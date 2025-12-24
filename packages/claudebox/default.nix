{ pkgs, perSystem }:
let
  src = pkgs.callPackage ./source.nix { };
in
import ./package.nix {
  inherit pkgs;
  claude-code = perSystem.self.claude-code-npm;
  sourceDir = "${src}/src";
}
