# =============================================================================
# gen/examples/gen-vars/modules/injection.nix
# Per-class loop: bind host-global `vars` (resolved, class-native values) into
# each aspect's class content via genBind.wrap. classNames is threaded
# EXPLICITLY (NEVER off config.schema).
# =============================================================================
{
  lib,
  config,
  genAspects,
  genBind,
  classNames,
  generatorsForHost,
  projectVars,
  ...
}:
let
  flat = genAspects.flatten config.aspects;
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
