{ genVars, ... }:
let
  h = genVars.mkHandle {
    generator = "wg-key";
    name = "public.key";
    secret = false;
  };
  pathR = handle: "/etc/vars/${handle.generator}/${handle.name}";
  refR = handle: { ref = "vars_file.${handle.generator}_${handle.name}"; };
  out = genVars.resolveAll {
    nixos = pathR;
    terranix = refR;
  } h;
in
{
  flake.tests.resolve = {
    test-single = {
      expr = genVars.resolve pathR h;
      expected = "/etc/vars/wg-key/public.key";
    };
    test-mkResolver-identity = {
      expr = genVars.mkResolver pathR h;
      expected = "/etc/vars/wg-key/public.key";
    };
    test-fanout-nixos = {
      expr = out.nixos;
      expected = "/etc/vars/wg-key/public.key";
    };
    test-fanout-terranix-open = {
      expr = out.terranix.ref;
      expected = "vars_file.wg-key_public.key";
    };
    test-fanout-targets = {
      expr = builtins.attrNames out;
      expected = [
        "nixos"
        "terranix"
      ];
    };
  };
}
