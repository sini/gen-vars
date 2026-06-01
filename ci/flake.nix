{
  inputs = {
    gen.url = "github:sini/gen";
    gen-graph.url = "github:sini/gen-graph";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen,
      gen-graph,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      # genVars WITH gen-graph enrichment (order/ uses gen-graph when present).
      genVars = import ../. {
        inherit lib;
        inputs = { inherit gen-graph; };
      };
      # genVars on the pure lib.toposort fallback path (no gen-graph).
      genVarsPure = import ../. { inherit lib; };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-vars";
      testModules = ./tests;
      specialArgs = {
        inherit genVars genVarsPure lib;
        # for examples/raw-flake (pkgs-using) tests; pure-eval safe (the channels
        # tarball nixpkgs exposes legacyPackages.<system>). nix-unit runs PURE
        # (mkCi never passes --impure), so `import <nixpkgs>` is NOT an option.
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
    };
}
