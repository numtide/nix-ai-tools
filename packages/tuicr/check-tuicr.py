#!/usr/bin/env python3
"""Verify tuicr binary works by starting TUI in a git repo and quitting."""

import subprocess
import sys
import tempfile
from pathlib import Path

import pexpect

EXPECTED_ARGS = 2
if len(sys.argv) != EXPECTED_ARGS:
    print(f"Usage: {sys.argv[0]} <tuicr-binary>")
    sys.exit(1)

binary = sys.argv[1]

with tempfile.TemporaryDirectory() as tmpdir:
    # Create a git repo with uncommitted changes
    subprocess.run(["git", "init"], cwd=tmpdir, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )

    # Create and commit a file
    test_file = Path(tmpdir) / "test.txt"
    test_file.write_text("initial content\n")
    subprocess.run(
        ["git", "add", "test.txt"], cwd=tmpdir, check=True, capture_output=True
    )
    subprocess.run(
        ["git", "commit", "-m", "initial"],
        cwd=tmpdir,
        check=True,
        capture_output=True,
    )

    # Make uncommitted changes
    test_file.write_text("modified content\n")

    # Start tuicr and send 'q' to quit
    child = pexpect.spawn(binary, cwd=tmpdir, timeout=5)
    child.expect(pexpect.TIMEOUT, timeout=1)
    child.send("q")
    child.expect(pexpect.EOF, timeout=5)
    child.close()

    if child.exitstatus == 0:
        print("tuicr binary verified working")
        sys.exit(0)
    else:
        print(f"tuicr exited with status {child.exitstatus}")
        sys.exit(1)
