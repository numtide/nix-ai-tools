{
  pkgs,
  perSystem,
  flake,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  inherit (perSystem.self) buildNpmPackage codex;
}
