{ pkgs }:
pkgs.mkShellNoCC {
  packages = [
    # Tools needed for update scripts
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.gh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.nix-prefetch-scripts
    pkgs.nix-update
    pkgs.nodejs

    # Formatter
    pkgs.treefmt
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
