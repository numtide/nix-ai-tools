{ pkgs, perSystem, ... }:
pkgs.callPackage ./package.nix {
  darwinOpenptyHook = pkgs.callPackage ../darwinOpenptyHook { };
  inherit (perSystem.self) buildNpmPackage versionCheckHomeHook;
}
