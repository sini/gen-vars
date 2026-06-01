{
  lib,
  genGraph ? null,
}:
let
  depGraph = gens: {
    edges = id: gens.${id}.dependencies or [ ];
    nodes = builtins.attrNames gens;
  };

  reachLibOnly =
    gens: start:
    let
      go =
        seen: frontier:
        if frontier == [ ] then
          seen
        else
          let
            n = builtins.head frontier;
            fresh = builtins.filter (d: !(builtins.elem d seen)) (gens.${n}.dependencies or [ ]);
          in
          go (seen ++ fresh) (builtins.tail frontier ++ fresh);
    in
    go [ ] [ start ];
  dependentsLibOnly =
    gens: target:
    builtins.filter (n: builtins.elem target (reachLibOnly gens n)) (builtins.attrNames gens);

  mkPlan =
    generators:
    let
      g = depGraph generators;
      # 1. missing-dependency check BEFORE toposort.
      missing = lib.flatten (
        lib.mapAttrsToList (
          n: gen:
          map (d: {
            from = n;
            dep = d;
          }) (builtins.filter (d: !(generators ? ${d})) gen.dependencies)
        ) generators
      );
      missingErr =
        lib.optional (missing != [ ])
          "gen-vars: unknown generator dependencies: ${
            builtins.concatStringsSep ", " (map (m: "${m.from} -> ${m.dep}") missing)
          }";
      # 2. order + cycle detection.
      sorted = lib.toposort (a: b: builtins.elem a.name b.dependencies) (builtins.attrValues generators);
      cycleNodes =
        if !(sorted ? cycle) then
          [ ]
        else if genGraph != null then
          genGraph.cycles g
        else
          map (r: r.name) (sorted.loops or sorted.cycle);
      cycleErr = lib.optional (
        sorted ? cycle
      ) "gen-vars: dependency cycle among generators: ${builtins.concatStringsSep " -> " cycleNodes}";
      errors = missingErr ++ cycleErr;
      toEntry = gen: {
        inherit (gen)
          name
          dependencies
          runtimeInputs
          script
          ;
        files = builtins.attrValues gen.files; # [{ name; generator; secret; deploy; }]
        prompts = builtins.attrValues gen.prompts; # [{ name; description; type; }]
        io = {
          out = "$out";
          deps = "$in";
          prompts = "$prompts";
        };
      };
    in
    if errors != [ ] then
      throw (builtins.concatStringsSep "\n" errors)
    else
      {
        order = map toEntry sorted.result;
        impactOf =
          name: if genGraph != null then genGraph.dependentsOf g name else dependentsLibOnly generators name;
        depsOf =
          name: if genGraph != null then genGraph.reachableFrom g name else reachLibOnly generators name;
      };
in
{
  inherit mkPlan depGraph;
}
