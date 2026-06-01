{ lib }:
let
  mkScriptText = import ./script.nix { inherit lib; };
in
{
  pkgs,
  plan,
  fileLocation ? "/etc/vars",
}:
{
  app = pkgs.writeShellApplication {
    name = "generate-vars";
    runtimeInputs = [ pkgs.coreutils ];
    text = mkScriptText { inherit plan fileLocation; };
  };
  store = fileLocation;
  # how a CONSUMER reads a stored value back (the resolver, from `store`).
  resolve =
    handle:
    "${fileLocation}/${
      if handle.secret then "secret" else "public"
    }/${handle.generator}/${handle.name}";
}
