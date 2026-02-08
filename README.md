<img alt="llm-agents.nix" src="https://banner.numtide.com/banner/numtide/llm-agents.nix.svg">

A port of numtide's llm-agents.nix repository for users who prefer overlays. Synced daily.

Please check upstream's [README.md](https://github.com/numtide/llm-agents.nix) for contents and more information.

## Installation

### Using an Overlay

This repository exists because upstream's distribution ships an already-initialized nixpkgs instance.
This means that:

- It builds from its own nixpkgs commit, duplicating the repository. (This can be fixed with `follows`)
- It ships its own initialization configuration (ie `allowUnfree = true`), which you might not want.
- The packages ignore the user's overlaid packages.

Using an overlay is the better option if you want to keep your closure size small and use
`nixpkgs.config`.

How to use:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # or stable, whatever floats your boat

    agents-overlay.url = "github:ulucs/agents-overlay";
    # agents-overlay's nixpkgs dependency will not be downloaded unless you look into the per-system outputs
    # but you can optionally override the nixpkgs input for a smaller flake.lock
    agents-overlay.inputs.nixpgks.follows = "nixpkgs";
  };

  outputs = { nixpkgs, agents-overlay, ... }: {
    # NixOS / nix-darwin configuration
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ...}: {
          nixpkgs.overlays = [ agents-overlay.overlays.default ];
          environment.systemPackages = [
            pkgs.llm-agents.claude-code
            pkgs.llm-agents.codex
            pkgs.llm-agents.gemini-cli
          ];
        })
      ];
    };
  };
}
```
