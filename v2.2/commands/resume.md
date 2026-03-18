---
description: "Resume interrupted pipeline from last checkpoint. Usage: /resume ARGO-12345"
---

# Resume Pipeline

Task key: $ARGUMENTS

1. Read checkpoint: docs/plans/{task-key}/checkpoint.yaml
2. If not found → "No checkpoint for {task-key}. Start new with /worker {task-key}"
3. If found → display current state (same as /progress)
4. Load Skill: pipeline-worker with resume mode
5. Resume from phase_completed + 1
6. Restore context: ci_disabled, worktree_path, iteration counters, handoff_payload

If no arguments provided, find most recent checkpoint and offer to resume it.
