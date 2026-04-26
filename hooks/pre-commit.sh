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
echo "=== Pre-commit: Frontmatter Lint ==="
bash "$REPO_ROOT/scripts/check-frontmatter.sh"

echo ""
echo "=== Pre-commit: Trigger Evals ==="
bash "$REPO_ROOT/scripts/check-triggers.sh"

echo ""
echo "=== Pre-commit: Dependency Resolution ==="
bash "$REPO_ROOT/scripts/check-deps.sh"

echo ""
echo "All pre-commit checks passed."
