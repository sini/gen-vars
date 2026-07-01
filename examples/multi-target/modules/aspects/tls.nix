# =============================================================================
# gen-vars/examples/multi-target/modules/aspects/tls.nix
# The env-baseline aspect: declares the `tls-ca` generator that prod-env hosts
# inherit via the scope graph (NOT via their role). Makes the env tier
# load-bearing — see the envBaseline negative assert (tls-ca reaches vpn-host
# SOLELY by env inheritance).
# =============================================================================
{ ... }:
{
  config.aspects.tls = {
    tags = [ "security" ];
    generators.tls-ca = {
      files."cert.pem" = {
        secret = false;
      };
      files."key.pem" = {
        secret = true;
      };
      script = ''step-ca-init > "$out"/cert.pem'';
    };
  };
}
