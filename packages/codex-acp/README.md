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

1. Build the package:
   ```bash
   nix build github:numtide/nix-ai-tools#codex-acp
   ```

2. Replace Zed's version with a symlink to the Nix-built binary:
   ```bash
   # Replace v0.3.12 with the version Zed is using
   ln -sf $(realpath result/bin/codex-acp) ~/.local/share/zed/external_agents/codex/v0.3.12/codex-acp
   ```

3. Restart Zed if it's running.

### Automatic Setup Script

For convenience, you can use this one-liner to build and link codex-acp:

```bash
nix build github:numtide/nix-ai-tools#codex-acp && \
  ln -sf $(realpath result/bin/codex-acp) ~/.local/share/zed/external_agents/codex/v0.3.12/codex-acp
```

> **Note**: Make sure to check which version of codex-acp Zed is using by looking in `~/.local/share/zed/external_agents/codex/` and adjust the version number in the command accordingly.

## Updating

When Zed updates its codex-acp version or when this package is updated:

1. Check the new version directory in `~/.local/share/zed/external_agents/codex/`
2. Rebuild the package: `nix build github:numtide/nix-ai-tools#codex-acp`
3. Update the symlink to point to the new version directory

## Troubleshooting

### Zed doesn't recognize codex-acp

- Verify the symlink is correct: `ls -l ~/.local/share/zed/external_agents/codex/v*/codex-acp`
- Make sure the binary is executable: `chmod +x ~/.local/share/zed/external_agents/codex/v*/codex-acp`
- Check Zed's logs for any error messages

### Version mismatch

If you see version-related errors:
- Check which version Zed expects: `ls ~/.local/share/zed/external_agents/codex/`
- Verify this package version matches or is compatible
- The current package version is listed in `package.nix`

## Links

- [codex-acp GitHub Repository](https://github.com/zed-industries/codex-acp)
- [Zed Editor](https://zed.dev/)
- [ACP Protocol Documentation](https://github.com/zed-industries/codex-acp)

## Building from Source

This package is built from source using Rust. See `package.nix` for the full build configuration.
