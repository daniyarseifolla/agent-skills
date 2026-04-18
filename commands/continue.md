---
description: "Continue interrupted pipeline from last checkpoint. Usage: /continue ARGO-12345"
---

# Resume Pipeline

Task key: $ARGUMENTS

1. Read checkpoint: docs/plans/{task-key}/checkpoint.yaml

2. **Validate checkpoint** (if found):
   ```yaml
   validation:
     required: [task_key, completed, complexity, route]
     required_for_resume: [handoff_payload]
     recommended: [iteration, resume]
     on_missing_required: "HALT — checkpoint malformed, fall through to heuristic recovery"
     on_missing_handoff:
       action: "Attempt reconstruction from artifacts"
       repair:
         analyze_input: "Reconstruct from task-analysis.md + checkpoint fields (complexity, route)"
         plan_input: "Reconstruct from plan.md path + checkpoint fields"
         implement_input: "Reconstruct from plan.md + evaluate.md (verdict, iteration)"
         review_input: "Reconstruct from git diff main..HEAD (branch, files changed)"
         ship_input: "Reconstruct from review verdicts in checkpoint.verdict"
       on_repair_failed: "HALT — cannot resume without handoff context. Show: 'Checkpoint missing handoff_payload and repair failed. Re-run from earlier phase? (y/n)'"
     on_missing_recommended: "WARN — proceed with defaults (iteration: all zeros)"
   ```

3. **Check terminal status**:
   - If `terminal_status` is set (success|failed|stopped_by_user|loop_exceeded):
     - Display: "Pipeline ended with status: {terminal_status} at phase {phase_name}"
     - Ask: "Re-run from {resume}? (y/n)"
     - If no → stop
     - If yes → **terminal cleanup before re-entry**:
       ```yaml
       terminal_cleanup:
         - clear: "terminal_status → null (pipeline is running again)"
         - keep: "completed, invalidated, iteration (preserve history)"
         - verify: "resume is set and valid for current route"
         - write_checkpoint: "MUST write cleaned checkpoint BEFORE loading worker"
         - note: "This ensures worker sees a non-terminal, resumable checkpoint"
       ```

4. **Determine resume phase**:
   ```yaml
   resume_logic:
     primary: "checkpoint.resume (if present and non-null)"
     fallback: "next_phase_map[max(completed)]"
     with_invalidation: "If invalidated is non-empty → show which phases will re-run"
   ```

5. Display current state (same as /progress)

6. If no checkpoint found → try heuristic recovery:
   - Check docs/plans/{task-key}/ for existing artifacts
   - Use core-orchestration recovery_heuristic table:
     | Analysis? | Plan? | Evaluate? | Code? | Resume from |
     |-----------|-------|-----------|-------|-------------|
     | Yes       | No    | —         | —     | Phase 4: impact (with task-analysis.md) |
     | No        | No    | —         | —     | Phase 4: impact then planning |
     | —         | Yes   | No        | No    | Phase 7: implement — evaluate gate |
     | —         | Yes   | Yes       | No    | Phase 7: implement — start coding |
     | —         | Yes   | —         | Yes   | Phase 8: review |
   - Write checkpoint from detected state (with resume set)
   - Resume from detected phase

7. If still nothing found → "No task artifacts found. Start new with /worker {task_key}"

8. **Rehydrate state**:
   ```yaml
   restore:
     - handoff_payload:
         source: "checkpoint.handoff_payload"
         if_missing: "Attempt repair (see validation.on_missing_handoff). On repair failure → HALT."
         if_present: "Validate against handoff_contracts for target phase. On mismatch → WARN, attempt partial repair."
     - worktree_path:
         verify: "directory exists"
         if_missing: "Ask user: recreate worktree or work in main repo?"
         repair: "Skill: superpowers:using-git-worktrees with existing branch"
     - credentials_path:
         verify: "file exists at path"
         if_missing: "Ask user to provide credentials. Write to same path."
         repair: "Write docs/plans/{task-key}/.credentials from user input"
     - app_url:
         verify: "curl -s -o /dev/null -w '%{http_code}' {url} returns 200"
         if_unreachable: "Ask user to start dev server. Offer: run start command from tech-stack adapter?"
         repair: "Run adapter.start_dev_server() or accept manual URL"
     - ci_disabled: "restore flag (no verification needed)"
     - iteration: "restore counters (default: all zeros if missing)"
   ```

9. Load Skill: pipeline-worker with resume mode

If no arguments provided, find most recent checkpoint and offer to resume it.
