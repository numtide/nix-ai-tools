{ lib }:
final: _prev:
let
  packageNames = builtins.filter (name: builtins.pathExists (../packages + "/${name}/package.nix")) (
    builtins.attrNames (builtins.readDir ../packages)
  );

  npmPackumentSupport = final.callPackage ../lib/fetch-npm-deps.nix { };
  fetchCargoVendor = final.callPackage ../lib/fetch-cargo-vendor/fetch-cargo-vendor.nix { };

  callPackage = lib.callPackageWith (
    final
    // {
      inherit lib;
      flake = { inherit lib; }; # keep the shape of packages.nix, but fail if they try to access unsavory things through flake
      pkgs = final;
      inherit fetchCargoVendor;
    }
    // npmPackumentSupport
  );

  packageOverrides = {
    claudebox = callPackage ../packages/claudebox/package.nix {
      claude-code = final.claude-code;
      sourceDir = "${callPackage ../packages/claudebox/source.nix { }}/src";
    };
  };

  packages = lib.genAttrs packageNames (
    name:
    if builtins.hasAttr name packageOverrides then
      packageOverrides.${name}
    else
      callPackage (../packages + "/${name}/package.nix") { }
  );
in
packages
// {
  llm-agents = packages;
}
