{ demo, ... }:
let
  vt = demo.varsMultiTarget;
in
{
  flake.tests.gen-vars = {
    test-multiTarget = {
      expr = vt.reachesTwoClasses;
      expected = true;
    };
    test-multiResolve = {
      expr = vt.multiResolveProof;
      expected = true;
    };
    test-envBaseline = {
      expr = vt.envBaselineProof;
      expected = true;
    };
    test-union = {
      expr = vt.unionProof;
      expected = true;
    };
  };
}
