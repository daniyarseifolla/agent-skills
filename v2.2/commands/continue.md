---
description: "Continue interrupted pipeline from last checkpoint. Usage: /continue ARGO-12345"
---

# Resume Pipeline

Task key: $ARGUMENTS

1. Read checkpoint: docs/plans/{task-key}/checkpoint.yaml
2. If found → display current state (same as /progress)
3. If no checkpoint found → try heuristic recovery:
   - Check docs/plans/{task-key}/ for existing artifacts
   - Use core-orchestration recovery_heuristic table:
     | Analysis? | Plan? | Code? | Tests? | Reviews? | Resume from |
     |-----------|-------|-------|--------|----------|-------------|
     | Yes       | No    | —     | —      | —        | Phase 1 (with task-analysis.md) |
     | No        | No    | —     | —      | —        | Phase 0.7 (or Phase 1 for S) |
     | —         | Yes   | No    | —      | —        | Phase 3 |
     | —         | Yes   | Yes   | No     | —        | Phase 3 (fix tests) |
     | —         | Yes   | Yes   | Yes    | No       | Phase 4+5 |
     | —         | Yes   | Yes   | Yes    | Yes      | Phase 6 |
   - Write checkpoint from detected state
   - Resume from detected phase
4. If still nothing found → "No task artifacts found. Start new with /worker {task_key}"
5. Load Skill: pipeline-worker with resume mode
6. Resume: last = max(completed_phases), next = next_phase_map[last]
7. Restore: ci_disabled, worktree_path, credentials_path, iteration counters, handoff_payload

If no arguments provided, find most recent checkpoint and offer to resume it.
