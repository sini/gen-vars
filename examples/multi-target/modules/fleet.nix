# =============================================================================
# gen/examples/gen-vars/modules/fleet.nix
# Hosts with a role + env. env/role drive scope-graph generator selection.
# =============================================================================
{ lib, ... }:
{
  options.fleet.hosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          role = lib.mkOption { type = lib.types.str; };
          env = lib.mkOption { type = lib.types.str; };
        };
      }
    );
    default = { };
  };

  config.fleet.hosts = {
    # role == "vpn" selects wg-key + monitoring; env == "prod" adds tls-ca.
    vpn-host = {
      role = "vpn";
      env = "prod";
    };
    web-host = {
      role = "web";
      env = "prod";
    };
    dev-host = {
      role = "web";
      env = "dev";
    };
  };
}
