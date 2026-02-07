{ flake }:
final: _prev:
let
  lib = flake.lib;

  packageNames = builtins.filter (name: builtins.pathExists (../packages + "/${name}/package.nix")) (
    builtins.attrNames (builtins.readDir ../packages)
  );

  npmPackumentSupport = final.callPackage ../lib/fetch-npm-deps.nix { };
  fetchCargoVendor = final.callPackage ../lib/fetch-cargo-vendor/fetch-cargo-vendor.nix { };

  callPackage = lib.callPackageWith (
    final
    // {
      inherit lib flake;
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
