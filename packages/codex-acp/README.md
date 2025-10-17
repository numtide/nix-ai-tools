# codex-acp Package

This package provides codex-acp (https://github.com/zed-industries/codex-acp), an ACP adapter for Codex.

## About

codex-acp is an adapter that allows you to use [Codex](https://github.com/openai/codex) from [ACP-compatible](https://agentclientprotocol.com) clients such as [Zed](https://zed.dev).

## Current Implementation

The package builds from source using Rust's cargo build system.

## Files

- `package.nix`: Main package definition (builds from source)
- `update.sh`: Update script for new versions
- `default.nix`: Standard wrapper

## Building

```bash
nix build .#codex-acp
```

The package will build codex-acp from source.

## Usage

```bash
nix run .#codex-acp -- --help
```

Or with environment variable:

```bash
OPENAI_API_KEY=sk-... nix run .#codex-acp
```
