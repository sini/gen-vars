{ lib, pkgs, ... }:
let
  driver = import ../../examples/raw-flake { inherit lib pkgs; };
in
{
  flake.tests.raw-flake = {
    test-plan-order = {
      expr = map (e: e.name) driver.plan.order;
      expected = [
        "a"
        "b"
      ];
    };
    test-harness-store = {
      expr = driver.harness.store;
      expected = "/etc/vars";
    };
    test-app-is-drv = {
      expr = lib.isDerivation driver.harness.app;
      expected = true;
    };
    test-resolve-reads-store = {
      expr = driver.harness.resolve {
        generator = "a";
        name = "a";
        secret = true;
      };
      expected = "/etc/vars/secret/a/a";
    };
  };
}
