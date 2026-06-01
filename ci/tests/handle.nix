{ genVars, ... }:
let
  h = genVars.mkHandle {
    generator = "wg-key";
    name = "public.key";
    secret = false;
  };
  g = genVars.mkGenerator "wg-key" {
    files."public.key" = {
      secret = false;
    };
    files."private.key" = { };
  };
  hs = genVars.handlesOf g;
in
{
  flake.tests.handle = {
    test-id = {
      expr = genVars.handleId h;
      expected = "wg-key/public.key";
    };
    test-secret-explicit = {
      expr = h.secret;
      expected = false;
    };
    test-secret-default = {
      expr =
        (genVars.mkHandle {
          generator = "g";
          name = "f";
        }).secret;
      expected = true;
    };
    test-no-deploy-on-handle = {
      expr = h ? deploy;
      expected = false;
    };
    test-handlesOf-count = {
      expr = builtins.length hs;
      expected = 2;
    };
    test-handlesOf-secret = {
      expr = (builtins.head (builtins.filter (x: x.name == "private.key") hs)).secret;
      expected = true;
    };
  };
}
