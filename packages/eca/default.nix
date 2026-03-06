{
  pkgs,
  flake,
  perSystem,
  ...
}:
import ./package.nix {
  inherit pkgs flake;
  inherit (perSystem.self) wrapBuddy versionCheckHomeHook;
}
