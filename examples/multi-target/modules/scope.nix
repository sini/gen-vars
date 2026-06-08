# =============================================================================
# gen/examples/gen-vars/modules/scope.nix
# A REAL small env/host parent graph + scope-driven generator SELECTION.
# The env node contributes a baseline generator set; each host adds its own
# (role-driven). `genScope.inheritAll` UNIONS the set up the env->host chain:
# the GRAPH TOPOLOGY is the selection mechanism (den value-add over flat vars).
# =============================================================================
{
  lib,
  config,
  genScope,
  ...
}:
let
  hosts = config.fleet.hosts;
  hostNames = builtins.attrNames hosts;
  envNames = lib.unique (lib.mapAttrsToList (_h: c: c.env) hosts);

  # role -> generator names. Selection is role-driven, composed up the chain.
  # `monitoring` deliberately overlaps with envGenerators.prod so lib.unique
  # is load-bearing (proves set-union, not coincidental non-overlap).
  roleGenerators = {
    vpn = [
      "wg-key"
      "monitoring"
    ];
    web = [ ];
  };
  # env -> baseline generators every host in that env inherits (topology-driven).
  # `tls-ca` is a REAL declared generator (aspects/tls.nix) and reaches
  # vpn-host SOLELY by env inheritance — the discriminating proof of §5.9.
  envGenerators = {
    prod = [
      "tls-ca"
      "monitoring"
    ];
    dev = [ ];
  };

  # P-edges: each host's parent is its env (inverted star = child->center).
  parentGraph = genScope.overlays (
    map (h: genScope.edge "host:${h}" "env:${hosts.${h}.env}") hostNames
  );

  roots = genScope.buildNodes {
    inherit parentGraph;
    types =
      lib.genAttrs (map (e: "env:${e}") envNames) (_: "env")
      // lib.genAttrs (map (h: "host:${h}") hostNames) (_: "host");
    decls =
      lib.listToAttrs (
        map (e: lib.nameValuePair "env:${e}" { generators = envGenerators.${e} or [ ]; }) envNames
      )
      // lib.listToAttrs (
        map (
          h:
          lib.nameValuePair "host:${h}" {
            role = hosts.${h}.role;
            env = hosts.${h}.env;
            generators = roleGenerators.${hosts.${h}.role} or [ ];
          }
        ) hostNames
      );
  };

  scopeEval = genScope.eval {
    inherit roots;
    attributes = {
      # Required by eval's attribute-set completeness / materialization helpers
      # (NOT for host resolution: buildNodes flattens every vertex into `roots`,
      # so `get` short-circuits on `rootEval ? id` and never walks children here).
      children = _self: id: lib.filterAttrs (_: n: n.parent == id) roots;
      imports = _self: _id: [ ];
      # THE SELECTION: union the host's own generators with every ancestor's
      # baseline set, up the env->host chain. lib.unique de-dups overlap.
      generatorsFor = genScope.inheritAll {
        extract = node: node.decls.generators or null;
        combine = a: b: lib.unique (a ++ b);
      };
    };
  };

  # The scope-driven answer: which generator NAMES this host gets.
  generatorNamesForHost = h: scopeEval.get "host:${h}" "generatorsFor";
in
{
  config._module.args = { inherit scopeEval generatorNamesForHost roleGenerators; };
}
