{ pkgs, perSystem }:
pkgs.mkShellNoCC {
  packages = [
    perSystem.self.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
