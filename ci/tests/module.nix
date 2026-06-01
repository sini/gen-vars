{ genVars, lib, ... }:
let
  # mkOnMachineResolver { fileLocation } is itself a deferredModule: a function
  # `file: { path = ...; }` that reads the file submodule's own config.
  fileModule = genVars.mkOnMachineResolver { fileLocation = "/etc/vars"; };
  evald = lib.evalModules {
    modules = [
      { options.gens = genVars.generatorsOption { inherit fileModule; }; }
      {
        gens.wg-key = {
          files."public.key" = {
            secret = false;
          };
          files."private.key" = { };
        };
      }
    ];
  };
  g = evald.config.gens.wg-key;
in
{
  flake.tests.module = {
    test-file-generator-backref = {
      expr = g.files."public.key".generator;
      expected = "wg-key";
    };
    test-file-name = {
      expr = g.files."public.key".name;
      expected = "public.key";
    };
    test-public-path = {
      expr = g.files."public.key".path;
      expected = "/etc/vars/public/wg-key/public.key";
    };
    test-secret-path = {
      expr = g.files."private.key".path;
      expected = "/etc/vars/secret/wg-key/private.key";
    };
    test-interop-shape = {
      expr = g.files."private.key".secret;
      expected = true;
    };
  };
}
