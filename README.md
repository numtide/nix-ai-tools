<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/nix-ai-tools-banner--dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/nix-ai-tools-banner--white.svg">
  <img alt="nix-ai-tools" src="docs/nix-ai-tools-banner--white.svg">
</picture>

Exploring the integration between Nix and AI coding agents. This repository serves as a testbed for packaging, sandboxing, and enhancing AI-powered development tools within the Nix ecosystem.

## Project Purpose

As Nix and DevOps consultants, this work is part of our strategic exploration—we are evaluating how LLMs and coding agents will transform our consulting practice and the solutions we deliver to clients. Through these experiments, we aim to:

- **Stay ahead of the curve**: Understand how AI agents will reshape infrastructure-as-code and DevOps practices
- **Enhance our consulting toolkit**: Develop AI-augmented workflows that deliver better results for clients faster
- **Build expertise**: Position ourselves as leaders in AI-enhanced Nix and DevOps consulting
- **Create client value**: Discover how AI agents can solve complex infrastructure challenges more effectively
- **Develop best practices**: Establish patterns for secure, reproducible AI integration in enterprise environments

## Integration Patterns

This project explores several key integration patterns between Nix and AI agents:

### 1. Reproducible AI Tool Deployment

- **Declarative packaging**: All AI tools are packaged as Nix derivations, ensuring reproducible builds across different systems
- **Version pinning**: Exact versions are locked via flake.lock for consistent behavior
- **Cross-platform support**: Native support for Linux and macOS on both x86_64 and aarch64

### 2. Security and Sandboxing

- **claudebox**: Demonstrates running AI agents in bubblewrap sandboxes with restricted filesystem access
- **Transparency**: All AI agent actions are logged and displayed in real-time via tmux integration
- **Controlled access**: Read-only system access with write permissions limited to project directories

### 3. Tool Composition and Routing

- **claude-code-router**: Shows how to decouple AI interfaces from specific providers
- **Alternative backends**: Route requests to different LLM providers while maintaining the same interface
- **Extensibility**: Easy addition of new AI tools through modular package structure

### 4. Development Environment Integration

- **Unified tooling**: AI agents work seamlessly within Nix development shells
- **Format integration**: AI-generated code automatically follows project formatting rules
- **Dependency management**: AI tools have access to all project dependencies through Nix

## Automated Updates

This repository uses GitHub Actions to automatically update all packages and flake inputs daily. Updates are created as individual pull requests for easy review and testing. See `.github/workflows/update.yml` for the workflow configuration.

## Available Tools

`> ./scripts/generate-package-docs.sh`

<!-- BEGIN mdsh -->
#### backlog-md

- **Description**: Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem
- **Version**: 1.6.4
- **License**: MIT
- **Homepage**: https://github.com/MrLesk/Backlog.md
- **Usage**: `nix run .#backlog-md -- --help`

#### claude-code

- **Description**: Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
- **Version**: 1.0.67
- **License**: unfree
- **Homepage**: https://github.com/anthropics/claude-code
- **Usage**: `nix run .#claude-code -- --help`

#### claude-code-router

- **Description**: Use Claude Code without an Anthropics account and route it to another LLM provider
- **Version**: 1.0.31
- **License**: MIT
- **Homepage**: https://github.com/musistudio/claude-code-router
- **Usage**: `nix run .#claude-code-router -- --help`

#### claude-desktop

- **Description**: Claude Desktop - AI assistant from Anthropic
- **Version**: 0.12.55
- **License**: unfree
- **Homepage**: https://claude.ai
- **Usage**: `nix run .#claude-desktop -- --help`

#### claudebox

- **Description**: Sandboxed environment for Claude Code
- **Version**: unknown
- **License**: Check package
- **Usage**: `nix run .#claudebox -- --help`

#### crush

- **Description**: The glamourous AI coding agent for your favourite terminal
- **Version**: 0.2.0
- **License**: MIT
- **Homepage**: https://github.com/charmbracelet/crush
- **Usage**: `nix run .#crush -- --help`

#### formatter

- **Description**: one CLI to format the code tree
- **Version**: unknown
- **License**: MIT
- **Homepage**: https://github.com/numtide/treefmt
- **Usage**: `nix run .#formatter -- --help`

#### gemini-cli

- **Description**: AI agent that brings the power of Gemini directly into your terminal
- **Version**: 0.1.15
- **License**: Apache-2.0
- **Homepage**: https://github.com/google-gemini/gemini-cli
- **Usage**: `nix run .#gemini-cli -- --help`

#### opencode

- **Description**: AI coding agent, built for the terminal
- **Version**: 0.3.101
- **License**: MIT
- **Homepage**: https://github.com/sst/opencode
- **Usage**: `nix run .#opencode -- --help`

#### qwen-code

- **Description**: Command-line AI workflow tool for Qwen3-Coder models
- **Version**: 0.0.2
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

### Dependencies

Most packages are based on Node.js 20, with some providing pre-built binaries. Each package is self-contained with all required dependencies.

## Experimental Features and Future Directions

This repository serves as a laboratory for exploring how Nix can enhance AI-powered development:

### Current Experiments

- **Sandboxed execution**: claudebox demonstrates transparent, sandboxed AI agent execution
- **Provider abstraction**: claude-code-router explores decoupling AI interfaces from specific providers
- **Tool composition**: Investigating how multiple AI agents can work together in Nix environments

### Future Exploration Areas

#### Dynamic Development Environment Integration

- **Automatic devshell reloading**: Enable AI agents to detect and reload their development shells whenever the Nix configuration changes
- **Live environment updates**: Seamless integration of new tools and dependencies without interrupting AI agent sessions
- **State preservation**: Maintain AI agent context across devshell reloads

#### Enhanced Tool Discovery

- **Nixpkgs program indexing**: Make the entire nixpkgs collection queryable by AI agents for dynamic tool discovery
- **Smart tool suggestions**: AI agents can recommend and instantly access appropriate tools from nixpkgs based on task requirements
- **On-demand tool loading**: Just-in-time provisioning of development tools without pre-declaring all dependencies

#### Advanced Workspace Management

- **Git worktree integration**: Enable AI agents to dynamically create and manage git worktrees for parallel development branches
- **Isolated experiment spaces**: Each AI task can operate in its own worktree without affecting the main development flow
- **Automatic context switching**: AI agents can seamlessly move between different worktrees based on task requirements

#### Asynchronous Collaboration

- **Online work sessions**: Support for long-running, asynchronous AI agent sessions that persist beyond terminal sessions
- **Background task execution**: AI agents can continue working on tasks while developers focus on other activities
- **Progress synchronization**: Real-time updates and notifications for ongoing AI agent work
- **Session handoff**: Ability to pause, resume, and transfer AI agent sessions between different environments

#### Additional Research Areas

- **Deterministic AI outputs**: Using Nix's reproducibility features to create more predictable AI behaviors
- **Context management**: Leveraging Nix's declarative nature to manage AI agent contexts and memory
- **Multi-agent orchestration**: Coordinating multiple AI tools through Nix expressions
- **Audit trails**: Complete provenance tracking of AI-generated code through Nix derivations

### Research Questions

#### Technical Integration

- How can AI agents dynamically adapt to changing Nix environments without losing context?
- What's the best way to expose the entire nixpkgs ecosystem to AI agents for tool discovery?
- Can git worktrees provide effective isolation for parallel AI agent experiments?
- How do we build robust asynchronous AI workflows that survive disconnections and environment changes?
- What abstractions are needed to make Nix environments truly AI-native?
- How can we balance AI agent autonomy with security and reproducibility guarantees?

#### Consulting Practice Evolution

- How will AI agents transform Nix and DevOps consulting engagements?
- What new service offerings can we create by combining Nix expertise with AI capabilities?
- How do we help clients adopt AI-enhanced DevOps practices safely and effectively?
- Which infrastructure challenges become trivial with AI assistance vs requiring human expertise?
- How can we use AI to accelerate Nix adoption and reduce the learning curve for clients?
- What governance and compliance frameworks are needed for AI-assisted infrastructure management?

## Contributing

Contributions are welcome! Please:

1. Fork the repository
1. Create a feature branch
1. Run `nix fmt` before committing
1. Submit a pull request

## See also

- https://github.com/k3d3/claude-desktop-linux-flake

## License

Individual tools are licensed under their respective licenses:

- claude-code: Proprietary
- opencode: MIT
- gemini-cli: Apache 2.0
- claude-code-router: Check package
- claudebox: Check package

The Nix packaging code in this repository is licensed under MIT.
