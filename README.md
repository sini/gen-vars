# gen-vars — scope-driven, multi-target variable generation for Nix

[![CI](https://github.com/sini/gen-vars/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-vars/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

A den-agnostic, pure-Nix vars/secrets library. It owns the **generator** data model, **dependency-DAG ordering**, a backend-agnostic **generation plan**, and a **multi-target resolution interface**. Impure execution is *emitted* (a script / derivation), never run by the library — gen-vars produces plans; a backend the consumer drives does the generating.

Dependency class: **nixpkgs-lib-tethered**. The library builds on `nixpkgs.lib` (`toposort`, the NixOS module system) with a single *optional* gen sibling — [gen-graph](https://github.com/sini/gen-graph) — for richer `order` diagnostics. Its bottom `pure/` tier is `lib`-free by construction (imported zero-arg, `builtins` only), so handles, generators, and the resolution interface stay usable with no `lib` at all.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [The multi-target property](#the-multi-target-property)
- [Tiers](#tiers)
- [API Reference](#api-reference)
- [Usage Example](#usage-example)
- [Testing](#testing)
- [Design Lineage](#design-lineage)

## Overview

A **generator** declares one or more files produced by a script, optionally depending on other generators' outputs (`$in`), prompting for input (`$prompts`), and writing results to `$out` — the proven nixpkgs `vars` model. gen-vars extracts the *pure algebra* of that model into a target-agnostic library: any consumer (a raw flake, NixOS, terranix, k8s) stitches the primitives together, and the **same generated file can be resolved to many targets in one evaluation**.

The motivation: nixpkgs `vars` is NixOS-coupled by *packaging* (mounted under `options.vars`, single-machine backend), not by concept. gen-vars keeps the generator core target-agnostic and pushes all coupling to the consumer. The library imports nothing from den / gen-aspects / gen-scope / gen-bind — consumers import gen-vars, never the reverse.

```nix
genVars = import gen-vars { inherit (nixpkgs) lib; };

gens = builtins.mapAttrs genVars.mkGenerator {
  ca  = { files."cert.pem" = { secret = false; }; files."key.pem" = { }; script = ''step-ca-init''; };
  tls = { dependencies = [ "ca" ]; files."server.pem" = { }; script = ''sign --ca "$in"/ca/cert.pem''; };
};

plan    = genVars.mkPlan gens;                                  # topo-ordered; cycle + missing-dep checked
harness = genVars.backends.onMachine { inherit pkgs plan; };    # → { app; store; resolve }; emits, runs nothing
```

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch) |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified phases, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-rebuild](https://github.com/sini/gen-rebuild) | Pure-Nix incremental rebuilder (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | **This lib** — Pure-Nix vars/secrets (den-agnostic) |

## Quick Start

### As a flake input

```nix
{
  inputs.gen-vars.url = "github:sini/gen-vars";
  outputs = { gen-vars, nixpkgs, ... }:
    let
      genVars = gen-vars.lib;   # the flake's `.lib` value output (nixpkgs.lib + gen-graph already wired)
    in { /* use genVars.mkGenerator, genVars.mkPlan, genVars.resolveAll, ... */ };
}
```

### Without flakes

```nix
let
  lib     = (import <nixpkgs> { }).lib;
  genVars = import ./path/to/gen-vars { inherit lib; };
in
genVars.mkPlan (builtins.mapAttrs genVars.mkGenerator { /* generators */ })
```

The root `default.nix` is `{ lib ? null, inputs ? { } }:`. With `lib == null` you still get the lib-free `pure` tier (handles, generators, the resolution interface); the `order` / `module` / `backend` tiers activate once `lib` is supplied. Pass `inputs.gen-graph` to enrich `order`'s impact/dependency diagnostics (optional — it falls back to `lib.toposort`).

## The multi-target property

A generated file is a pure **handle** `{ generator; name; secret; }` that carries **no resolution**. A *resolver* is a plain `handle -> resolution`, where `resolution` is *any* class-native value (a path string, a terranix ref, a `Secret` attrset — an **open** type). `resolveAll` feeds **one** handle to **many** resolvers in **one** evaluation:

```nix
genVars.resolveAll {
  nixos    = h: "/etc/vars/${h.generator}/${h.name}";
  terranix = h: { ref = "vars_file.${h.generator}_${h.name}"; };
} (genVars.mkHandle { generator = "ca"; name = "cert.pem"; secret = false; })
# → { nixos    = "/etc/vars/ca/cert.pem";
#     terranix = { ref = "vars_file.ca_cert.pem"; }; }
```

One file, two consumers, one eval. That fan-out — not machine-coupled storage — is what gen-vars adds over flat NixOS vars.

## Tiers

Dependencies flow strictly upward; `pure/` is verifiably `lib`-free (`builtins` only, no IO at import):

```
pure/      lib-free, gen-free, den-free        handle · generator · resolve (resolveAll)
  ▲
order/     lib + (optional) gen-graph          mkPlan: toposort, cycle/missing-dep, impact/deps
  ▲
module/    lib + the NixOS module system       deferredModule resolver seam · nixpkgs-vars-interop registry
  ▲
backend/   lib + pkgs                          emit a generate script (writeShellApplication) — runs nothing
```

## API Reference

### `pure/` — handles, generators, resolution (lib-free)

```
mkGenerator        : name → genSpec → generator
normalizeGenerator : alias of mkGenerator
validateGenerator  : generator → [errorString]      # a separate, non-throwing pass

mkHandle  : { generator; name; secret ? true } → handle
handleId  : handle → "${generator}/${name}"
handlesOf : generator → [handle]

mkResolver : (handle → resolution) → resolver        # identity / doc tag
resolve    : resolver → handle → resolution
resolveAll : { <target> = resolver; } → handle → { <target> = resolution; }
```

All of the above are spread onto the top-level attrset **and** re-exported grouped under `genVars.pure` — the entire `lib`-free tier as one namespace, so a consumer can depend on just `genVars.pure` with no `lib` in scope.

- **`mkGenerator name spec`** normalizes a generator: each file gets a `generator` backref and `secret = true` / `deploy = true` defaults; each prompt gets `description = name` / `type = "line"` defaults; `dependencies` / `runtimeInputs` / `script` default empty.
- **`validateGenerator g`** returns a *list* of error strings (never throws) — invalid generator name, invalid file names, invalid prompt types, each reported independently. The core stays lazy/composable; the module tier or consumer chooses when to enforce.
- **`resolution` is an open type.** A resolver returns whatever the consuming class wants — gen-vars never closes it to a fixed enum. `resolveAll` is the multi-target fan-out: a plain `mapAttrs` applying each resolver to the same handle once.

```nix
g = genVars.mkGenerator "wg-key" {
  files."public.key"  = { secret = false; };
  files."private.key" = { };
};
genVars.validateGenerator g            # → [ ]   (valid)
genVars.handleId (genVars.mkHandle { generator = "wg-key"; name = "public.key"; })
                                       # → "wg-key/public.key"
```

### `order/` — the backend-agnostic plan (`lib`, optional `gen-graph`)

```
mkPlan   : { <name> = generator; } → { order; impactOf; depsOf; }
depGraph : generators → { edges; nodes; }
```

**`mkPlan generators`** detects missing dependencies *before* ordering (a typo'd dep → a clear `unknown generator dependencies` throw), topologically orders via `lib.toposort` (a cycle → a `dependency cycle` throw), and returns:

```
order    : [ planEntry ]                  # deps before dependents
impactOf : name → [name]                  # what depends on this generator
depsOf   : name → [name]                  # what this generator transitively needs
```

Each `planEntry` is `{ name; dependencies; runtimeInputs; script; files = [fileSpec]; prompts = [promptSpec]; io = { out = "$out"; deps = "$in"; prompts = "$prompts"; }; }`. When `inputs.gen-graph` is present, `impactOf` / `depsOf` (and cycle text) use gen-graph's `dependentsOf` / `reachableFrom` / `cycles`; otherwise a lib-only BFS fallback gives identical results.

### `module/` — NixOS-module adapter & nixpkgs-vars interop (`lib`)

```
generatorsType   : settings → type        # attrsOf submodule, 1:1 with vars.generators
generatorsOption : settings → option
fileModuleSlot   : a deferredModule option (the resolver seam)
mkOnMachineResolver : { fileLocation } → fileModule
```

`generatorsType` is a plain `attrsOf submodule` registry whose file fields (`generator` / `name` / `secret`) are 1:1 with the pure handle — so a generator authored for nixpkgs `vars` evaluates here unchanged. Each `files.<f>` submodule imports `settings.fileModule` (a `deferredModule` resolver) which sets `.path`. `mkOnMachineResolver { fileLocation }` resolves to `${fileLocation}/<secret|public>/<generator>/<file>`, bucketed per file. One `deferredModule` slot = one target; genuine multi-target lives in the consumer's per-class resolver registry over the pure `resolveAll` (see the demo).

### `backend/` — emit a generate script (`lib` + `pkgs`)

```
mkScriptText      : { lib } → { plan; fileLocation ? "/etc/vars" } → string
backends.onMachine: { pkgs; plan; fileLocation ? "/etc/vars" } → { app; store; resolve }
mkHarness         : { plan; store; emitApp; resolve } → { app = emitApp plan; store; resolve; }
```

**`mkScriptText`** is a pure, `lib`-only builder for the on-machine generate script: per generator a tri-state consistency check (all-present → skip; all-missing → generate; mixed → bail), prompt collection, `$in` dependency staging from the secret/public trees, sandboxed (`unset PATH`) script execution into `$out`, post-run verification, then materialization into `<loc>/{secret,public}/<gen>/<file>` honoring per-file `secret` + `deploy`. **`backends.onMachine`** wraps it in `pkgs.writeShellApplication` and returns a harness `{ app; store; resolve }` — `app` is the runnable derivation, `store` is where values live, `resolve` reads them back. **`mkHarness`** is the generic emitter contract any backend implements. *The library runs nothing — it emits an artifact you invoke out of band.*

## Usage Example

A den-agnostic, end-to-end driver (mirrors [`examples/raw-flake`](./examples/raw-flake)):

```nix
{ lib, pkgs }:
let
  genVars = import gen-vars { inherit lib; };
  gens = builtins.mapAttrs genVars.mkGenerator {
    a = { files."a" = { secret = true; }; script = ''echo a > "$out"/a''; };
    b = { dependencies = [ "a" ]; files."b" = { secret = true; }; script = ''cat "$in"/a/a > "$out"/b''; };
  };
  plan = genVars.mkPlan gens;
in
{
  inherit plan;                                                  # order = [ a b ]
  harness = genVars.backends.onMachine { inherit pkgs plan; };   # harness.app builds a generate-vars script
}
```

## Testing

47 nix-unit tests across the four tiers, in seven suites (generator, handle, resolve, plan, module, backend, raw-flake):

```bash
nix flake check ./ci                              # builds the check derivation ("47 tests passed")
nix develop ./ci -c nix-unit --flake ./ci#tests   # run the suite directly
```

CI mirrors the gen ecosystem convention (`gen.lib.mkCi`, shared treefmt + nix-unit). Test leaf names are `test-`prefixed (nix-unit 2.34 only discovers `test*` leaves).

## Design Lineage

gen-vars is engineering over a proven model, not a novel calculus — its honest precedents:

- **nixpkgs `vars` (lassulus, [PR #370444](https://github.com/NixOS/nixpkgs/pull/370444)) and Clan's vars** — the generator model (`$in` / `$out` / `$prompts`, the tri-state on-machine generation semantics) is extracted from here and generalized to be target-agnostic.
- **agenix-rekey** — the system-agnostic decoupling precedent: emit a runnable artifact and let the consumer drive it, rather than coupling generation to a single machine backend.
- **gen-graph** ([Arntzenius & Krishnaswami 2016](https://github.com/sini/gen-graph), monotone reachability) — the *optional* enrichment for `order`'s impact/dependency diagnostics; `mkPlan` always works on `lib.toposort` alone.

The handle/resolver split — a generated file as an open, resolution-free value plus a `resolveAll` fan-out — is gen-vars' own contribution, and the reason one generated file can reach NixOS, terranix, and beyond from a single evaluation.

## License

MIT
