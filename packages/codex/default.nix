{
  pkgs,
  ...
}:
pkgs.callPackage ./package.nix {
  fetchCargoVendor = pkgs.callPackage ../../lib/fetch-cargo-vendor/fetch-cargo-vendor.nix { };
}
