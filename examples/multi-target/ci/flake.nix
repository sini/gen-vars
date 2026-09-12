{
  inputs = {
    # mkCi is a generic nix-unit runner from the CI harness (not gen-vars-coupled);
    # read it from the published harness rather than a local path.
    gen-harness.url = "github:sini/gen-harness";
    demo.url = "path:..";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };
  outputs =
    inputs@{ gen-harness, ... }:
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-vars-multi-target-demo";
      testModules = ./tests;
      specialArgs = {
        demo = inputs.demo;
      };
    };
}
