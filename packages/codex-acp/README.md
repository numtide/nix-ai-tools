# codex-acp Package

This package provides codex-acp (https://github.com/zed-industries/codex-acp), an ACP adapter for Codex.

## About

codex-acp is an adapter that allows you to use [Codex](https://github.com/openai/codex) from [ACP-compatible](https://agentclientprotocol.com) clients such as [Zed](https://zed.dev).

## Current Implementation

The package uses pre-built binaries from the official GitHub releases. Building from source is problematic due to git dependencies with workspace inheritance issues in the Codex crates.

## Source Build Issues

Building from source fails due to the following challenges:

- The project depends on multiple Codex crates from a git repository using a specific branch (`acp`)
- These git dependencies have workspace inheritance which can cause issues with Nix's cargo vendoring
- Using pre-built binaries is the recommended approach per the repository guidelines

## Files

- `package.nix`: Main package definition (uses pre-built binaries)
- `update.sh`: Update script for new versions
- `default.nix`: Standard wrapper

## Building

```bash
nix build .#codex-acp
```

The package will download and install the appropriate pre-built binary for your platform.

## Usage

```bash
nix run .#codex-acp -- --help
```

Or with environment variable:

```bash
OPENAI_API_KEY=sk-... nix run .#codex-acp
```
