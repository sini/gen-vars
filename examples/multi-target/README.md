# gen-vars demo: scope-driven, multi-target variable generation

A fresh, lean flake-parts demo proving the gen-vars headline: **the scope graph decides which generators each host gets, and one generated file resolves to multiple targets in a single evaluation.** It composes four gen libraries — `gen-aspects` (aspect schema + classes), `gen-scope` (the env/host graph that drives selection), `gen-bind` (injecting resolved values into class content), and `gen-vars` (handles, plans, `resolveAll`).

This demo lives inside the gen-vars project, so it consumes gen-vars as the parent input (`gen-vars.url = "path:../.."`) and reads every sibling lib (`gen-aspects`, `gen-scope`, `gen-bind`, plus their `gen-schema` / `gen-algebra` / `gen-graph` deps) as **direct flake inputs** — `setup.nix` constructs each lib itself, mirroring how gen's `mkGenLibs` wires them. No gen hub required.

## Running

```bash
nix eval .#varsMultiTarget.reachesTwoClasses    # → true   (the headline conjunction)
nix eval --json .#varsMultiTarget               # all proof fields + nixosPath / terranixRef
nix eval .#varsMultiTarget.nixosPath            # → "/etc/vars/vpn-host/public/wg-key/public.key"
nix eval .#varsMultiTarget.terranixRef          # → "${data.vars_file.wg-key_public.key.content}"

# CI: four discriminating asserts (reads the app flake's output once)
nix develop ./ci -c nix-unit --flake ./ci#tests # → 4/4 successful
```

## Structure

```
flake.nix              — inputs = { gen-vars = path:../.. ; gen-aspects/gen-scope/gen-bind/...
                         (direct github inputs); nixpkgs; flake-parts; import-tree }
modules/
  setup.nix            — construct each lib DIRECTLY from inputs (no hub); aspect schema
                         { nixos; terranix } + a `generators` aspectModule; threads classes +
                         classNames via _module.args
  fleet.nix            — 3 hosts with role + env (vpn-host, web-host, dev-host)
  scope.nix            — env/host parent graph; genScope.inheritAll unions each host's generator
                         set up the env→host chain (lib.unique combine) — the SELECTION mechanism
  generators.nix       — flatten the aspect tree → host-global generator registry; per host,
                         materialize ONLY the scope-selected + declared generators into gen-vars handles
  resolvers.nix        — per-class resolver registry (host-aware); projectVars resolves every
                         selected handle through gen-vars' core resolveAll (never a bypass)
  injection.nix        — per-class loop; genBind.wrap binds a host-global `vars` (resolved,
                         class-native values — never handles) into each aspect's class content
  outputs.nix          — flake.varsMultiTarget: the multi-target + end-to-end + scope proofs
  aspects/
    vpn.nix            — wg-key generator + PARAMETRIC nixos/terranix classes that read `vars`
    tls.nix            — tls-ca generator (the env-baseline aspect)
ci/
  flake.nix            — gen.lib.mkCi (mkCi from github:sini/gen); reads the app flake via inputs.demo
  tests/multi-target.nix — asserts the four proof booleans
```

## What each library does here

| Library | Role in this demo |
|---------|-------------------|
| **gen-aspects** | `mkAspectSchema { classes = { nixos; terranix }; aspectModules = [ generators ]; }` + `flatten` — two registered classes and a per-aspect `generators` channel |
| **gen-scope** | `buildNodes` + `eval` build a real env/host parent graph; `inheritAll` (with a `lib.unique` combine) unions each host's generator names up the env→host chain — **graph topology is the selection mechanism** |
| **gen-vars** | imported-only: `mkHandle` / `mkGenerator` / `mkPlan` / `resolveAll` / `handleId`. `resolveAll` fans ONE handle to BOTH class resolvers in ONE call |
| **gen-bind** | `wrap` injects a host-global `vars` binding (resolved class-native values) into each aspect's parametric class content, with a contract + provenance |

`gen-derive` is deliberately **not** on the selection path — a pure `genScope.inheritAll` parent-chain accumulator is leaner and makes the scope graph itself the selection mechanism, which is the demo's point.

## The fleet

```nix
vpn-host = { role = "vpn"; env = "prod"; };
web-host = { role = "web"; env = "prod"; };
dev-host = { role = "web"; env = "dev";  };

roleGenerators = { vpn = [ "wg-key" "monitoring" ]; web = [ ]; };
envGenerators  = { prod = [ "tls-ca" "monitoring" ]; dev = [ ]; };   # inherited by every host in that env
```

`genScope.inheritAll` unions a host's own (role-driven) set with every ancestor's (env) baseline:

```
generatorNamesForHost "vpn-host"  → [ "wg-key" "monitoring" "tls-ca" ]   # role ∪ env, de-duped
generatorNamesForHost "web-host"  → [ "tls-ca" "monitoring" ]            # env only (role=web is empty)
generatorNamesForHost "dev-host"  → [ ]                                  # env=dev contributes nothing
```

Only **declared** generators are materialized into handles (`monitoring` is selected by both tiers but never authored as a generator, so it is filtered out before `mkHandle` — never throwing on a missing `.files`).

## Key patterns demonstrated

### Scope graph drives generation (not a flat per-host lookup)

`tls-ca` is declared only by the `tls` aspect and contributed only by `envGenerators.prod`. It reaches `vpn-host` **solely by env inheritance** — `vpn-host`'s role (`vpn`) never names it. Deleting the env tier would drop it.

### Multi-target resolution through the core

The headline. One `resolveAll` call, both resolvers, the one `wg-key/public.key` handle:

```nix
genVars.resolveAll {
  nixos    = classResolvers.nixos "vpn-host";      # → "/etc/vars/vpn-host/public/wg-key/public.key"
  terranix = classResolvers.terranix "vpn-host";   # → "${data.vars_file.wg-key_public.key.content}"
} handle
```

The `nixos` resolver threads `host` into the path, so two hosts get distinct paths for the same generator — generation varies by scope position, not just selection.

### Injection: host-global `vars` into parametric classes

Both `vpn` classes are parametric (`{ vars, ... }:`) and read `vars.wg-key."public.key"`. `genBind.wrap` binds a host-global `vars` (the *resolved* class-native values, never raw handles) into each aspect's class content — riding the same `deferredModule` seam settings ride. The **same** handle reaches both classes through two resolvers.

### The proof (`flake.varsMultiTarget.reachesTwoClasses`)

One discriminating boolean, decomposed into four CI asserts so a regression points at its cause:

| Assert | What it pins |
|--------|--------------|
| `multiResolve` | one `resolveAll` fans the single handle to a nixos path **and** a terranix ref (≥2 resolvers, one eval) |
| `multiTarget` | the conjunction — also covers the end-to-end injected-class eval (`lib.evalModules` over the wrapped `nixos` + `terranix` classes) |
| `envBaseline` | the scope graph is load-bearing: `tls-ca` reaches `vpn-host` **solely** by env inheritance, not its role |
| `union` | `inheritAll` accumulation is a real set-union: `monitoring` (in both tiers) appears **exactly once** |

CI fails loudly if one handle stops reaching two classes through `resolveAll`, or if the scope graph stops contributing the env baseline / collapses the union.
