{
  inputs = {
    # mkCi is a generic nix-unit runner from the gen hub (not gen-vars-coupled);
    # read it from the published hub rather than a local path.
    gen.url = "github:sini/gen";
    demo.url = "path:..";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };
  outputs =
    inputs@{ gen, ... }:
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-vars-multi-target-demo";
      testModules = ./tests;
      specialArgs = {
        demo = inputs.demo;
      };
    };
}
