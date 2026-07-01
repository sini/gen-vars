{
  description = "gen-vars demo: scope-driven, multi-target variable generation";
  inputs = {
    # gen-vars is the parent project; every sibling lib is a direct input
    # (this demo lives inside gen-vars, so there is no gen hub to read from).
    gen-vars.url = "path:../..";

    gen-algebra.url = "github:sini/gen-algebra";
    gen-schema.url = "github:sini/gen-schema";
    gen-aspects.url = "github:sini/gen-aspects";
    gen-scope.url = "github:sini/gen-scope";
    gen-bind.url = "github:sini/gen-bind";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    import-tree.url = "github:sini/import-tree";
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
