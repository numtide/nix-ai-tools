{
  description = "Exploring integration between Nix and AI coding agents";
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      blueprintOutputs = inputs.blueprint {
        inherit inputs;
        nixpkgs.config.allowUnfree = true;
      };

      # Utility packages to exclude from the overlay
      excludedPackages = [
        "formatter"
        "flake-inputs"
        "versionCheckHomeHook"
        "darwinOpenptyHook"
        "wrapBuddy"
      ];
    in
    blueprintOutputs
    // {
      overlays.default = import ./overlays {
        packages = blueprintOutputs.packages;
        inherit excludedPackages;
      };
    };
}
