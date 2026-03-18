---
description: "Clean up pipeline artifacts. Usage: /cleanup ARGO-12345"
---

# Cleanup

Task key: $ARGUMENTS

Actions (ask confirmation for each):
1. Remove docs/plans/{task-key}/ directory (plan, checklist, reviews, checkpoint)
2. If checkpoint.ci_disabled == true → restore .gitlab-ci.yml from backup
3. If checkpoint.worktree_path exists → ask to remove worktree (with safety checks)
4. Remove checkpoint file

Safety:
- ALWAYS ask before deleting anything
- Check for uncommitted changes before worktree removal
- Never remove if user is inside the worktree directory
