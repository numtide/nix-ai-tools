{
  pkgs,
  perSystem,
  flake,
  ...
}:
pkgs.callPackage ../openfang/desktop.nix {
  inherit flake;
  inherit (perSystem.self) claude-code;
}
