{ pkgs, perSystem, ... }:
import ./package.nix {
  inherit pkgs;
  inherit (perSystem.self) wrapBuddy versionCheckHomeHook;
}
