{
  pkgs,
  perSystem,
  ...
}:
let
  inherit (perSystem.self) versionCheckHomeHook;
in
pkgs.callPackage ./package.nix { inherit versionCheckHomeHook; }
