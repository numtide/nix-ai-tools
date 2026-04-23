{
  pkgs,
  flake,
  perSystem,
  ...
}:
let
  upstream = pkgs.callPackage ./upstream.nix { };
in
pkgs.callPackage ./package.nix {
  inherit flake upstream;
  inherit (perSystem.self) versionCheckHomeHook;
  gooseServer = pkgs.callPackage ./goose-server.nix {
    inherit flake upstream;
  };
}
