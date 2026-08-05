# gen-vars — agent capability sheet

## Scope

Target-agnostic vars/secrets algebra: normalizes generator declarations, topologically orders them into a backend-agnostic plan, and fans one resolution-free file handle out to many consumer targets in one evaluation — emitting a generate script, never running it.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Traversal, condensation, cycle enumeration, reachability | `gen-graph` — "gen-graph: accessor-based graph query combinators". The *only* gen sibling gen-vars references in source (`default.nix:10-11`, `flake.nix:4`), and it is **optional**: `order/` falls back to a `lib.toposort` + BFS path |
| The nixpkgs/flake boundary, composing a definition tree purely, injecting resolved values, building NixOS systems | `gen-flake` — "gen-flake — the pure composition boundary of the pure-gen module ecosystem". `examples/multi-target` was migrated onto it at `7b595f4`; the library proper has no flake-side composition |
| Building/evaluating the scope graph that *selects* which generators a host gets | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs". "scope-driven" in gen-vars' own description names the consumer's pattern, not code here — gen-vars carries no scope graph |
| Aspect traits, classification, per-class content | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Injecting resolved values into NixOS modules (`wrap`) | `gen-bind` — "gen-bind: module binding with external arguments for Nix" |
| Minting identity, kinds, instances, typed registries | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system". A gen-vars handle is a plain 3-field record with no `id_hash` |
| Module merge semantics | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system". `module/` uses nixpkgs `lib.evalModules`/`lib.types` directly |
| Type checking / `verify` | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem". `validateGenerator` is a hand-rolled regex + enum pass, not a type checker |
| nixpkgs-lib-free utility base | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem". gen-vars does **not** consume it: the upper tiers take nixpkgs `lib` directly, and `pure/` uses `builtins` only |
| Choosing a winner among competing rules | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |
| Deciding what to regenerate after a change | `gen-rebuild` — "gen-rebuild: pure-Nix incremental rebuilder core (Mokhov rebuilder dimension)". `impactOf` reports the dependent set; it schedules nothing |
| Layered precedence over settings values | `gen-settings` — "gen-settings — stratified settings resolution as a pure layered fold, with refs-as-data, structured provenance, and the graduated injection construct" |
| **Running the generator scripts.** gen-vars emits shell text and a `writeShellApplication` derivation; invoking it is the consumer's, out of band | no gen library — the consumer's deploy path |

## Exports

Entry: `inputs.gen-vars.lib` (flake). The root `default.nix` is a **function** `{ lib ? null, inputs ? { } }:` (`default.nix:1-4`) — unlike most gen siblings, `import ./.` alone is not the library value. Tiers activate by argument: `lib == null` yields the pure tier only.

Every pure-tier name appears **both** at top level and under the `pure` namespace, with equal values.

**Pure tier — generators** (`pure/generator.nix`, `builtins` only)

| Export | Signature |
|---|---|
| `mkGenerator` | `name -> spec -> generator` (curried; applies `secret`/`deploy`/`description`/`type` defaults) |
| `normalizeGenerator` | alias of `mkGenerator` (`pure/generator.nix:35`) |
| `validateGenerator` | `generator -> [errorString]` — never throws |

**Pure tier — handles** (`pure/handle.nix`)

| Export | Signature |
|---|---|
| `mkHandle` | `{ generator; name; secret ? true } -> handle` |
| `handleId` | `handle -> "${generator}/${name}"` |
| `handlesOf` | `normalizedGenerator -> [handle]` |

**Pure tier — resolution** (`pure/resolve.nix`)

| Export | Signature |
|---|---|
| `mkResolver` | `a -> a` — identity/doc tag, validates nothing |
| `resolve` | `resolver -> handle -> resolution` |
| `resolveAll` | `{ <target> = resolver; } -> handle -> { <target> = resolution; }` |
| `pure` | the nine names above as one namespace |

**Order tier** (`order/default.nix`; needs `lib`, optional `inputs.gen-graph`)

| Export | Signature |
|---|---|
| `mkPlan` | `{ <name> = generator; } -> { order = [planEntry]; impactOf = name -> [name]; depsOf = name -> [name]; }` |
| `depGraph` | `generators -> { edges = id -> [id]; nodes = [id]; }` (accessor shape; `edges` is a function) |

**Module tier** (`module/`; needs `lib` + the NixOS module system)

| Export | Signature |
|---|---|
| `generatorsType` | `settings -> type` (`attrsOf submodule`; `settings.fileModule` is **required**) |
| `generatorsOption` | `settings -> option` |
| `fileModuleSlot` | an option *value* (`deferredModule`, `internal`, `default = { }`) — not a function |
| `mkOnMachineResolver` | `{ fileLocation } -> file -> { path }` (a deferredModule reading the file submodule's own config) |

**Backend tier** (`backend/`)

| Export | Signature |
|---|---|
| `mkScriptText` | `{ plan; fileLocation ? "/etc/vars" } -> string` — `lib` is **already applied** at export |
| `backends.onMachine` | `{ pkgs; plan; fileLocation ? "/etc/vars" } -> { app; store; resolve }` |
| `mkHarness` | `{ plan; store; emitApp; resolve } -> { app = emitApp plan; store; resolve; }` |

**Record shapes** (produced, not exported). `handle = { generator; name; secret; }` — no `deploy`, no resolution. `planEntry = { name; dependencies; runtimeInputs; script; files = [fileSpec]; prompts = [promptSpec]; io = { out = "$out"; deps = "$in"; prompts = "$prompts"; }; }`. `fileSpec = { name; generator; secret; deploy; }`. `promptSpec = { name; description; type; }`.

## Entry points by task

| Task | Reach for |
|---|---|
| Normalize a generator declaration | `mkGenerator name spec`; `builtins.mapAttrs mkGenerator` over a set |
| Check a generator without throwing | `validateGenerator g` — returns a list; call it yourself, nothing else does |
| Order generators, detect cycles and missing deps | `mkPlan gens` (throws on both) |
| Ask what a change affects / what a generator needs | `plan.impactOf name` / `plan.depsOf name` |
| Hand a dependency graph to gen-graph | `depGraph gens` (already accessor-shaped) |
| Name one generated file without committing to a target | `mkHandle { generator; name; secret; }`; `handlesOf g` for all of a generator's |
| Stable key for a file | `handleId h` |
| Reach several targets from one file in one eval | `resolveAll { nixos = …; terranix = …; } handle` — the library's reason to exist |
| Expose generators as NixOS options | `generatorsOption { fileModule = …; }` |
| Resolve module-tier files to on-machine paths | `mkOnMachineResolver { fileLocation }` as that `fileModule` |
| Get the generate script as text (no pkgs) | `mkScriptText { plan; fileLocation ? }` |
| Get a runnable harness | `backends.onMachine { pkgs; plan; }` |
| Implement a new backend | `mkHarness { plan; store; emitApp; resolve; }` |
| Use the library with no `lib` at all | `import ./. { }` — pure tier only |

## Measured traps

Every row verified in this run at rev `7b595f4`. Fixtures: `L` = the flake's wired library, reached from the repo root as `nix eval --json .#lib --apply '<fn>'` (nixpkgs `lib` + gen-graph); `Lnull` = `import ./. { }`; `Lpure` = `import ./. { inherit lib; }` (lib, no gen-graph). Absence claims use `git grep`, which cannot see this file (`git check-ignore -v AGENTS.md` ⇒ `/home/sini/.config/git/ignore:22`).

Nix function equality is *always* false, so identity claims below compare **applied results**. Live control this run: `let f = x: x; in { selfEq = f == f; intEq = 1 == 1; }` ⇒ `{"intEq":true,"selfEq":false}`.

| Trap | Evidence |
|---|---|
| **A `deploy = false` file makes its generator fail on every re-run.** The presence check tests *all* files at their `$OUT_DIR` paths, but only `deploy` files are ever materialized — so after one success the generator is permanently "mixed" and bails | `backend/script.nix:17-20` (presence, all files) vs `:48-54` (`mv` gated on `f.deploy`) and `:21-23` (bail). **Executed**: script emitted for a generator with one `deploy = true` + one `deploy = false` file, run twice against a scratch `OUT_DIR` ⇒ run 1 exit `0`, run 2 printed `gen-vars: inconsistent state for generator: g`, exit `1`. Positive control, same two-run protocol, both files `deploy = true` ⇒ exit `0` and `0`, second run printed `all files for g present`. The repo's `test-deploy-false-checked` (`ci/tests/backend.nix`) asserts only that `"$out"/tmp` appears in the emitted text; it does not cover the re-run |
| Root `default.nix` is a function — `import ./.` is not the library | `default.nix:1-4`; `builtins.isFunction (import ./.)` ⇒ `true` |
| `lib == null` silently yields the pure tier only; `mkPlan`/`backends`/`mkScriptText`/`mkHarness`/`generatorsType` are **absent**, not throwing | `default.nix:14-19,21-34`; `attrNames Lnull` ⇒ `["handleId","handlesOf","mkGenerator","mkHandle","mkResolver","normalizeGenerator","pure","resolve","resolveAll","validateGenerator"]`; membership probe ⇒ all five `false`, `pure`/`mkGenerator` `true`. Control: `L` has 19 top-level names |
| `mkGenerator` performs **no** validation — it normalizes an invalid name without complaint | `pure/generator.nix:27-34`; `(L.mkGenerator "bad name!" { }).name` ⇒ `"bad name!"` |
| **Nothing in the library calls `validateGenerator`** — `order`/`module`/`backend` never enforce it | `git grep -ln 'validateGenerator' -- order module backend` ⇒ no hits. Positive control, same command shape: `git grep -ln 'validateGenerator' -- pure` ⇒ `pure/default.nix`, `pure/generator.nix` |
| `validateGenerator` reports name, file and prompt faults **independently** in one list | `pure/generator.nix:38-54`; on a generator bad in all three ⇒ a 3-element list, one message each |
| `mkPlan` **throws** on a missing dep or a cycle (it does not collect them) | `order/default.nix:44-48,58-60`; `tryEval` `.success` ⇒ `false` for both, `true` for a well-formed set |
| …but `depsOf`/`impactOf` on an **unknown** name silently return `[]` — a typo'd query looks like "nothing depends on it" | `order/default.nix:11-28,84-86`; `depsOf "typo"` and `impactOf "typo"` ⇒ `[]` on **both** the gen-graph and lib-only paths. Positive controls, same accessors: `depsOf "b"` ⇒ `["a"]`, `impactOf "a"` ⇒ `["b"]` on both |
| `depsOf`/`impactOf` return **BFS order, not sorted**, and `depsOf` excludes the queried node | `order/default.nix:11-25`; on `c → [b, a]`, `depsOf "c"` ⇒ `["b","a"]` (not alphabetical), `"c" ∈ depsOf "c"` ⇒ `false`. The repo's own `test-deps-of`/`test-impact-of` (`ci/tests/plan.nix`) sort before asserting, so ordering is unasserted |
| The optional gen-graph enrichment and the lib-only fallback agreed **exactly**, including order, on the measured fixture | `order/default.nix:51-57,84-86`; `L` vs `Lpure` over a 4-generator diamond: `depsOf`, `impactOf` identical element-for-element |
| `handlesOf` needs a **normalized** generator; a raw spec is a hard error that `tryEval` does **not** catch | `pure/handle.nix:15-21`; raw spec ⇒ `error: attribute 'name' missing at pure/handle.nix:18` escaping `tryEval`. Positive control, same `deepSeq`+`tryEval` predicate, normalized generator ⇒ `true` |
| A handle carries **no** `deploy` even when the file sets it | `pure/handle.nix:15-21`; file attrs ⇒ `["deploy","generator","name","secret"]`, handle attrs ⇒ `["generator","name","secret"]` |
| `mkHandle` defaults `secret = true` | `pure/handle.nix:4-13`; ⇒ `{"generator":"g","name":"f","secret":true}` |
| `mkResolver` is identity and accepts a non-function without complaint | `pure/resolve.nix:6`; `builtins.isFunction (L.mkResolver 42)` ⇒ `false` |
| `resolveAll { }` ⇒ `{ }` — an empty resolver set is not an error | `pure/resolve.nix:9`; observed `{}` |
| The exported `mkScriptText` is **already** `lib`-applied — it takes `{ plan; … }` directly, and the README's `{ lib } → …` signature is the *file's*, not the export's | `default.nix:19`, `backend/script.nix:1-5`; `L.mkScriptText { plan = …; }` ⇒ a string. Passing `{ lib = 1; }` is an arity error at `backend/script.nix:2` (`called without required argument 'plan'`), not a curried step |
| `mkHarness` **drops** `plan` from its result | `default.nix:21-34`; `attrNames` of the result ⇒ `["app","resolve","store"]` |
| `generatorsOption { }` is a **hard error**, despite `fileModuleSlot` carrying `default = { }` — the slot's default is not `generatorsType`'s | `module/registry.nix:6`, `module/file-module.nix:3-12`; ⇒ `error: attribute 'fileModule' missing at module/registry.nix:6`, escaping `tryEval`. Passing `{ fileModule = { }; }` evaluates and leaves `path` ⇒ `null` |
| The module tier **accepts** the empty generator name the pure tier rejects, producing a malformed path | `pure/generator.nix:3` uses `"[a-zA-Z0-9:_.-]+"`; `module/registry.nix:9,45` use `"[a-zA-Z0-9:_.-]*"`. `validateGenerator` on `""` ⇒ one error; the same name through `evalModules` ⇒ succeeds, `path` ⇒ `"/etc/vars/secret//f"`. Positive controls on a valid name: pure ⇒ `[]`, module ⇒ succeeds |
| `normalizeGenerator` and `mkGenerator` are the same function | `pure/generator.nix:35`; applied to identical arguments the results are `==` ⇒ `true` |
| Generator `files`/`prompts` are **attrsets**; the plan entry's are **lists** | `pure/generator.nix:30-31`, `order/default.nix:62-76`; `typeOf` ⇒ `"set"`/`"set"` on the generator, `"list"`/`"list"` on the entry. `io` is the same three constants on every entry |
| `depGraph.edges` is a **function**, not a list — the value is not serializable | `order/default.nix:6-9`; `isFunction` ⇒ `true`, `edges "b"` ⇒ `["a"]` |
| `pure/` is `lib`-free by construction but has **no purity test** guarding it | `git grep -n 'lib\.' -- pure` ⇒ no hits; positive control, same pattern: `order/default.nix`, `module/registry.nix`, `module/file-module.nix`, `backend/script.nix` all hit. `builtins.isFunction (import ./pure)` ⇒ `false` (zero-arg). `ci/tests/` holds seven suites, none of them a purity check |
| `examples/multi-target` is a **separate flake with its own `ci`** — the repo-root checks command does not cover it | `examples/multi-target/flake.nix:89` declares `gen-vars.url = "path:../.."`; the root `ci/tests/` references only `examples/raw-flake` (`ci/tests/raw-flake.nix:3`). Run separately this run from `examples/multi-target`, `nix flake check ./ci` ⇒ exit `0` |
| `examples/raw-flake` runs on the **lib-only** path — it passes no `inputs`, so the covered example never exercises gen-graph enrichment | `examples/raw-flake/default.nix:4` — `import ../../. { inherit lib; }` |

**Consumer reality** (the tracker calls gen-vars an orphan; this is the measurement, not the judgement). Across the 30 local repos under `~/Documents/repos/sini/` and `~/Documents/repos/denful/den`, `git grep -n 'gen-vars' -- '*flake.nix'` returns **no** repo declaring gen-vars as an input. Positive control, same predicate: gen-graph is declared in 11 repos' `flake.nix` files. Every other cross-repo hit is a README ecosystem table; the sole code-adjacent reference is a comment (`gen-prelude/lib/default.nix:80`). gen-vars is also **not** in the hub roster — `grep -n 'vars' gen/lib/mkGenLibs.nix` ⇒ no hits, control `grep -n 'graph'` ⇒ hits. Scope limit: local checkouts only, not a GitHub-wide search.

## Theory

The repo makes **no novel-calculus claim**. `README.md:217-225` heads its section *Design Lineage* and states gen-vars "is engineering over a proven model, not a novel calculus" — so precedents, not an Implements/Informed-by split. Source carries almost no citation comments: `git grep` over `pure order module backend default.nix` for lineage terms returns one hit, `module/registry.nix:6` (`# the resolver seam (Option 3)`), alongside `pure/handle.nix:2` (`# Option-1 handle`) — internal design-option labels, not literature.

**Precedents claimed** (`README.md:221-223`)

- **nixpkgs `vars` (lassulus, PR #370444) and Clan's vars** — the generator model (`$in` / `$out` / `$prompts`, the tri-state on-machine generation semantics) is extracted from here and generalized to be target-agnostic.
- **agenix-rekey** — the precedent for emitting a runnable artifact and letting the consumer drive it rather than coupling generation to one machine backend.
- **gen-graph** — the *optional* enrichment for `order`'s impact/dependency diagnostics.

**Claimed as gen-vars' own** (`README.md:225`): the handle/resolver split — a generated file as an open, resolution-free value plus a `resolveAll` fan-out.

**Dependency class** (`README.md:7`): *nixpkgs-lib-tethered* — builds on `nixpkgs.lib` (`toposort`, the module system), with `pure/` `lib`-free by construction. Unenforced by tests; see traps.

## Drift check

```sh
nix eval --json .#lib --apply 'l: { top = builtins.attrNames l; pure = builtins.attrNames l.pure; backends = builtins.attrNames l.backends; }'
```

Current output (verbatim):

```json
{"backends":["onMachine"],"pure":["handleId","handlesOf","mkGenerator","mkHandle","mkResolver","normalizeGenerator","resolve","resolveAll","validateGenerator"],"top":["backends","depGraph","fileModuleSlot","generatorsOption","generatorsType","handleId","handlesOf","mkGenerator","mkHandle","mkHarness","mkOnMachineResolver","mkPlan","mkResolver","mkScriptText","normalizeGenerator","pure","resolve","resolveAll","validateGenerator"]}
```

**Checks.** This repo has **no CI workflow** — `git ls-files -- '.github'` returns nothing and no `*.yml` exists outside `.direnv`/`.git` (positive control, same two commands in `gen-select`: 2 tracked files, `.github/workflows/ci.yml`). `README.md:3` still badges `actions/workflows/ci.yml`, which is not in the tree. The command below is the one `README.md:211` documents; it was run from the repo root this run and exited `0` unmasked:

```sh
nix flake check ./ci
```
