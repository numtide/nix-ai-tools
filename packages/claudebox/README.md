# claudebox - responsible YOLO

Open your project in a liteweight sandbox, and avoid unwanted surprises.

The project shadows your $HOME, so no credentials are accessible (except
~/.claude).
The project parent folder is mounted read-only so it's possible to access
other dependencies.

We also patch Claude to monitor all the executed commands in a tmux side-pane.

![Demo](./claudbox-demo.svg)

## Usage

```bash
claudebox
```

Opens Claude Code with:

- Left pane: Claude interface
- Right pane: Live command log

## What it does

- Lightweight sandbox using bubblewrap
- Intercepts all commands via Node.js instrumentation
- Shows commands in real-time in tmux
- Disables telemetry and auto-updates
- Uses `--dangerously-skip-permissions` (safe in sandbox)

## Note

Not a security boundary - designed for transparency, not isolation.

## Future ideas

- direnv reload integration
- git worktree support
