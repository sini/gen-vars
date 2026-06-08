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
  algebra = inputs.gen-algebra { inherit lib; }; # functor
  scope = inputs.gen-scope { inherit lib; }; # functor
  bind = import "${inputs.gen-bind}/nix/lib" { inherit lib; };
  schema = import "${inputs.gen-schema}/nix/lib" {
    inputs.gen-algebra = algebra;
    inherit lib;
  };
  aspects = import "${inputs.gen-aspects}/lib" {
    inputs.gen-schema = schema;
    inherit lib;
  };
  # gen-vars: import the flake root default.nix (signature `{ lib, inputs }:`),
  # threading the gen-graph flake input so order/ enrichment shares its revision.
  vars = import "${inputs.gen-vars}" {
    inherit lib;
    inputs = { inherit (inputs) gen-graph; };
  };

  genAspects = aspects;
  genScope = scope;
  genBind = bind;
  genVars = vars;

  # The declared class set is the SINGLE SOURCE OF TRUTH for classNames.
  # config.schema.aspect.classes does NOT exist (classes live at cnf.classes
  # internally, never re-surfaced — gen-aspects types.nix:104). We thread the
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
