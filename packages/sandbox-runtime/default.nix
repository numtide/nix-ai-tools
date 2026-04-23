{ pkgs, ... }:
pkgs.callPackage ./package.nix {
  nodejs = pkgs.nodejs_24;
}
