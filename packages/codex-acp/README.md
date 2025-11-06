# codex-acp

An ACP-compatible (Agent Communication Protocol) coding agent powered by Codex. This package provides a version of codex-acp built for NixOS that can be used with editors like Zed.

## What is ACP?

ACP (Agent Communication Protocol) is a protocol that allows editors and IDEs to communicate with AI coding agents. codex-acp implements this protocol, making it compatible with editors that support ACP, such as Zed.

## Installation

### Build and Install

```bash
# Build the package
nix build github:numtide/nix-ai-tools#codex-acp

# Or add to your system configuration
{
  inputs.nix-ai-tools.url = "github:numtide/nix-ai-tools";
  
  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.codex-acp
  ];
}
```

### Try Without Installing

```bash
nix run github:numtide/nix-ai-tools#codex-acp -- --help
```

## Usage with Zed Editor

Zed editor automatically downloads codex-acp and places it under `~/.local/share/zed/external_agents/codex/`. However, on NixOS, the downloaded binary won't work because it's dynamically linked and expects libraries in standard locations.

### Using codex-acp from this Repository with Zed

To use the NixOS-compatible version of codex-acp with Zed:

1. Install the package to your profile:

   ```bash
   nix profile install github:numtide/nix-ai-tools#codex-acp
   ```

1. Replace Zed's version with a symlink to the installed binary:

   ```bash
   # First, check which version Zed is using
   ls ~/.local/share/zed/external_agents/codex/

   # Then create the symlink (replace VERSION with the version from above)
   ln -sf $(which codex-acp) ~/.local/share/zed/external_agents/codex/VERSION/codex-acp
   ```

1. Restart Zed if it's running.

## Updating

When Zed updates its codex-acp version or when this package is updated:

1. Check the new version directory in `~/.local/share/zed/external_agents/codex/`
1. Update the package: `nix profile upgrade '.*codex-acp.*'`
1. Update the symlink to point to the new version directory

## Troubleshooting

### Zed doesn't recognize codex-acp

- Verify the symlink is correct: `ls -l ~/.local/share/zed/external_agents/codex/*/codex-acp`
- Make sure the binary is executable: `chmod +x ~/.local/share/zed/external_agents/codex/*/codex-acp`
- Check Zed's logs for any error messages

### Version mismatch

If you see version-related errors:

- Check which version Zed expects: `ls ~/.local/share/zed/external_agents/codex/`
- Verify this package version matches or is compatible
- The current package version is listed in `package.nix`

## Links

- [codex-acp GitHub Repository](https://github.com/zed-industries/codex-acp) - Main project repository with protocol implementation
- [Zed Editor](https://zed.dev/)
- [Agent Communication Protocol Specification](https://github.com/zed-industries/acp) - ACP protocol specification

## Building from Source

This package is built from source using Rust. See `package.nix` for the full build configuration.
