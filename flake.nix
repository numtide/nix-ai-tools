{
  description = "Exploring integration between Nix and AI coding agents";
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      packageNames = builtins.filter (name: builtins.pathExists (./packages + "/${name}/package.nix")) (
        builtins.attrNames (builtins.readDir ./packages)
      );

      overlays.default = import ./overlays;

      mkPerSystem =
        system:
        let
          inherit (nixpkgs) lib;

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlays.default ];
          };

          rawPackages = lib.genAttrs packageNames (name: pkgs.${name});

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

          devShell = import ./devshell.nix { inherit pkgs; };
        in
        {
          inherit packages;
          formatter = pkgs.treefmt;
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
      packages = builtins.mapAttrs (_: output: output.packages) perSystemOutputs;
      checks = builtins.mapAttrs (_: output: output.checks) perSystemOutputs;
      devShells = builtins.mapAttrs (_: output: output.devShells) perSystemOutputs;
      formatter = builtins.mapAttrs (_: output: output.formatter) perSystemOutputs;
      inherit overlays;
    };
}
