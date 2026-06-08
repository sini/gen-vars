# =============================================================================
# gen/examples/gen-vars/modules/resolvers.nix
# Per-class resolver registry + projectVars. Resolution runs through the
# gen-vars CORE interface resolveAll (never a bypass). The nixos resolver is
# host-aware so generation varies by scope position, not just selection.
# =============================================================================
{ lib, genVars, ... }:
let
  varRoot = "/etc/vars";
  # handle -> class-native value. `host` is threaded so the GENERATED path
  # varies by scope position (vpn-host vs web-host differ for the same gen).
  classResolvers = {
    nixos =
      host: handle:
      let
        sub = if handle.secret then "secret" else "public";
      in
      "${varRoot}/${host}/${sub}/${handle.generator}/${handle.name}";
    terranix = _host: handle: "\${data.vars_file.${handle.generator}_${handle.name}.content}";
  };

  # Resolve every selected handle for one host into one class's native values.
  # Uses resolveAll (the multi-target core) then projects the single class.
  projectVars =
    host: className: hostHandles:
    lib.mapAttrs (
      _gen: files:
      lib.mapAttrs (
        _file: handle:
        (genVars.resolveAll { ${className} = classResolvers.${className} host; } handle).${className}
      ) files
    ) hostHandles;
in
{
  config._module.args = { inherit classResolvers projectVars varRoot; };
}
