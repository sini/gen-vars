# =============================================================================
# gen-vars/examples/multi-target/modules/injection.nix
# Per-class loop: bind host-global `vars` (resolved, class-native values) into
# each aspect's class content via genBind.wrap. classNames is threaded
# EXPLICITLY (NEVER off config.schema).
#
# READER of gen-flake's value-injection + the demo's MULTI-TARGET terminal: the
# aspect tree (with BOTH `nixos` and `terranix` class content) is composed PURELY
# by gen-flake and injected as `genValues`; this flattens `genValues.aspects`
# (DATA + unforced class deferredModules) and wraps each class body per (host,
# class) via genBind.wrap. `classNames` is the explicit declared set (threaded
# from flake.nix); `config.fleet.hosts` stays flake-parts-side.
# =============================================================================
{
  lib,
  config,
  genValues,
  genAspects,
  genBind,
  classNames,
  generatorsForHost,
  projectVars,
  ...
}:
let
  flat = genAspects.flatten genValues.aspects;
  leafName = path: lib.last (lib.splitString "/" path);
  hostNames = builtins.attrNames config.fleet.hosts;

  injectAspectClass =
    {
      host,
      aspectLeaf,
      className,
      classContent,
    }:
    (genBind.wrap {
      module = classContent;
      bindings = {
        host = {
          name = host;
        }
        // (config.fleet.hosts.${host} or { });
        # Resolved, class-native var values (strings/refs — NEVER handles).
        # host-global: any aspect's class fn on this host can read any handle.
        vars = projectVars host className (generatorsForHost.${host} or { });
      };
      contracts.vars = genBind.contract.isType "set";
      provenance.vars = {
        source = "gen-vars";
        scope = "host:${host}/class:${className}";
      };
    }).module;

  assembleHostAspects =
    host:
    lib.mapAttrs' (
      path: aspect:
      lib.nameValuePair (leafName path)
        # classNames is the literal declared set (NOT config.schema).
        (
          lib.genAttrs classNames (
            className:
            injectAspectClass {
              inherit host className;
              aspectLeaf = leafName path;
              classContent = aspect.${className} or { };
            }
          )
        )
    ) flat;

  assembledClasses = lib.genAttrs hostNames assembleHostAspects;
in
{
  config._module.args = { inherit injectAspectClass assembledClasses; };
}
