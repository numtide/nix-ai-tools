{
  pkgs,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  nodejs = pkgs.nodejs_24;
  inherit (perSystem.self) buildNpmPackage;
}
