# gen-vars REPL — all exports in scope.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  genVars = import ./.. { inherit (nixpkgs) lib; };
in
{
  inherit (nixpkgs) lib;
  inherit genVars;
}
// genVars
