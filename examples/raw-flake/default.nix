# den-agnostic end-to-end: import gen-vars purely, build a plan, emit a harness.
{ lib, pkgs }:
let
  genVars = import ../../. { inherit lib; };
  gens = builtins.mapAttrs genVars.mkGenerator {
    a = {
      files."a" = {
        secret = true;
      };
      script = ''echo a > "$out"/a'';
    };
    b = {
      dependencies = [ "a" ];
      files."b" = {
        secret = true;
      };
      script = ''cat "$in"/a/a > "$out"/b'';
    };
  };
  plan = genVars.mkPlan gens;
in
{
  inherit plan;
  harness = genVars.backends.onMachine {
    inherit pkgs plan;
    fileLocation = "/etc/vars";
  };
}
