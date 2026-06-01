{
  description = "gen-vars: scope-driven, multi-target variable generation";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.gen-graph.url = "github:sini/gen-graph"; # optional order/ enrichment
  outputs =
    { nixpkgs, gen-graph, ... }:
    {
      lib = import ./. {
        lib = nixpkgs.lib;
        inputs = { inherit gen-graph; };
      };
      __functor = _: import ./.;
    };
}
