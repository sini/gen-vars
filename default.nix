{
  lib ? null,
  inputs ? { },
}:
let
  pure = import ./pure; # zero-arg, lib-free
  genGraph =
    if lib == null then
      null
    else if inputs ? gen-graph then
      inputs.gen-graph { inherit lib; }
    else
      null;
  order = if lib != null then import ./order { inherit lib genGraph; } else null;
  module = if lib != null then import ./module { inherit lib; } else null;
  backends =
    if lib != null then { onMachine = import ./backend/on-machine.nix { inherit lib; }; } else null;
  # pure script-text builder (lib only), surfaced as mkScriptText.
  mkScriptText = if lib != null then import ./backend/script.nix { inherit lib; } else null;
  # mkHarness: the generic emitter contract (plan -> harness).
  mkHarness =
    if lib == null then
      null
    else
      {
        plan,
        store,
        emitApp,
        resolve,
      }:
      {
        app = emitApp plan;
        inherit store resolve;
      };
in
{
  inherit pure;
}
// pure
// (if order != null then order else { })
// (if module != null then module else { })
// (if backends != null then { inherit backends; } else { })
// (if mkScriptText != null then { inherit mkScriptText; } else { })
// (if mkHarness != null then { inherit mkHarness; } else { })
