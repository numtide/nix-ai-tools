{
  pkgs,
  flake,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  inherit (pkgs.npmHooks) npmConfigHook;
  inherit (perSystem.self) versionCheckHomeHook;
}
