---
description: "Continue interrupted pipeline from last checkpoint. Usage: /continue ARGO-12345"
---

# Resume Pipeline

Task key: $ARGUMENTS

1. Read checkpoint: docs/plans/{task-key}/checkpoint.yaml
2. If found → display current state (same as /progress)
3. If no checkpoint found → try heuristic recovery:
   - Check docs/plans/{task-key}/ for existing artifacts
   - Use core-orchestration recovery table:
     | Plan? | Code? | Tests? | Reviews? | Resume from |
     |-------|-------|--------|----------|-------------|
     | No    | —     | —      | —        | Phase 1     |
     | Yes   | No    | —      | —        | Phase 3     |
     | Yes   | Yes   | No     | —        | Phase 3 (fix tests) |
     | Yes   | Yes   | Yes    | No       | Phase 4+5   |
     | Yes   | Yes   | Yes    | Yes      | Phase 6     |
   - Write checkpoint from detected state
   - Resume from detected phase
4. If still nothing found → "No task artifacts found. Start new with /worker {task_key}"
5. Load Skill: pipeline-worker with resume mode
6. Resume from phase_completed + 1
7. Restore context: ci_disabled, worktree_path, iteration counters, handoff_payload

If no arguments provided, find most recent checkpoint and offer to resume it.
