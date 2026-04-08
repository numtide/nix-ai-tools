{
  pkgs,
  flake,
  ...
}:
let
  bun2nix = (pkgs.extend flake.inputs.bun2nix.overlays.default).bun2nix;
  pkgsRust = pkgs.extend flake.inputs.rust-overlay.overlays.default;
  # Upstream pins nightly for a codegen regression:
  # https://github.com/can1357/oh-my-pi/blob/v13.19.0/.github/workflows/ci.yml#L61-L63
  rustToolchain = pkgsRust.rust-bin.nightly."2026-03-27".default;
in
pkgs.callPackage ./package.nix { inherit bun2nix rustToolchain; }
