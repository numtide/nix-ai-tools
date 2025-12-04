<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/numtide/nix-ai-tools/releases/download/assets/nix-ai-tools-banner--dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/numtide/nix-ai-tools/releases/download/assets/nix-ai-tools-banner--white.svg">
  <img alt="nix-ai-tools" src="https://github.com/numtide/nix-ai-tools/releases/download/assets/nix-ai-tools-banner--white.svg">
</picture>

[![Mentioned in Awesome Gemini CLI](https://awesome.re/mentioned-badge.svg)](https://github.com/Piebald-AI/awesome-gemini-cli)

Nix packages for AI coding agents and development tools. Automatically updated daily.

## Available Tools

<!-- `> ./scripts/generate-package-docs.py` -->

<!-- BEGIN mdsh -->

<details>
<summary><strong>amp</strong> - CLI for Amp, an agentic coding tool in research preview from Sourcegraph</summary>

- **Source**: bytecode
- **License**: unfree
- **Homepage**: https://ampcode.com/
- **Usage**: `nix run github:numtide/nix-ai-tools#amp -- --help`
- **Nix**: [packages/amp/package.nix](packages/amp/package.nix)

</details>
<details>
<summary><strong>backlog-md</strong> - Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/MrLesk/Backlog.md
- **Usage**: `nix run github:numtide/nix-ai-tools#backlog-md -- --help`
- **Nix**: [packages/backlog-md/package.nix](packages/backlog-md/package.nix)

</details>
<details>
<summary><strong>beads</strong> - A distributed issue tracker designed for AI-supervised coding workflows</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/steveyegge/beads
- **Usage**: `nix run github:numtide/nix-ai-tools#beads -- --help`
- **Nix**: [packages/beads/package.nix](packages/beads/package.nix)

</details>
<details>
<summary><strong>catnip</strong> - Developer environment that's like catnip for agentic programming</summary>

- **Source**: binary
- **License**: Apache-2.0
- **Homepage**: https://github.com/wandb/catnip
- **Usage**: `nix run github:numtide/nix-ai-tools#catnip -- --help`
- **Nix**: [packages/catnip/package.nix](packages/catnip/package.nix)

</details>
<details>
<summary><strong>ccstatusline</strong> - A highly customizable status line formatter for Claude Code CLI</summary>

- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/sirmalloc/ccstatusline
- **Usage**: `nix run github:numtide/nix-ai-tools#ccstatusline -- --help`
- **Nix**: [packages/ccstatusline/package.nix](packages/ccstatusline/package.nix)

</details>
<details>
<summary><strong>ccusage</strong> - Usage analysis tool for Claude Code</summary>

- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/ryoppippi/ccusage
- **Usage**: `nix run github:numtide/nix-ai-tools#ccusage -- --help`
- **Nix**: [packages/ccusage/package.nix](packages/ccusage/package.nix)

</details>
<details>
<summary><strong>ccusage-codex</strong> - Usage analysis tool for OpenAI Codex sessions</summary>

- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/ryoppippi/ccusage
- **Usage**: `nix run github:numtide/nix-ai-tools#ccusage-codex -- --help`
- **Nix**: [packages/ccusage-codex/package.nix](packages/ccusage-codex/package.nix)

</details>
<details>
<summary><strong>claude-code</strong> - Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster</summary>

- **Source**: source
- **License**: unfree
- **Homepage**: https://github.com/anthropics/claude-code
- **Usage**: `nix run github:numtide/nix-ai-tools#claude-code -- --help`
- **Nix**: [packages/claude-code/package.nix](packages/claude-code/package.nix)

</details>
<details>
<summary><strong>claude-code-acp</strong> - An ACP-compatible coding agent powered by the Claude Code SDK (TypeScript)</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/zed-industries/claude-code-acp
- **Usage**: `nix run github:numtide/nix-ai-tools#claude-code-acp -- --help`
- **Nix**: [packages/claude-code-acp/package.nix](packages/claude-code-acp/package.nix)

</details>
<details>
<summary><strong>claude-code-router</strong> - Use Claude Code without an Anthropics account and route it to another LLM provider</summary>

- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/musistudio/claude-code-router
- **Usage**: `nix run github:numtide/nix-ai-tools#claude-code-router -- --help`
- **Nix**: [packages/claude-code-router/package.nix](packages/claude-code-router/package.nix)

</details>
<details>
<summary><strong>claudebox</strong> - Sandboxed environment for Claude Code</summary>

- **Source**: source
- **License**: Check package
- **Homepage**: https://github.com/numtide/nix-ai-tools/tree/main/packages/claudebox
- **Usage**: `nix run github:numtide/nix-ai-tools#claudebox -- --help`
- **Nix**: [packages/claudebox/package.nix](packages/claudebox/package.nix)
- **Documentation**: See [packages/claudebox/README.md](packages/claudebox/README.md) for detailed usage

</details>
<details>
<summary><strong>code</strong> - Fork of codex. Orchestrate agents from OpenAI, Claude, Gemini or any provider.</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/just-every/code/
- **Usage**: `nix run github:numtide/nix-ai-tools#code -- --help`
- **Nix**: [packages/code/package.nix](packages/code/package.nix)

</details>
<details>
<summary><strong>coderabbit-cli</strong> - AI-powered code review CLI tool</summary>

- **Source**: binary
- **License**: unfree
- **Homepage**: https://coderabbit.ai
- **Usage**: `nix run github:numtide/nix-ai-tools#coderabbit-cli -- --help`
- **Nix**: [packages/coderabbit-cli/package.nix](packages/coderabbit-cli/package.nix)

</details>
<details>
<summary><strong>codex</strong> - OpenAI Codex CLI - a coding agent that runs locally on your computer</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/openai/codex
- **Usage**: `nix run github:numtide/nix-ai-tools#codex -- --help`
- **Nix**: [packages/codex/package.nix](packages/codex/package.nix)

</details>
<details>
<summary><strong>codex-acp</strong> - An ACP-compatible coding agent powered by Codex</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/zed-industries/codex-acp
- **Usage**: `nix run github:numtide/nix-ai-tools#codex-acp -- --help`
- **Nix**: [packages/codex-acp/package.nix](packages/codex-acp/package.nix)
- **Documentation**: See [packages/codex-acp/README.md](packages/codex-acp/README.md) for detailed usage

</details>
<details>
<summary><strong>copilot-cli</strong> - GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal.</summary>

- **Source**: bytecode
- **License**: unfree
- **Homepage**: https://github.com/github/copilot-cli
- **Usage**: `nix run github:numtide/nix-ai-tools#copilot-cli -- --help`
- **Nix**: [packages/copilot-cli/package.nix](packages/copilot-cli/package.nix)

</details>
<details>
<summary><strong>crush</strong> - The glamourous AI coding agent for your favourite terminal</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/charmbracelet/crush
- **Usage**: `nix run github:numtide/nix-ai-tools#crush -- --help`
- **Nix**: [packages/crush/package.nix](packages/crush/package.nix)

</details>
<details>
<summary><strong>cursor-agent</strong> - Cursor Agent - CLI tool for Cursor AI code editor</summary>

- **Source**: binary
- **License**: unfree
- **Homepage**: https://cursor.com/
- **Usage**: `nix run github:numtide/nix-ai-tools#cursor-agent -- --help`
- **Nix**: [packages/cursor-agent/package.nix](packages/cursor-agent/package.nix)

</details>
<details>
<summary><strong>droid</strong> - Factory AI's Droid - AI-powered development agent for your terminal</summary>

- **Source**: binary
- **License**: unfree
- **Homepage**: https://factory.ai
- **Usage**: `nix run github:numtide/nix-ai-tools#droid -- --help`
- **Nix**: [packages/droid/package.nix](packages/droid/package.nix)

</details>
<details>
<summary><strong>eca</strong> - Editor Code Assistant (ECA) - AI pair programming capabilities agnostic of editor</summary>

- **Source**: binary
- **License**: Apache-2.0
- **Homepage**: https://github.com/editor-code-assistant/eca
- **Usage**: `nix run github:numtide/nix-ai-tools#eca -- --help`
- **Nix**: [packages/eca/package.nix](packages/eca/package.nix)

</details>
<details>
<summary><strong>forge</strong> - AI-Enhanced Terminal Development Environment - A comprehensive coding agent that integrates AI capabilities with your development environment</summary>

- **Source**: binary
- **License**: MIT
- **Homepage**: https://github.com/antinomyhq/forge
- **Usage**: `nix run github:numtide/nix-ai-tools#forge -- --help`
- **Nix**: [packages/forge/package.nix](packages/forge/package.nix)
- **Documentation**: See [packages/forge/README.md](packages/forge/README.md) for detailed usage

</details>
<details>
<summary><strong>gemini-cli</strong> - AI agent that brings the power of Gemini directly into your terminal</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/google-gemini/gemini-cli
- **Usage**: `nix run github:numtide/nix-ai-tools#gemini-cli -- --help`
- **Nix**: [packages/gemini-cli/package.nix](packages/gemini-cli/package.nix)

</details>
<details>
<summary><strong>goose-cli</strong> - CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/block/goose
- **Usage**: `nix run github:numtide/nix-ai-tools#goose-cli -- --help`
- **Nix**: [packages/goose-cli/package.nix](packages/goose-cli/package.nix)

</details>
<details>
<summary><strong>handy</strong> - Fast and accurate local transcription app using AI models</summary>

- **Source**: binary
- **License**: unfree
- **Homepage**: https://handy.computer/
- **Usage**: `nix run github:numtide/nix-ai-tools#handy -- --help`
- **Nix**: [packages/handy/package.nix](packages/handy/package.nix)

</details>
<details>
<summary><strong>kilocode-cli</strong> - The open-source AI coding agent. Now available in your terminal.</summary>

- **Source**: bytecode
- **License**: Apache-2.0
- **Homepage**: https://kilocode.ai/cli
- **Usage**: `nix run github:numtide/nix-ai-tools#kilocode-cli -- --help`
- **Nix**: [packages/kilocode-cli/package.nix](packages/kilocode-cli/package.nix)

</details>
<details>
<summary><strong>nanocoder</strong> - A beautiful local-first coding agent running in your terminal - built by the community for the community ⚒</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/Mote-Software/nanocoder
- **Usage**: `nix run github:numtide/nix-ai-tools#nanocoder -- --help`
- **Nix**: [packages/nanocoder/package.nix](packages/nanocoder/package.nix)

</details>
<details>
<summary><strong>opencode</strong> - AI coding agent built for the terminal</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/sst/opencode
- **Usage**: `nix run github:numtide/nix-ai-tools#opencode -- --help`
- **Nix**: [packages/opencode/package.nix](packages/opencode/package.nix)

</details>
<details>
<summary><strong>openskills</strong> - Universal skills loader for AI coding agents - install and load Anthropic SKILL.md format skills in any agent</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/numman-ali/openskills
- **Usage**: `nix run github:numtide/nix-ai-tools#openskills -- --help`
- **Nix**: [packages/openskills/package.nix](packages/openskills/package.nix)

</details>
<details>
<summary><strong>openspec</strong> - Spec-driven development for AI coding assistants</summary>

- **Source**: bytecode
- **License**: MIT
- **Homepage**: https://github.com/Fission-AI/OpenSpec
- **Usage**: `nix run github:numtide/nix-ai-tools#openspec -- --help`
- **Nix**: [packages/openspec/package.nix](packages/openspec/package.nix)

</details>
<details>
<summary><strong>qwen-code</strong> - Command-line AI workflow tool for Qwen3-Coder models</summary>

- **Source**: source
- **License**: Apache-2.0
- **Homepage**: https://github.com/QwenLM/qwen-code
- **Usage**: `nix run github:numtide/nix-ai-tools#qwen-code -- --help`
- **Nix**: [packages/qwen-code/package.nix](packages/qwen-code/package.nix)

</details>
<details>
<summary><strong>spec-kit</strong> - Specify CLI, part of GitHub Spec Kit. A tool to bootstrap your projects for Spec-Driven Development (SDD)</summary>

- **Source**: source
- **License**: MIT
- **Homepage**: https://github.com/github/spec-kit
- **Usage**: `nix run github:numtide/nix-ai-tools#spec-kit -- --help`
- **Nix**: [packages/spec-kit/package.nix](packages/spec-kit/package.nix)

</details>
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

### Binary Cache

Pre-built binaries are available from the Numtide Cachix cache. All packages are built daily via CI and pushed to the cache, so you can avoid compiling from source.

This cache is automatically configured when this flake is used directly (e.g `nix run github:numtide/nix-ai-tools#claude-code`)

To use the binary cache when using this flake as an input, add `nixConfig` to your flake:

```nix
{
  nixConfig = {
    extra-substituters = [ "https://numtide.cachix.org" ];
    extra-trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" ];
  };
}
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
