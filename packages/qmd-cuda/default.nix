{
  pkgs,
  flake,
  ...
}:
let
  bun2nix = (pkgs.extend flake.inputs.bun2nix.overlays.default).bun2nix;
in
pkgs.callPackage ./package.nix {
  inherit flake bun2nix;
  inherit (pkgs) vulkan-loader autoAddDriverRunpath;
  inherit (pkgs) cudaPackages;
  cudaSupport = true;  # Force CUDA on for this variant
}
