#!/usr/bin/env bash
set -euo pipefail

# claudebox - Run Claude Code in YOLO mode with transparency
# Shows all commands Claude executes in a tmux split pane

# Default options
SPLIT_DIRECTION=horizontal
LOAD_TMUX_CONFIG=true

# Parse command-line arguments
show_help() {
  cat <<EOF
Usage: claudebox [OPTIONS]

Options:
  --split-direction horizontal|vertical   Set tmux split direction (default: horizontal)
  --no-tmux-config                        Don't load user tmux configuration
  -h, --help                              Show this help message

Examples:
  claudebox                               # Run with default settings (user tmux config, and horizontal split)
  claudebox --split-direction vertical
  claudebox --no-tmux-config              # Use default tmux settings
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
  --split-direction)
    SPLIT_DIRECTION="$2"
    if [[ $SPLIT_DIRECTION != "horizontal" && $SPLIT_DIRECTION != "vertical" ]]; then
      echo "Error: --split-direction must be 'horizontal' or 'vertical'" >&2
      exit 1
    fi
    shift 2
    ;;
  --no-tmux-config)
    LOAD_TMUX_CONFIG=false
    shift
    ;;
  -h | --help)
    show_help
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Use --help for usage information" >&2
    exit 1
    ;;
  esac
done

# Generate unique session name for this sandbox
project_dir="$(pwd)"

# Try to find git repo root, fallback to current directory
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$project_dir")"

session_prefix="$(basename "$repo_root")"
session_id="$(printf '%04x%04x' $RANDOM $RANDOM)"
session_name="${session_prefix}-${session_id}"

# Create isolated home directory (protects real home from YOLO mode)
claude_home="/tmp/${session_name}"
at_exit() {
  rm -rf "$claude_home"
}
trap at_exit EXIT
mkdir -p "$claude_home"

# Mount points for Claude config (needs API keys)
claude_config="${HOME}/.claude"
mkdir -p "$claude_config"
claude_json="${HOME}/.claude.json"

# Prepare tmux configuration directories
mkdir -p "$claude_home/.config/tmux"

# Ensure Claude is initialized before sandboxing
if [[ ! -f $claude_json ]]; then
  echo "Initializing Claude configuration..."
  claude --help >/dev/null 2>&1 || true
  sleep 1
fi

# Smart filesystem sharing - full tree read-only, repo/project read-write
real_repo_root="$(realpath "$repo_root")"
real_home="$(realpath "$HOME")"

if [[ $real_repo_root == "$real_home"/* ]]; then
  # Share entire top-level directory as read-only (e.g., ~/projects/*)
  rel_path="${real_repo_root#"$real_home"/}"
  top_dir="$(echo "$rel_path" | cut -d'/' -f1)"
  share_tree="$real_home/$top_dir"
else
  # Only share current repo/project directory
  share_tree="$real_repo_root"
fi

# Bubblewrap sandbox - lightweight isolation for transparency
bwrap_args=(
  --dev /dev
  --proc /proc
  --ro-bind /usr /usr
  --ro-bind /bin /bin
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --ro-bind /etc /etc
  --ro-bind /nix /nix
  --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket # For package installs
  --tmpfs /tmp
  --bind "$claude_home" "$HOME"           # Isolated home (YOLO safety)
  --bind "$claude_config" "$HOME/.claude" # API keys access
  --bind "$claude_json" "$HOME/.claude.json"
  --unshare-all
  --share-net
  --ro-bind /run /run
  --setenv HOME "$HOME"
  --setenv SESSION_NAME "$session_name"
  --setenv USER "$USER"
  --setenv PATH "$PATH"
  --setenv TMUX_TMPDIR "/tmp"
  --setenv TMPDIR "/tmp"
  --setenv TEMPDIR "/tmp"
  --setenv TEMP "/tmp"
  --setenv TMP "/tmp"
)

# Mount tmux configuration (support both traditional and XDG locations)
if [[ $LOAD_TMUX_CONFIG == "true" ]]; then
  if [[ -f "${HOME}/.tmux.conf" ]]; then
    bwrap_args+=(--ro-bind "${HOME}/.tmux.conf" "$HOME/.tmux.conf")
  fi
  if [[ -d "${HOME}/.config/tmux" ]]; then
    bwrap_args+=(--ro-bind "${HOME}/.config/tmux" "$HOME/.config/tmux")
  fi
fi

# Mount parent directory tree if working under home
if [[ $share_tree != "$repo_root" ]]; then
  bwrap_args+=(--ro-bind "$share_tree" "$share_tree")
fi

# Git repo root (or current dir) gets full write access (YOLO mode)
bwrap_args+=(--bind "$repo_root" "$repo_root")

# Define log file path
logfile="/tmp/claudebox-commands-${session_name}.log"

# Determine split flag based on direction
if [[ $SPLIT_DIRECTION == "vertical" ]]; then
  SPLIT_FLAG="-v"
else
  SPLIT_FLAG="-h"
fi

# Add logfile to bwrap environment
bwrap_args+=(--setenv CLAUDEBOX_LOG_FILE "$logfile")

# Launch tmux with Claude in left pane, commands in right
bwrap "${bwrap_args[@]}" bash -c "
  # Change to original working directory
  cd '$project_dir'

  # Create session with Claude directly (no send-keys needed)
  # Launch Claude with --dangerously-skip-permissions (safe in sandbox)
  tmux new-session -d -s '$session_name' -n main 'claude --dangerously-skip-permissions' 2>/dev/null

  # Set large history limit for both panes (50k lines)
  tmux set-option -t '$session_name' history-limit 50000

  # Create right pane for command viewer (keep focus on current pane with -d)
  tmux split-window -d $SPLIT_FLAG -t '$session_name:main' \"exec command-viewer '$logfile'\"

  exec tmux attach -t '$session_name'
"
