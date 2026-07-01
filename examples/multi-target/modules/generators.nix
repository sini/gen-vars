# =============================================================================
# gen-vars/examples/multi-target/modules/generators.nix
# Collect generator declarations from the aspect tree (flatten); per host,
# instantiate ONLY the scope-selected, DECLARED generators into pure gen-vars
# handles + a plan. gen-vars is imported-only here.
# =============================================================================
{
  lib,
  config,
  genAspects,
  genVars,
  generatorNamesForHost,
  ...
}:
let
  flat = genAspects.flatten config.aspects;
  hostNames = builtins.attrNames config.fleet.hosts;

  # Fold every aspect's `generators` into one host-global declaration registry,
  # erroring on conflicting redeclaration of the same generator name.
  allGeneratorDecls = builtins.foldl' (
    acc: path:
    let
      decls = flat.${path}.generators or { };
    in
    builtins.foldl' (
      a: gn:
      if (a ? ${gn}) && a.${gn} != decls.${gn} then
        throw "gen-vars-demo: conflicting generator declarations for '${gn}'"
      else
        a // { ${gn} = decls.${gn}; }
    ) acc (builtins.attrNames decls)
  ) { } (builtins.attrNames flat);

  # A scope-selected name with no declaration (e.g. an unauthored baseline) is
  # skipped, not a throw on `allGeneratorDecls.<gn>.files`.
  selectedDeclared = h: builtins.filter (gn: allGeneratorDecls ? ${gn}) (generatorNamesForHost h);

  handlesForHost =
    h:
    lib.genAttrs (selectedDeclared h) (
      gen:
      lib.mapAttrs (
        fileName: fileSpec:
        genVars.mkHandle {
          generator = gen;
          name = fileName;
          secret = fileSpec.secret or true;
        }
      ) (allGeneratorDecls.${gen}.files or { })
    );

  generatorsForHost = lib.genAttrs hostNames handlesForHost;

  planForHost =
    h:
    genVars.mkPlan (
      lib.genAttrs (selectedDeclared h) (g: genVars.mkGenerator g allGeneratorDecls.${g})
    );
in
{
  config._module.args = {
    inherit generatorsForHost allGeneratorDecls;
    generatorPlans = lib.genAttrs hostNames planForHost;
  };
}
