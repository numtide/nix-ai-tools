# nix-ai-tools

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

## Available Tools

### AI Coding Assistants

#### claude-code
- **Description**: Anthropic's official Claude Code CLI - an agentic coding tool
- **Version**: 1.0.53
- **License**: Proprietary (unfree)
- **Usage**: `nix run .#claude-code -- --help`

#### opencode
- **Description**: Open-source AI coding agent built for the terminal
- **Version**: 0.3.13
- **License**: MIT
- **Usage**: `nix run .#opencode -- --help`

#### gemini-cli
- **Description**: Google's AI agent bringing Gemini AI to your terminal
- **Version**: 0.1.12
- **License**: Apache 2.0
- **Usage**: `nix run .#gemini-cli -- --help`

### AI Collaboration Tools

#### backlog-md
- **Description**: Project collaboration tool for humans and AI agents in git ecosystems
- **Version**: 1.4.1
- **License**: Check package
- **Usage**: `nix run .#backlog-md -- --help`

### Integration Examples

#### claudebox
- **Integration Focus**: Security and transparency for AI agent execution
- **Key Innovation**: Combines Nix packaging with bubblewrap sandboxing and tmux for real-time monitoring
- **Features**:
  - Runs Claude Code in a bubblewrap sandbox for safety
  - Shows all executed commands in a tmux split pane
  - Provides read-only filesystem access with write access only to current project
  - Command logging and viewing functionality
- **Demonstrates**: How Nix can wrap AI tools with additional security layers
- **Usage**: `nix run .#claudebox`

#### claude-code-router
- **Integration Focus**: Provider abstraction and flexibility
- **Key Innovation**: Decouples AI tool interfaces from specific providers
- **Version**: 1.0.19
- **Features**: Use Claude Code without an Anthropic account by routing to other LLMs
- **Demonstrates**: How Nix can enable swappable AI backends while maintaining consistent interfaces
- **Usage**: `nix run .#claude-code-router -- --help`

### Development Tools

#### formatter
- **Description**: Enhanced treefmt wrapper with format checking
- **Features**: Includes nixfmt, deadnix, shellcheck, shfmt, mdformat, yamlfmt, taplo
- **Usage**: `nix run .#formatter`

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

# Build all packages
nix build .#packages.x86_64-linux.claude-code
nix build .#packages.x86_64-linux.opencode
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
2. Create a feature branch
3. Run `nix fmt` before committing
4. Submit a pull request

## License

Individual tools are licensed under their respective licenses:
- claude-code: Proprietary
- opencode: MIT
- gemini-cli: Apache 2.0
- claude-code-router: Check package
- claudebox: Check package

The Nix packaging code in this repository is licensed under MIT.
