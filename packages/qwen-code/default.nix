{ pkgs }:
let
  npmPackumentSupport = pkgs.callPackage ./fetch-npm-deps.nix { };
in
pkgs.callPackage ./package.nix {
  darwinOpenptyHook = pkgs.callPackage ../darwinOpenptyHook { };
  inherit (npmPackumentSupport) fetchNpmDepsWithPackuments npmConfigHook;
}
