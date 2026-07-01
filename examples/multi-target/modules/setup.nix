# =============================================================================
# gen-vars/examples/multi-target/modules/setup.nix
# Instantiate the gen libs this demo needs DIRECTLY from flake inputs (no hub):
# build gen-aspects (+ its gen-schema/gen-algebra deps), gen-scope, gen-bind and
# gen-vars itself, then declare the aspect schema with nixos + terranix classes
# and a `generators` aspectModule; thread classNames EXPLICITLY from the literal
# classes attrset.
# =============================================================================
{ lib, inputs, ... }:
let
  # --- construct each lib from its input, mirroring gen's mkGenLibs wiring ---
  # Every published gen lib now exposes a single `.lib` VALUE (the old callable
  # `gen-X { inherit lib; }` functor form is gone). gen-scope, gen-bind and
  # gen-algebra are nixpkgs-lib-free (they wire their own gen-prelude), so we
  # consume their `.lib` directly. gen-schema and gen-aspects still accept a
  # `lib`, so we thread the demo's nixpkgs.lib into them (via `${input}/lib`)
  # to keep ONE lib instance across the module eval.
  algebra = inputs.gen-algebra.lib;
  scope = inputs.gen-scope.lib;
  bind = inputs.gen-bind.lib;
  schema = import "${inputs.gen-schema}/lib" {
    inherit lib algebra;
  };
  aspects = import "${inputs.gen-aspects}/lib" {
    inherit lib schema;
  };
  # gen-vars: its `.lib` output already wires gen-graph from gen-vars' own lock,
  # so order/ enrichment shares gen-vars' pinned gen-graph revision.
  vars = inputs.gen-vars.lib;

  genAspects = aspects;
  genScope = scope;
  genBind = bind;
  genVars = vars;

  # The declared class set is the SINGLE SOURCE OF TRUTH for classNames.
  # config.schema.aspect.classes does NOT exist (classes live at cnf.classes
  # internally, never re-surfaced by gen-aspects). We thread the
  # literal set explicitly; NO silent or-fallback to nixos.
  classes = {
    nixos = { };
    terranix = { }; # the SECOND target class; required or `terranix` falls
    # through freeform and becomes a nested aspect.
  };

  aspectSchema = genAspects.mkAspectSchema {
    inherit classes;
    collections = {
      tags = {
        default = [ ];
      };
    };
    aspectModules = [
      {
        # gen-vars generator declarations owned by this aspect.
        options.generators = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
          description = "gen-vars generator declarations owned by this aspect.";
        };
      }
    ];
  };
in
{
  imports = [ (aspectSchema.mkAspectModule { }) ];

  options.schema = aspectSchema.schemaOption;

  config._module.args = {
    inherit
      genAspects
      genScope
      genBind
      genVars
      aspectSchema
      ;
    # The threaded class set + names. Read these, NEVER config.schema.
    inherit classes;
    classNames = builtins.attrNames classes;
  };
}
