---
description: "Clean up pipeline artifacts. Usage: /cleanup ARGO-12345"
---

# Cleanup

Task key: $ARGUMENTS

Actions (ask confirmation for each):

1. Read checkpoint FIRST: docs/plans/{task-key}/checkpoint.yaml
   - If checkpoint.ci_disabled == true → restore .gitlab-ci.yml BEFORE deleting anything
   - If checkpoint.worktree_path exists → ask to remove worktree (with safety checks)

2. Preserve metrics: copy docs/plans/{task-key}/metrics.yaml to docs/plans/archive/{task-key}-metrics.yaml

3. Remove docs/plans/{task-key}/ directory (plan, checklist, reviews, checkpoint, .tmp/)

4. Remove docs/plans/{task-key}/.credentials if exists

Safety:
- ALWAYS read checkpoint BEFORE deletion (need ci_disabled, worktree_path)
- ALWAYS preserve metrics.yaml (historical data for calibration)
- ALWAYS ask before deleting anything
- Check for uncommitted changes before worktree removal
- Never remove if user is inside the worktree directory
