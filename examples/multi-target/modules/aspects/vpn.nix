# =============================================================================
# gen/examples/gen-vars/modules/aspects/vpn.nix
# The proof aspect: a wg-key generator + PARAMETRIC nixos/terranix classes that
# read the host-global `vars` binding. SAME handle (wg-key/public.key) consumed
# by BOTH classes — the multi-target headline.
# =============================================================================
{ ... }:
{
  config.aspects.vpn = {
    tags = [
      "network"
      "security"
    ];

    generators.wg-key = {
      files."private.key" = {
        secret = true;
      };
      files."public.key" = {
        secret = false;
      };
      runtimeInputs = [ ]; # wireguard-tools in a real build
      script = ''wg genkey | tee "$out"/private.key | wg pubkey > "$out"/public.key'';
    };

    # PARAMETRIC classes (MUST name `vars`): a static attrset never names
    # `vars`, so genBind.wrap (wrap.nix:88-90 binds only named args) would never
    # bind it and `vars.wg-key."public.key"` would be a missing-attr throw.
    # The SAME handle reaches both classes via two resolvers.
    nixos =
      { vars, ... }:
      {
        networking.wireguard.interfaces.wg0.publicKey = vars.wg-key."public.key";
      };
    terranix =
      { vars, ... }:
      {
        resource.wireguard_peer.self.public_key = vars.wg-key."public.key";
      };
  };
}
