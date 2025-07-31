# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Building and Testing

```bash
# Enter development shell
nix develop

# Build a specific package
nix build .#claude-code
nix build .#opencode

# Build all packages
nix flake check

# Run a tool without installing
nix run .#claude-code -- --help
nix run .#gemini-cli -- --help

# Format code
nix fmt

# Update packages - each package can be updated individually
# using either its custom update script or nix-update

# For packages with custom update scripts:
./packages/<package-name>/update.sh

# For packages without custom scripts:
nix-update --flake --version=branch <package-name>
```

### Package Development

When adding a new AI tool package:

1. Create directory: `packages/<tool-name>/`
1. Add `package.nix` using existing packages as templates (Node.js tools use `buildNpmPackage`)
1. Add `default.nix` that imports the package
1. Create `update.sh` if the package needs custom update logic
1. The package will be automatically discovered by blueprint

### Testing Individual Packages

```bash
# Build and verify package
nix build .#<package-name>

# Run package checks
nix build .#checks.x86_64-linux.pkgs-<package-name>
```

## High-Level Architecture

This repository uses the **blueprint** framework for flake organization, which automatically discovers and builds packages from the `packages/` directory.

### Core Components

1. **Package Structure**: Each AI tool in `packages/` follows a consistent pattern:

   - `package.nix`: Main package definition (usually `buildNpmPackage` for Node.js tools)
   - `default.nix`: Simple wrapper that imports package.nix
   - `update.sh`: Custom update script for packages with special requirements
   - `package-lock.json`: For Node.js packages requiring dependency locking

1. **Update System**: Package updates are handled by GitHub Actions:

   - Automatically discovers all packages with a `version` attribute
   - Uses custom `update.sh` scripts when available
   - Falls back to `nix-update` for standard packages
   - Creates individual PRs for each update

1. **Security Experiments**: The `claudebox` package demonstrates sandboxed AI execution:

   - Uses bubblewrap for containerization
   - Provides tmux-based monitoring interface
   - Restricts file system and network access

1. **Provider Abstraction**: `claude-code-router` allows switching between LLM backends:

   - Supports multiple AI providers (Claude, OpenAI, etc.)
   - Provides unified interface for different models

1. **Development Environment**: Minimal shell with formatter integration:

   - treefmt configuration includes nixfmt, deadnix, shellcheck, shfmt, mdformat, yamlfmt, taplo
   - All formatting rules defined in `packages/formatter/treefmt.nix`

### Platform Support

The flake supports: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

### Key Design Principles

- **Reproducibility**: All packages use exact version pinning and hash verification
- **Modularity**: Each tool is independently packaged and versioned
- **Automation**: Update scripts handle version bumps and hash recalculation
- **Security**: Experimental sandboxing for AI tool execution
