{ genVars, ... }:
let
  g = genVars.mkGenerator "wg-key" {
    files."public.key" = {
      secret = false;
    };
    files."private.key" = { };
    prompts.pass = {
      description = "passphrase";
      type = "hidden";
    };
    script = "true";
  };
in
{
  flake.tests.generator = {
    test-file-backref = {
      expr = g.files."public.key".generator;
      expected = "wg-key";
    };
    test-file-secret-default = {
      expr = g.files."private.key".secret;
      expected = true;
    };
    test-file-secret-explicit = {
      expr = g.files."public.key".secret;
      expected = false;
    };
    test-file-deploy-default = {
      expr = g.files."public.key".deploy;
      expected = true;
    };
    test-prompt-type = {
      expr = g.prompts.pass.type;
      expected = "hidden";
    };
    test-prompt-desc-default = {
      expr = (genVars.mkGenerator "x" { prompts.p = { }; }).prompts.p.description;
      expected = "p";
    };
    test-deps-default = {
      expr = g.dependencies;
      expected = [ ];
    };
    test-valid-empty-errors = {
      expr = genVars.validateGenerator g;
      expected = [ ];
    };
    test-bad-name = {
      expr = genVars.validateGenerator (genVars.mkGenerator "bad name!" { });
      expected = [ ''gen-vars: invalid generator name "bad name!"'' ];
    };
    # file check fires EVEN when the name is also invalid (independent passes).
    test-bad-name-and-file = {
      expr = builtins.length (
        genVars.validateGenerator (genVars.mkGenerator "bad name!" { files."also bad" = { }; })
      );
      expected = 2;
    };
    test-bad-prompt-type = {
      expr = builtins.length (
        genVars.validateGenerator (
          genVars.mkGenerator "ok" {
            prompts.p = {
              type = "nope";
            };
          }
        )
      );
      expected = 1;
    };
  };
}
