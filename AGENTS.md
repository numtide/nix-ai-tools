# Repository Guidelines

## Project Structure & Module Organization

- Root: `flake.nix`, `flake.lock`, `devshell.nix`, `README.md`.
- Packages live under `packages/<tool>/` with `package.nix`, `default.nix`, optional `update.py`, and lockfiles when needed.
- Formatting config: `packages/formatter/treefmt.nix`.
- Utilities and docs: `scripts/`, `docs/`, `.github/`.

## Build, Test, and Development Commands

- Enter dev shell: `nix develop`.
- Build a package: `nix build --accept-flake-config .#<package>` (e.g., `nix build .#claude-code`).
- Run without installing: `nix run .#<package> -- --help`.
- Repo checks (builds + lints): `nix flake check`.
- Format everything: `nix fmt`.
- Regenerate README package section: `./scripts/generate-package-docs.py`.

## Coding Style & Naming Conventions

- Indentation: 2 spaces; avoid tabs.
- Nix: small, composable derivations; prefer `buildNpmPackage`/`rustPlatform.buildRustPackage`/`stdenv.mkDerivation` as in existing packages.
- File layout per package: `package.nix` (definition), `default.nix` (wrapper), `update.py` (optional custom updater), `nix-update-args` (optional nix-update flags).
- Tools via treefmt: nixfmt, deadnix, shfmt, shellcheck, mdformat, yamlfmt, taplo. Always run `nix fmt` before committing.

### Updating Packages

**Prefer `nix-update` over custom update scripts.** Most packages can be updated with:

```bash
nix run nixpkgs#nix-update -- --flake <package>
```

For this to work, `package.nix` must have version/hash attributes inline (not loaded from JSON):

```nix
buildGoModule rec {
  pname = "example";
  version = "1.0.0";  # nix-update finds and updates this

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "sha256-...";  # nix-update updates this
  };

  subPackages = [ "." ];  # for go find the relevant packages containing the binary

  vendorHash = "sha256-...";  # nix-update updates this too
}
```

**Testing updates**: After writing or modifying a package, verify updates work by:

1. Temporarily downgrading the version in `package.nix`
1. Running `nix run nixpkgs#nix-update -- --flake <package>`
1. Confirming version and hashes are updated correctly

**Only use custom `update.py` scripts when nix-update cannot handle the package**, such as:

- Packages with complex version schemes nix-update cannot parse
- Sources not supported by nix-update (non-GitHub, custom APIs)
- Packages requiring special hash calculation logic

Custom updaters should use the `scripts/updater/` library. See existing `update.py` files for examples.

### Package Metadata Requirements

Every package MUST have proper metadata in `package.nix`:

```nix
meta = with lib; {
  description = "Clear, concise description";
  homepage = "https://project-homepage.com";
  license = licenses.mit; # or licenses.unfree, etc.
  sourceProvenance = with lib.sourceTypes; [ fromSource ];
  maintainers = with maintainers; [ username ];
  mainProgram = "binary-name";
  platforms = platforms.all; # or specific platforms
};
```

### Package Categories

Every package should have a category in `passthru` for README organization:

```nix
passthru.category = "AI Coding Agents";

meta = { ... };
```

Available categories (in display order):

- **AI Coding Agents** - Main AI coding assistants (claude-code, codex, gemini-cli, etc.)
- **AI Assistants** - General-purpose AI assistants not focused on coding (localgpt, openclaw, etc.)
- **Claude Code Ecosystem** - Tools specifically for Claude Code (claudebox, catnip, etc.)
- **ACP Ecosystem** - Agent Control Protocol implementations (claude-code-acp, codex-acp, agent-client-protocol)
- **Usage Analytics** - Usage tracking and analysis tools (ccusage and variants)
- **Workflow & Project Management** - Project/spec management tools (backlog-md, beads, openspec, spec-kit)
- **Code Review** - Code review tools (coderabbit-cli, tuicr)
- **Utilities** - Other useful tools (coding-agent-search, handy, happy-coder, openskills)

#### Custom Maintainers

For maintainers not yet in nixpkgs, define them in `lib/default.nix`:

```nix
{ inputs, ... }:
inputs.nixpkgs.lib.extend (
  _final: prev: {
    maintainers = prev.maintainers // {
      username = {
        github = "github-username";
        githubId = 123456; # Get from: curl -s https://api.github.com/users/username | jq -r '.id'
        name = "Full Name";
      };
    };
  }
)
```

Then in `packages/<package>/default.nix`, pass `flake` to the package:

```nix
{ pkgs, flake }: pkgs.callPackage ./package.nix { inherit flake; }
```

And in `packages/<package>/package.nix`, reference custom maintainers:

```nix
{
  lib,
  flake,
  # ... other args
}:

stdenv.mkDerivation rec {
  # ...
  meta = with lib; {
    maintainers = with flake.lib.maintainers; [ username ];
    # ... other meta
  };
}
```

### Version Check Hooks

Use `versionCheckHook` to verify packages report correct versions during build:

```nix
doInstallCheck = true;
nativeInstallCheckInputs = [ versionCheckHook ];
```

**For tools that need a writable HOME directory** (many CLI tools try to create config/cache directories), use `versionCheckHomeHook`:

1. In `packages/<package>/default.nix`, pass the hook:

   ```nix
   {
     pkgs,
     perSystem,
     ...
   }:
   pkgs.callPackage ./package.nix {
     inherit (perSystem.self) versionCheckHomeHook;
   }
   ```

1. In `packages/<package>/package.nix`, add it to inputs and use it:

   ```nix
   {
     versionCheckHook,
     versionCheckHomeHook,
     # ...
   }:
   stdenv.mkDerivation {
     # ...
     doInstallCheck = true;
     nativeInstallCheckInputs = [
       versionCheckHook
       versionCheckHomeHook
     ];
   }
   ```

## Testing Guidelines

- Build locally: `nix build .#<package>`.
- Run flake checks: `nix flake check`.
- Per-package checks (when defined): `nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).pkgs-<package>`.
- For scripts, ensure `shellcheck` passes; enable `doCheck = true` in packages when feasible.

## Commit & Pull Request Guidelines

- Commit style mirrors history: `<package>: summary`.
  - Version bumps: `<package>: X -> Y (#123)`; new packages: `<package>: init at X.Y.Z`.
- PRs: clear description, rationale, and testing notes; link issues; include sample run output for CLIs.
- Before pushing: run `nix fmt` and `nix flake check`.

## Security & Configuration Tips

- Some tools are unfree; enable unfree if needed in your Nix config.
- Sandbox experiments: see `packages/claudebox/` for a confined execution wrapper.
- Pin sources with hashes; avoid network access at build time.

## Installing Nix (Required for Package Testing)

When working on package requests or fixes, you MUST install Nix from the official installer to properly test changes,
unless already present

```bash
# Install Nix with daemon mode
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes and nix-command (required for this repository)
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf

# Restart the Nix daemon to apply changes
if [[ "$OSTYPE" == "darwin"* ]]; then
  sudo launchctl kickstart -k system/org.nixos.nix-daemon
else
  sudo systemctl restart nix-daemon
fi
```

### Common Issues and Solutions

1. **Rust packages with git dependencies**: May fail during cargo vendoring if dependencies have workspace inheritance issues. Consider using pre-built binaries as a workaround.

1. **Binary packages**: When packaging pre-built binaries:

   - Use `dontUnpack = true` if the download is a single executable file
   - Use `autoPatchelfHook` on Linux to handle dynamic library dependencies
   - Common missing libraries: `gcc-unwrapped.lib` for libgcc_s.so.1

1. **Update scripts**: Follow shellcheck recommendations - declare and assign variables separately to avoid masking return values.

1. **Custom nix-update arguments**: For packages that need special nix-update flags (e.g., filtering out nightly releases), create a `nix-update-args` file with one argument per line:

   ```text
   # packages/qwen-code/nix-update-args
   --use-github-releases
   --version-regex
   ^v([0-9]+\.[0-9]+\.[0-9]+)$
   ```

   The CI workflow reads this file and passes the arguments to nix-update automatically.
