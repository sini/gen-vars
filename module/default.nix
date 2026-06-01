{ lib }: (import ./file-module.nix { inherit lib; }) // (import ./registry.nix { inherit lib; })
