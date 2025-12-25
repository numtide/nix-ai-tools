{
  pkgs,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit (perSystem.self) mistralai agent-client-protocol versionCheckHomeHook;
}
