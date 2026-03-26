{
  pkgs,
  perSystem,
  flake,
  ...
}:
let
  onnxruntime' = pkgs.callPackage ../../lib/onnxruntime-override.nix { };
  python3' = pkgs.python3.override {
    packageOverrides = _final: prev: {
      onnxruntime = prev.onnxruntime.override { onnxruntime = onnxruntime'; };
    };
  };
in
pkgs.callPackage ./package.nix {
  inherit flake;
  inherit (perSystem.self) versionCheckHomeHook;
  python3 = python3';
}
