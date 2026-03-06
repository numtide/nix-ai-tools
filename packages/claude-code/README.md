# claude-code

Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster.

## Telemetry

By default, this package does **not** disable telemetry or nonessential network traffic. This is intentional — disabling them breaks features like `remote-control` that depend on these subsystems.

If you want to disable telemetry (at the cost of breaking `remote-control` and potentially other features), use the `disableTelemetry` override:

```nix
claude-code.override { disableTelemetry = true; }
```

Or set the environment variables yourself:

```bash
export DISABLE_TELEMETRY=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

### What's always disabled

The wrapper always sets these regardless of the `disableTelemetry` option:

| Variable | Purpose |
|---|---|
| `DISABLE_AUTOUPDATER=1` | Nix handles updates, auto-updater is unnecessary |
| `DISABLE_INSTALLATION_CHECKS=1` | Suppresses installation method warnings |
| `DISABLE_NON_ESSENTIAL_MODEL_CALLS=1` | Suppresses chatty flavor text from the model (overridable via env) |

## Links

- [Claude Code](https://claude.ai/code)
- [Changelog](https://github.com/anthropics/claude-code/releases)
- [Issue: telemetry breaks remote-control](https://github.com/anthropics/claude-code/issues/28098)
