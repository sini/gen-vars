# gen-vars demo: scope-driven, multi-target variable generation

A lean flake-parts demo proving the gen-vars headline: **the scope graph decides which generators each host gets, and one generated file resolves to multiple targets in a single evaluation.** It composes five gen libraries — `gen-flake` (the pure composition boundary), `gen-aspects` (aspect schema + classes), `gen-scope` (the env/host graph that drives selection), `gen-bind` (injecting resolved values into class content), and `gen-vars` (handles, plans, `resolveAll`).

**gen-flake value-injection.** The aspect definitions (`./gen-modules`) are composed PURELY by `gen-flake` — gen-merge's byte-mode `evalModuleTree`, NOT flake-parts' nixpkgs `lib.evalModules`. gen-aspects is now re-hosted on gen-merge, so embedding its aspect TYPE in a flake-parts options tree (the old `modules/setup.nix`: `mkAspectModule {}` + `options.schema`) makes flake-parts walk the type via `substSubModules`/`getSubOptions` and throw. Instead, `gen-flake.flakeModules.default` composes the tree once and injects the resolved config VALUES as the `genValues` module arg; NO gen type enters the flake-parts eval. The `./modules/*` readers consume `genValues.aspects` (resolved DATA + unforced class deferredModules).

This demo is **multi-target**, so it uses gen-flake for the pure compose ONLY, not its `mkSystems` terminal (which builds only the `nixos` class): the demo has no `config.hosts` NixOS registry — it keeps `config.fleet.hosts` flake-parts-side — so `flake.nixosConfigurations` is `{}` (harmless). The demo's OWN multi-target terminal stays flake-parts-side: `injection.nix` binds resolved vars into BOTH classes' content via `genBind.wrap`, and `outputs.nix` fans one handle to both via `genVars.resolveAll { nixos; terranix; }`.

The demo lives inside the gen-vars project, so it pins gen-vars as the parent (`gen-vars.url = "path:../.."`) and consumes gen-flake via a local path pin (`gen-flake` is unpublished). `gen-aspects` / `gen-bind` **follow gen-flake's own instances**, so the reader-side `flatten` / `wrap` operate on aspect + class objects structurally identical to the injected `genValues`. `gen-scope` is the demo's own input. gen-flake threads gen-merge / gen-schema / gen-aspects into the pure tree; no gen hub required.

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
flake.nix              — inputs = { gen-flake = path:… ; gen-vars = path:../.. ; gen-scope;
                         gen-aspects/gen-bind (follow gen-flake); nixpkgs; flake-parts; import-tree }.
                         imports gen-flake.flakeModules.default; gen.tree = ./gen-modules;
                         gen.specialArgs = { lib; classes }; reader libs + classNames via _module.args
gen-modules/           — the PURE gen tree (composed by gen-flake's evalModuleTree, injected as genValues)
  aspects.nix          — the typed aspect SURFACE: mkAspectSchema { classes = { nixos; terranix }; }
                         + a `generators` aspectModule; options.aspects = aspectSchema.mkAspectOption {}
  aspects/
    vpn.nix            — wg-key generator + PARAMETRIC nixos/terranix classes that read `vars`
    tls.nix            — tls-ca generator (the env-baseline aspect)
modules/               — the flake-parts READERS (consume the injected genValues, emit outputs)
  fleet.nix            — 3 hosts with role + env (vpn-host, web-host, dev-host); flake-parts-side
  scope.nix            — env/host parent graph; genScope.inheritAll unions each host's generator
                         set up the env→host chain (lib.unique combine) — the SELECTION mechanism
  generators.nix       — flatten genValues.aspects → host-global generator registry; per host,
                         materialize ONLY the scope-selected + declared generators into gen-vars handles
  resolvers.nix        — per-class resolver registry (host-aware); projectVars resolves every
                         selected handle through gen-vars' core resolveAll (never a bypass)
  injection.nix        — per-class loop; genBind.wrap binds a host-global `vars` (resolved,
                         class-native values — never handles) into each aspect's class content
  outputs.nix          — flake.varsMultiTarget: the multi-target + end-to-end + scope proofs
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

`gen-dispatch` is deliberately **not** on the selection path — a pure `genScope.inheritAll` parent-chain accumulator is leaner and makes the scope graph itself the selection mechanism, which is the demo's point.

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
