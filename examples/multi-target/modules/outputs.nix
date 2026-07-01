# =============================================================================
# gen-vars/examples/multi-target/modules/outputs.nix
# THE MULTI-TARGET PROOF. Primary: ONE resolveAll call with BOTH resolvers on
# ONE handle (the defining fan-out). Secondary: end-to-end injected-class eval.
# Plus the discriminating SCOPE asserts (env baseline + union).
# =============================================================================
{
  lib,
  genVars,
  classResolvers,
  generatorsForHost,
  generatorNamesForHost,
  roleGenerators,
  assembledClasses,
  varRoot,
  ...
}:
let
  handle = generatorsForHost.vpn-host.wg-key."public.key"; # the ONE handle

  # --- PRIMARY: one resolveAll, BOTH resolvers, one eval (the headline) ---
  targets = genVars.resolveAll {
    nixos = classResolvers.nixos "vpn-host";
    terranix = classResolvers.terranix "vpn-host";
  } handle;

  multiResolveProof =
    genVars.handleId handle == "wg-key/public.key"
    && targets.nixos == "${varRoot}/vpn-host/public/wg-key/public.key"
    && lib.hasInfix "vars_file.wg-key_public.key" targets.terranix;

  # --- SECONDARY: end-to-end through the injected, wrapped classes ---
  evalNixos =
    (lib.evalModules {
      modules = [
        {
          options.networking.wireguard.interfaces = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options.publicKey = lib.mkOption { type = lib.types.str; };
              }
            );
            default = { };
          };
        }
        assembledClasses.vpn-host.vpn.nixos
      ];
    }).config.networking.wireguard.interfaces.wg0.publicKey;

  evalTf =
    (lib.evalModules {
      modules = [
        { freeformType = lib.types.lazyAttrsOf lib.types.raw; }
        assembledClasses.vpn-host.vpn.terranix
      ];
    }).config.resource.wireguard_peer.self.public_key;

  endToEndProof =
    evalNixos == "${varRoot}/vpn-host/public/wg-key/public.key"
    && lib.hasInfix "vars_file.wg-key_public.key" evalTf;

  # --- SCOPE asserts: the graph is load-bearing, not a stub ---
  vpnGens = generatorNamesForHost "vpn-host";
  # tls-ca reaches vpn-host SOLELY by env inheritance (NOT its role).
  envBaselineProof = builtins.elem "tls-ca" vpnGens && !(builtins.elem "tls-ca" roleGenerators.vpn);
  # union is real: monitoring is in BOTH tiers; vpn-host gets exactly ONE.
  unionProof = builtins.length (builtins.filter (g: g == "monitoring") vpnGens) == 1;

  reachesTwoClasses = multiResolveProof && endToEndProof && envBaselineProof && unionProof;
in
{
  flake.varsMultiTarget = {
    handleId = genVars.handleId handle; # "wg-key/public.key"
    nixosPath = targets.nixos; # "/etc/vars/vpn-host/public/wg-key/public.key"
    terranixRef = targets.terranix; # "${data.vars_file.wg-key_public.key.content}"
    inherit
      multiResolveProof
      endToEndProof
      envBaselineProof
      unionProof
      reachesTwoClasses
      ;
  };
}
