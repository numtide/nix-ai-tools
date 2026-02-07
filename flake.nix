{
  description = "Exploring integration between Nix and AI coding agents";
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      lib = import ./lib { inherit inputs; };

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      packageNames = builtins.filter (name: builtins.pathExists (./packages + "/${name}/default.nix")) (
        builtins.attrNames (builtins.readDir ./packages)
      );

      mkPerSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          callDefault =
            perSystem: name:
            let
              packageFn = import (./packages + "/${name}/default.nix");
              availableArgs = builtins.functionArgs packageFn;
              providedArgs = {
                inherit pkgs perSystem;
                inherit inputs;
                flake = self;
              };
            in
            packageFn (builtins.intersectAttrs availableArgs providedArgs);

          perSystem = {
            self = rawPackages;
          };

          rawPackages = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = callDefault perSystem name;
            }) packageNames
          );

          packages = lib.filterAttrs (_: pkg: (builtins.tryEval pkg.drvPath).success) rawPackages;

          packageChecks = lib.mapAttrs' (name: pkg: {
            name = "pkgs-${name}";
            value = pkg;
          }) packages;

          packageTestChecks = builtins.foldl' (
            acc: name:
            let
              tests = packages.${name}.passthru.tests or { };
            in
            acc
            // lib.mapAttrs' (testName: testDrv: {
              name = "pkgs-${name}-${testName}";
              value = testDrv;
            }) tests
          ) { } (builtins.attrNames packages);

          devShell = import ./devshell.nix {
            inherit pkgs perSystem;
          };
        in
        {
          inherit packages;
          formatter = packages.formatter;
          devShells.default = devShell;
          checks = packageChecks // packageTestChecks // { devshell-default = devShell; };
        };

      perSystemOutputs = builtins.listToAttrs (
        map (system: {
          name = system;
          value = mkPerSystem system;
        }) systems
      );
    in
    {
      inherit lib;

      packages = builtins.mapAttrs (_: output: output.packages) perSystemOutputs;
      checks = builtins.mapAttrs (_: output: output.checks) perSystemOutputs;
      devShells = builtins.mapAttrs (_: output: output.devShells) perSystemOutputs;
      formatter = builtins.mapAttrs (_: output: output.formatter) perSystemOutputs;

      overlays.default = import ./overlays {
        packages = self.packages;
      };
    };
}
