{
  pkgs,
  flake,
  cudaSupport ? pkgs.config.cudaSupport or false,
  ...
}:
let
  bun2nix = (pkgs.extend flake.inputs.bun2nix.overlays.default).bun2nix;

  commonArgs = {
    inherit flake bun2nix;
    inherit (pkgs) vulkan-loader autoAddDriverRunpath;
    inherit (pkgs) cudaPackages;
  };

  # CPU-only version (default)
  qmd = pkgs.callPackage ./package.nix (commonArgs // {
    cudaSupport = false;
  });

  # CUDA-enabled version
  qmd-cuda = pkgs.callPackage ./package.nix (commonArgs // {
    cudaSupport = true;
  });
in
{
  inherit qmd qmd-cuda;

  # Default to CPU-only version
  default = qmd;
}
