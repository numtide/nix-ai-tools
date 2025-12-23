{ pkgs }:
let
  npmPackumentSupport = pkgs.callPackage ../../lib/fetch-npm-deps.nix { };
in
pkgs.callPackage ./package.nix {
  inherit (npmPackumentSupport) fetchNpmDepsWithPackuments npmConfigHook;
}
