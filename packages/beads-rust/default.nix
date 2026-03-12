{
  pkgs,
  flake,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  fetchCargoVendor = pkgs.callPackage ../../lib/fetch-cargo-vendor/fetch-cargo-vendor.nix { };
}
