{
  description = "gen-vars demo: scope-driven, multi-target variable generation via gen-flake value-injection";

  # Value-injection migration (gen-flake), multi-target variant. The aspect
  # definition tree (./gen-modules) is composed PURELY by gen-flake — gen-merge's
  # byte-mode `evalModuleTree`, NOT flake-parts' nixpkgs `lib.evalModules`. The
  # resolved config VALUES (incl the resolved aspect tree, with BOTH `nixos` and
  # `terranix` class content) are injected as the `genValues` module arg. NO gen
  # TYPE enters the flake-parts options tree (the old `mkAspectModule`/`options.schema`
  # embed made flake-parts walk the re-hosted aspect type via
  # substSubModules/getSubOptions and throw).
  #
  # gen-flake here is used for the PURE COMPOSE only, NOT its `mkSystems` terminal:
  # this demo has no `config.hosts` NixOS registry (it uses `config.fleet.hosts`
  # flake-parts-side), so mkSystems projects an empty `hostContent` and
  # `flake.nixosConfigurations` is `{}` — harmless. The demo's OWN multi-target
  # terminal stays flake-parts-side: `modules/injection.nix` binds resolved vars
  # into each aspect's class content (genBind.wrap) for BOTH classes, and
  # `modules/outputs.nix` fans one handle out to both via `genVars.resolveAll
  # { nixos; terranix; }`. Those readers now read the injected `genValues.aspects`
  # instead of a flake-parts `config.aspects` OPTION tree.
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      let
        # The declared class set — the SINGLE SOURCE OF TRUTH for classNames.
        # Threaded into the pure tree (via gen.specialArgs, so aspects.nix builds
        # its aspect schema with exactly these classes) AND to the flake-parts
        # readers (via _module.args, as the explicit `classNames`). NEVER read off
        # a `schema` surface — gen-aspects keeps classes internal.
        classes = {
          nixos = { };
          terranix = { }; # the SECOND target class; required or `terranix` falls
          # through freeform and becomes a nested aspect.
        };
      in
      {
        # gen-flake injects a `perSystem` (to spread `genValues` into per-system
        # args), so flake-parts requires `systems`. The demo emits no per-system
        # outputs; one system suffices.
        systems = [ "x86_64-linux" ];

        imports = [
          # PURE compose + value-injection. Composes ./gen-modules once, injects
          # `genValues` into every flake module arg, and (unused here) sets
          # `flake.nixosConfigurations = {}` from an empty host projection.
          inputs.gen-flake.flakeModules.default
          # The flake-parts READERS: fleet data, scope selection, resolvers,
          # generator instantiation, per-(host,class) injection, the proof.
          (inputs.import-tree ./modules)
        ];

        # The gen definition tree, composed PURELY by gen-merge's evalModuleTree.
        # gen-flake threads its own genMerge/genSchema/genAspects into every tree
        # module; the demo adds `lib` (aspects.nix's generators option uses nixpkgs
        # `lib.mkOption`/`lib.types`, matching the gen-schema playbook) and `classes`
        # (the declared class set) via `gen.specialArgs`.
        gen.tree = ./gen-modules;
        gen.specialArgs = { inherit lib classes; };

        # READER-side gen LIBRARIES (distinct from the injected VALUES) + the
        # explicit class set. genAspects/genBind FOLLOW gen-flake's own instances
        # (see inputs) so the reader's `flatten`/`wrap` operate on aspect + class
        # objects structurally identical to the injected `genValues.aspects`.
        # genScope/genVars are the demo's own libs (isolated concerns: scope graph
        # over plain node data, gen-vars over plain generator declarations).
        _module.args = {
          inherit classes;
          classNames = builtins.attrNames classes;
          genAspects = inputs.gen-aspects.lib;
          genScope = inputs.gen-scope.lib;
          genVars = inputs.gen-vars.lib;
          genBind = inputs.gen-bind.lib;
        };
      }
    );

  inputs = {
    # gen-flake — the pure composition boundary. Consumed LOCAL (unpublished) via a
    # path pin. It threads the published pure stack (gen-aspects / gen-merge / …)
    # into the tree, so the relocated aspect declaration receives `{ genAspects,
    # genMerge, ... }` as module args.
    gen-flake.url = "github:sini/gen-flake";

    # gen-vars is the parent project (this demo lives inside it); its `.lib` output
    # wires gen-graph from gen-vars' own lock, so order/enrichment shares gen-vars'
    # pinned gen-graph revision.
    gen-vars.url = "path:../..";

    # gen-scope is nixpkgs-lib-free (wires its own gen-prelude); the demo consumes
    # `.lib` directly for the env/host scope graph.
    gen-scope.url = "github:sini/gen-scope";

    # Reuse the EXACT gen-aspects / gen-bind instances gen-flake threads into the
    # pure tree, so the reader-side `flatten`/`wrap` operate on aspect + class
    # objects structurally identical to the injected `genValues` (and no duplicate
    # fetch). This is the multi-target instance-consistency requirement.
    gen-aspects.follows = "gen-flake/gen-aspects";
    gen-bind.follows = "gen-flake/gen-bind";

    # The flake-parts eval that hosts the readers + emits outputs keeps its own
    # nixpkgs + flake-parts. nixpkgs-lib follows nixpkgs so the tree's injected
    # `lib` and the readers' `lib` are one instance.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # The flake-parts reader loader (loads ./modules into the flake-parts eval).
    # Distinct from gen-flake's internal import-tree fork (which loads ./gen-modules
    # into the pure gen eval).
    import-tree.url = "github:sini/import-tree";
  };
}
