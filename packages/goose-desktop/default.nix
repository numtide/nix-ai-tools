{
  pkgs,
  flake,
  ...
}:
let
  upstream = pkgs.callPackage ../goose-cli/upstream.nix { };
in
pkgs.callPackage ./package.nix {
  inherit flake upstream;
  gooseServer = pkgs.callPackage ../goose-cli/goose-server.nix {
    inherit flake upstream;
  };
}
