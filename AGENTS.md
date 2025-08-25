# Repository Guidelines

## Project Structure & Module Organization

- Root: `flake.nix`, `flake.lock`, `devshell.nix`, `README.md`.
- Packages live under `packages/<tool>/` with `package.nix`, `default.nix`, optional `update.sh`, and lockfiles when needed.
- Formatting config: `packages/formatter/treefmt.nix`.
- Utilities and docs: `scripts/`, `docs/`, `.github/`.

## Build, Test, and Development Commands

- Enter dev shell: `nix develop`.
- Build a package: `nix build .#<package>` (e.g., `nix build .#claude-code`).
- Run without installing: `nix run .#<package> -- --help`.
- Repo checks (builds + lints): `nix flake check`.
- Format everything: `nix fmt`.
- Regenerate README package section: `mdsh` or `./scripts/generate-package-docs.sh`.

## Coding Style & Naming Conventions

- Indentation: 2 spaces; avoid tabs.
- Nix: small, composable derivations; prefer `buildNpmPackage`/`rustPlatform.buildRustPackage`/`stdenv.mkDerivation` as in existing packages.
- File layout per package: `package.nix` (definition), `default.nix` (wrapper), `update.sh` (optional updater).
- Tools via treefmt: nixfmt, deadnix, shfmt, shellcheck, mdformat, yamlfmt, taplo. Always run `nix fmt` before committing.

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

### Common Issues and Solutions

1. **Rust packages with git dependencies**: May fail during cargo vendoring if dependencies have workspace inheritance issues. Consider using pre-built binaries as a workaround.

1. **Binary packages**: When packaging pre-built binaries:

   - Use `dontUnpack = true` if the download is a single executable file
   - Use `autoPatchelfHook` on Linux to handle dynamic library dependencies
   - Common missing libraries: `gcc-unwrapped.lib` for libgcc_s.so.1

1. **Update scripts**: Follow shellcheck recommendations - declare and assign variables separately to avoid masking return values.
