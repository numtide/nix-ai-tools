{
  pkgs,
  perSystem,
  ...
}:
let
  npmPackumentSupport = pkgs.callPackage ../../lib/fetch-npm-deps.nix { };
in
pkgs.callPackage ./package.nix {
  inherit (perSystem.self) versionCheckHomeHook;
  inherit (npmPackumentSupport) fetchNpmDepsWithPackuments npmConfigHook;
}
