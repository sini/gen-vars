{
  genVars,
  genVarsPure,
  lib,
  ...
}:
let
  mk = gv: gv.mkGenerator;
  gens = gv: {
    a = (mk gv) "a" {
      files."a" = { };
      script = ''echo a > "$out"/a'';
    };
    b = (mk gv) "b" {
      dependencies = [ "a" ];
      files."b" = { };
      script = ''cat "$in"/a/a > "$out"/b'';
    };
    c = (mk gv) "c" {
      dependencies = [ "b" ];
      files."c" = { };
    };
  };
  planOf = gv: gv.mkPlan (gens gv);
  names = p: map (e: e.name) p.order;
  cyc =
    gv:
    gv.mkPlan {
      x = (mk gv) "x" { dependencies = [ "y" ]; };
      y = (mk gv) "y" { dependencies = [ "x" ]; };
    };
  miss = gv: gv.mkPlan { z = (mk gv) "z" { dependencies = [ "nope" ]; }; };
  tryErr = e: (builtins.tryEval e);
in
{
  flake.tests.plan = {
    test-order-libonly = {
      expr = names (planOf genVarsPure);
      expected = [
        "a"
        "b"
        "c"
      ];
    };
    test-order-graph = {
      expr = names (planOf genVars);
      expected = [
        "a"
        "b"
        "c"
      ];
    };
    test-entry-files-list = {
      expr = (builtins.head (planOf genVarsPure).order).files;
      expected = [
        {
          name = "a";
          generator = "a";
          secret = true;
          deploy = true;
        }
      ];
    };
    test-entry-io = {
      expr = (builtins.head (planOf genVarsPure).order).io.out;
      expected = "$out";
    };
    test-deps-of = {
      expr = builtins.sort builtins.lessThan ((planOf genVarsPure).depsOf "c");
      expected = [
        "a"
        "b"
      ];
    };
    test-impact-of = {
      expr = builtins.sort builtins.lessThan ((planOf genVarsPure).impactOf "a");
      expected = [
        "b"
        "c"
      ];
    };
    test-deps-of-graph = {
      expr = builtins.sort builtins.lessThan ((planOf genVars).depsOf "c");
      expected = [
        "a"
        "b"
      ];
    };
    test-cycle-throws = {
      expr = (tryErr (cyc genVarsPure)).success;
      expected = false;
    };
    test-missing-throws = {
      expr = (tryErr (miss genVarsPure)).success;
      expected = false;
    };
  };
}
