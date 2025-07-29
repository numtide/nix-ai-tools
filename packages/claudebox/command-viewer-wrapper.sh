#!/usr/bin/env bash
# Wrapper script that logs command-viewer execution
set -euo pipefail

# Get the session name from environment
session_name="${SESSION_NAME:-unknown}"
wrapper_log="/tmp/claudebox-viewer-wrapper-${session_name}.log"

# Log that we're starting the viewer
{
  echo "[$(date -Iseconds)] Starting command-viewer wrapper"
  echo "[$(date -Iseconds)] Arguments: $*"
  echo "[$(date -Iseconds)] Session: $session_name"
} >>"$wrapper_log"

# Execute the real command-viewer and capture its exit status
exit_code=0
"$COMMAND_VIEWER_REAL" "$@" || exit_code=$?

# Log the exit
echo "[$(date -Iseconds)] command-viewer exited with code: $exit_code" >>"$wrapper_log"

# Exit with the same code
exit $exit_code
