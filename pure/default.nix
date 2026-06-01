let
  generator = import ./generator.nix;
  handle = import ./handle.nix;
  resolve = import ./resolve.nix;
in
{
  inherit (generator) mkGenerator normalizeGenerator validateGenerator;
  inherit (handle) mkHandle handleId handlesOf;
  inherit (resolve) mkResolver resolve resolveAll;
}
