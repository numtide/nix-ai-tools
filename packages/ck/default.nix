{
  pkgs,
  ...
}:
pkgs.callPackage ./package.nix {
  onnxruntime = pkgs.callPackage ../../lib/onnxruntime-override.nix { };
}
