# =============================================================================
# gen-vars/examples/multi-target/gen-modules/aspects.nix
# The typed aspect SURFACE, declared PURELY inside the gen tree.
#
# This is the crux of the gen-flake value-injection migration. The old
# flake-parts `modules/setup.nix` embedded the aspect gen TYPE via
# `imports = [ (aspectSchema.mkAspectModule {}) ]` + `options.schema =
# aspectSchema.schemaOption`. gen-aspects is now re-hosted on gen-merge, so
# nixpkgs `lib.evalModules` (flake-parts) walks that gen type via
# substSubModules/getSubOptions and THROWS. Relocating the declaration here lets
# gen-merge's `evalModuleTree` — gen-aspects' own host engine — handle the type
# natively; only the resolved VALUES cross to the flake-parts readers (as the
# injected `genValues`), never the type.
#
# Mirrors gen-flake's fixture (ci/tests/_fixtures/tree/aspects.nix): declare the
# aspect surface with `mkAspectOption {}` (NOT `mkAspectModule {}` + a separate
# `options.schema`). `genAspects`/`genMerge` are threaded by gen-flake's compose;
# `lib`/`classes` are threaded by the demo via `gen.specialArgs`.
#
# The declared class set (`classes`) is the SINGLE SOURCE OF TRUTH for the class
# names, threaded EXPLICITLY from flake.nix — never read back off a `schema`
# surface (gen-aspects keeps classes at cnf.classes internally and never
# re-surfaces them). Both classes (`nixos` + `terranix`) are registered so
# neither falls through freeform into a nested aspect; this is the multi-target
# headline (one aspect, two parametric class bodies).
{
  genAspects,
  lib,
  classes,
  ...
}:
let
  aspectSchema = genAspects.mkAspectSchema {
    inherit classes;
    collections = {
      tags = {
        default = [ ];
      };
    };
    aspectModules = [
      {
        # gen-vars generator declarations owned by this aspect. Threaded onto
        # every aspect instance via cnf.aspectModules (aspectSubmodule imports).
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
  options.aspects = aspectSchema.mkAspectOption { };
}
