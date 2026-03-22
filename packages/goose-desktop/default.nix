{
  pkgs,
  perSystem,
  ...
}:
let
  npmPackumentSupport = pkgs.callPackage ../../lib/fetch-npm-deps.nix { };
in
pkgs.callPackage ./package.nix {
  inherit (npmPackumentSupport) fetchNpmDepsWithPackuments npmConfigHook;
  inherit (pkgs) electron_41 runCommand;
  inherit (perSystem.self) goose-server;
}
