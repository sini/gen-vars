# nixpkgs `vars` interop note

The file submodule field names (`generator` / `name` / `secret`) are 1:1 with the
pure-core handle, so `config.vars.generators.<g>.files.<f>` IS a core handle modulo
`.path` / `.value`. A generator authored for nixpkgs `vars` evaluates here unchanged:
the `attrsOf submodule` registry in `module/registry.nix` is structurally the same shape
as nixpkgs `vars.generators`.

`runtimeInputs` defaults to `[ ]` in the module tier (there is no `pkgs` here); the
backend prepends `coreutils` to `PATH` itself, so a generator script always sees the
core utilities regardless of what `runtimeInputs` declares.
