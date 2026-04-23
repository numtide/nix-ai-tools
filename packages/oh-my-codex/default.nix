{
  pkgs,
  perSystem,
  flake,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  codex = perSystem.self.codex;
}
