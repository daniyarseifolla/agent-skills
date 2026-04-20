#!/bin/bash
# Pre-commit checks for agent-skills repo
# Install: ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit

set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "=== Pre-commit: Drift Check ==="
bash "$REPO_ROOT/scripts/check-drift.sh"

echo ""
echo "=== Pre-commit: Contract Check ==="
bash "$REPO_ROOT/scripts/check-contracts.sh"

echo ""
echo "All pre-commit checks passed."
