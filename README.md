<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/nix-ai-tools-banner--dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/nix-ai-tools-banner--white.svg">
  <img alt="nix-ai-tools" src="docs/nix-ai-tools-banner--white.svg">
</picture>

[![Mentioned in Awesome Gemini CLI](https://awesome.re/mentioned-badge.svg)](https://github.com/Piebald-AI/awesome-gemini-cli)

Exploring the integration between Nix and AI coding agents. This repository serves as a testbed for packaging, sandboxing, and enhancing AI-powered development tools within the Nix ecosystem.

## Daily Updates

This repository uses GitHub Actions to automatically update all packages and flake inputs daily.

## Available Tools

<!-- `> ./scripts/generate-package-docs.sh` -->

<!-- BEGIN mdsh -->
#### amp

- **Description**: CLI for Amp, an agentic coding tool in research preview from Sourcegraph
- **Version**: 0.0.1756425781-g680f4d
- **Source**: bytecode
- **License**: unfree
- **Homepage**: https://ampcode.com/
- **Usage**: `nix run .#amp -- --help`

#### backlog-md

- **Description**: Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem
- **Version**: 1.8.3
- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/MrLesk/Backlog.md
- **Usage**: `nix run .#backlog-md -- --help`

#### catnip

- **Description**: Developer environment that's like catnip for agentic programming
- **Version**: 0.9.2
- **Source**: binary
- **License**: Apache-2.0
- **Homepage**: https://github.com/wandb/catnip
- **Usage**: `nix run .#catnip -- --help`

#### claude-code

- **Description**: Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
- **Version**: 1.0.96
- **Source**: source
- **License**: unfree
- **Homepage**: https://github.com/anthropics/claude-code
- **Usage**: `nix run .#claude-code -- --help`

#### claude-code-router

- **Description**: Use Claude Code without an Anthropics account and route it to another LLM provider
- **Version**: 1.0.43
- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/musistudio/claude-code-router
- **Usage**: `nix run .#claude-code-router -- --help`

#### claude-desktop

- **Description**: Claude Desktop - AI assistant from Anthropic
- **Version**: 0.12.125
- **Source**: binary
- **License**: unfree
- **Homepage**: https://claude.ai
- **Usage**: `nix run .#claude-desktop -- --help`

#### claudebox

- **Description**: Sandboxed environment for Claude Code
- **Version**: unknown
- **Source**: source
- **License**: Check package
- **Homepage**: https://github.com/numtide/nix-ai-tools/tree/main/packages/claudebox
- **Usage**: `nix run .#claudebox -- --help`

#### codex

- **Description**: OpenAI Codex CLI - a coding agent that runs locally on your computer
- **Version**: 0.27.0
- **Source**: binary
- **License**: Apache-2.0
- **Homepage**: https://github.com/openai/codex
- **Usage**: `nix run .#codex -- --help`

#### crush

- **Description**: The glamourous AI coding agent for your favourite terminal
- **Version**: 0.7.4
- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/charmbracelet/crush
- **Usage**: `nix run .#crush -- --help`

#### cursor-agent

- **Description**: Cursor Agent - CLI tool for Cursor AI code editor
- **Version**: 2025.08.27-24c29c1
- **Source**: binary
- **License**: unfree
- **Homepage**: https://cursor.com/
- **Usage**: `nix run .#cursor-agent -- --help`

#### forge

- **Description**: AI-Enhanced Terminal Development Environment - A comprehensive coding agent that integrates AI capabilities with your development environment
- **Version**: 0.111.0
- **Source**: binary
- **License**: MIT
- **Homepage**: https://github.com/antinomyhq/forge
- **Usage**: `nix run .#forge -- --help`

#### gemini-cli

- **Description**: AI agent that brings the power of Gemini directly into your terminal
- **Version**: 0.1.22
- **Source**: bytecode
- **License**: Apache-2.0
- **Homepage**: https://github.com/google-gemini/gemini-cli
- **Usage**: `nix run .#gemini-cli -- --help`

#### goose-cli

- **Description**: CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks
- **Version**: 1.6.0
- **Source**: binary
- **License**: Apache-2.0
- **Homepage**: https://github.com/block/goose
- **Usage**: `nix run .#goose-cli -- --help`

#### groq-code-cli

- **Description**: A highly customizable, lightweight, and open-source coding CLI powered by Groq for instant iteration
- **Version**: 1.0.2-unstable-2025-08-22
- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/build-with-groq/groq-code-cli
- **Usage**: `nix run .#groq-code-cli -- --help`

#### opencode

- **Description**: AI coding agent, built for the terminal
- **Version**: 0.5.28
- **Source**: binary
- **License**: MIT
- **Homepage**: https://github.com/sst/opencode
- **Usage**: `nix run .#opencode -- --help`

#### qwen-code

- **Description**: Command-line AI workflow tool for Qwen3-Coder models
- **Version**: 0.0.9
- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/QwenLM/qwen-code
- **Usage**: `nix run .#qwen-code -- --help`

<!-- END mdsh -->

## Installation

### Using Nix Flakes

Add to your system configuration:

```nix
{
  inputs = {
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
  };

  # In your system packages:
  environment.systemPackages = with inputs.nix-ai-tools.packages.${pkgs.system}; [
    claude-code
    opencode
    gemini-cli
    qwen-code
    # ... other tools
  ];
}
```

### Try Without Installing

```bash
# Try Claude Code
nix run github:numtide/nix-ai-tools#claude-code

# Try OpenCode
nix run github:numtide/nix-ai-tools#opencode

# Try Gemini CLI
nix run github:numtide/nix-ai-tools#gemini-cli

# Try Qwen Code
nix run github:numtide/nix-ai-tools#qwen-code

# etc...
```

## Development

### Setup Development Environment

```bash
nix develop
```

### Building Packages

```bash
# Build a specific package
nix build .#claude-code
nix build .#opencode
nix build .#qwen-code
# etc...
```

### Code Quality

```bash
# Format all code
nix fmt

# Run checks
nix flake check
```

## Package Details

### Platform Support

All packages support:

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Experimental Features

This repository serves as a laboratory for exploring how Nix can enhance AI-powered development:

### Current Experiments

- **Sandboxed execution**: claudebox demonstrates transparent, sandboxed AI agent execution
- **Provider abstraction**: claude-code-router explores decoupling AI interfaces from specific providers
- **Tool composition**: Investigating how multiple AI agents can work together in Nix environments

## Contributing

Contributions are welcome! Please:

1. Fork the repository
1. Create a feature branch
1. Run `nix fmt` before committing
1. Submit a pull request

## See also

- https://github.com/k3d3/claude-desktop-linux-flake

## License

Individual tools are licensed under their respective licenses.

The Nix packaging code in this repository is licensed under MIT.
