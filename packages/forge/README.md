# Forge Package

This package provides Forge (https://github.com/antinomyhq/forge), an AI-Enhanced Terminal Development Environment.

## Current Implementation

The package uses pre-built binaries from the official GitHub releases. Building from source is currently blocked by upstream dependency issues.

## Source Build Issues

Building from source fails due to a bug in the `rmcp` git dependency from https://github.com/modelcontextprotocol/rust-sdk:

- The rmcp crate specifies `rmcp-macros = { version = "0.1", workspace = true }` which is invalid
- The `workspace = true` conflicts with the explicit version specification
- This causes Nix's `replace-workspace-values` script to fail during cargo vendoring

This issue exists in the specific git revision used by forge (3a97917cd7584c4220815194bcb28b648147a3d8) and persists even in newer versions.

## Files

- `package.nix`: Main package definition (uses pre-built binaries)
- `update.sh`: Update script for new versions
- `default.nix`: Standard wrapper

## Building

```bash
nix build .#forge
```

The package will download and install the appropriate pre-built binary for your platform.
