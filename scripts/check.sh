#!/usr/bin/env bash
# Typecheck the entire project
# This script runs mypy on the updater library and all update.py scripts

set -euo pipefail

echo "Typechecking updater library..."
mypy scripts/updater

echo "Typechecking update scripts..."
find packages -type f -name 'update.py' -print0 | xargs -0 -n1 -P 0 mypy
