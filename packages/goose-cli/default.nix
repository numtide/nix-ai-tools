{
  pkgs,
  ...
}:
pkgs.callPackage ./package.nix {
  librusty_v8 = pkgs.callPackage ./librusty_v8.nix {
    inherit (pkgs.callPackage ./fetchers.nix { }) fetchLibrustyV8;
  };
}
