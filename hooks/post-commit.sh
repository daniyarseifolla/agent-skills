#!/bin/bash
# Post-commit: auto-sync repo skills to ~/.claude/skills/
# Install: ln -sf ../../hooks/post-commit.sh .git/hooks/post-commit

REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "=== Post-commit: Syncing skills ==="
bash "$REPO_ROOT/scripts/install.sh"
