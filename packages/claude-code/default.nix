{
  pkgs,
  perSystem,
  disableTelemetry ? false,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit (perSystem.self) wrapBuddy;
  inherit disableTelemetry;
}
