{
  pkgs,
  ...
}:
pkgs.callPackage ./package.nix {
  librusty_v8 = pkgs.callPackage ../goose-cli/librusty_v8.nix {
    inherit (pkgs.callPackage ../goose-cli/fetchers.nix { }) fetchLibrustyV8;
  };
}
