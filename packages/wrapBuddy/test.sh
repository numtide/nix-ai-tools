#!/usr/bin/env bash
set -euo pipefail

# Test script for wrap-buddy
# Usage: ./test.sh --interp PATH --libs PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERP=""
LIBS=""

while [[ $# -gt 0 ]]; do
  case $1 in
  --interp)
    INTERP="$2"
    shift 2
    ;;
  --libs)
    LIBS="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Detect FHS interpreter for this architecture
ARCH=$(uname -m)
case $ARCH in
x86_64) FHS_INTERP="/lib64/ld-linux-x86-64.so.2" ;;
i686) FHS_INTERP="/lib/ld-linux.so.2" ;;
aarch64) FHS_INTERP="/lib/ld-linux-aarch64.so.1" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

echo "=== Building test binary with FHS interpreter ${FHS_INTERP} ==="
${CC:-cc} -o "$TMPDIR/test" "$SCRIPT_DIR/test_program.c" \
  -Wl,--dynamic-linker="$FHS_INTERP"

echo "=== Patching with wrap-buddy ==="
"$SCRIPT_DIR/wrap-buddy" --paths "$TMPDIR/test" --interpreter "$INTERP" --libs "$LIBS"

echo "=== Config file contents ==="
xxd "$TMPDIR/.test.wrapbuddy"

echo "=== strace output ==="
strace -f "$TMPDIR/test" 2>&1 || true

echo "=== Running patched binary ==="
output=$("$TMPDIR/test" 2>&1)
echo "$output"

if ! echo "$output" | grep -q "Hello from patched binary!"; then
  echo "ERROR: expected output not found"
  exit 1
fi

echo "=== Test passed ==="
