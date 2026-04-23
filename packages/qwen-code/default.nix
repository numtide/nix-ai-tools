{ pkgs }:
pkgs.callPackage ./package.nix {
  darwinOpenptyHook = pkgs.callPackage ../darwinOpenptyHook { };
}
