{ genVarsPure, lib, ... }:
let
  gv = genVarsPure;
  gens = {
    a = gv.mkGenerator "a" {
      files."a" = {
        secret = true;
      };
      script = ''echo a > "$out"/a'';
    };
    b = gv.mkGenerator "b" {
      dependencies = [ "a" ];
      files."b" = {
        secret = false;
      };
      files."tmp" = {
        deploy = false;
      };
      script = ''cat "$in"/a/a > "$out"/b ; echo x > "$out"/tmp'';
    };
  };
  plan = gv.mkPlan gens;
  text = gv.mkScriptText {
    inherit plan;
    fileLocation = "/etc/vars";
  };
  hasInfix = lib.hasInfix;
in
{
  flake.tests.backend = {
    test-is-string = {
      expr = builtins.isString text;
      expected = true;
    };
    test-tristate-bail = {
      expr = hasInfix "inconsistent state" text;
      expected = true;
    };
    test-out-dir-default = {
      expr = hasInfix "OUT_DIR:-/etc/vars" text;
      expected = true;
    };
    test-secret-bucket = {
      expr = hasInfix "/secret/a/a" text;
      expected = true;
    };
    test-public-bucket = {
      expr = hasInfix "/public/b/b" text;
      expected = true;
    };
    # deploy=false file (b/tmp) is staged + produce-checked but never mv'd to a target.
    test-deploy-false-checked = {
      expr = hasInfix ''"$out"/tmp'' text;
      expected = true;
    };
    test-lowercase-env = {
      expr = hasInfix "export out" text || hasInfix "out=$(mktemp" text;
      expected = true;
    };
  };
}
