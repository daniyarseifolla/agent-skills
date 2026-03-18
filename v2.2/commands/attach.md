---
description: "Attach pipeline to existing task. Detects current state, creates checkpoint, runs missing phases. Usage: /attach [ARGO-12345]"
---

# Attach Pipeline to Existing Task

Arguments: $ARGUMENTS

## What this does

Connects the v2.2 pipeline to a task already in progress (started without /worker or with old skills).
Detects what's done, creates checkpoint, runs missing phases.

## Steps

### Phase 0: Detect Current State

1. **Find task key:**
   - If argument provided → use it
   - Else: parse from branch name (feat/ARGO-XXXXX)
   - Else: find in recent commits (grep ARGO)
   - Else: ask user

2. **Fetch task from Jira** (if task-source = jira):
   - Load Skill: adapter-jira
   - Get: title, AC, Figma URLs, description

3. **Scan what exists:**
   ```
   Branch: git branch --show-current
   Commits: git log --oneline develop..HEAD (or main..HEAD)
   Changed files: git diff develop...HEAD --stat
   Plan: ls docs/plans/{task-key}/
   Checkpoint: cat docs/plans/{task-key}/checkpoint.yaml
   CI status: is .gitlab-ci.yml modified?
   Worktree: is this a worktree? (git rev-parse --git-dir)
   ```

4. **Classify state:**

   | Plan? | Code changes? | Tests pass? | Reviews exist? | State |
   |-------|--------------|-------------|---------------|-------|
   | No | No | — | — | Just started → Phase 1 |
   | No | Yes | — | — | Coded without plan → Phase 1 + retro-plan |
   | Yes | No | — | — | Planned, not coded → Phase 3 |
   | Yes | Yes | No | — | Coded, tests fail → Phase 3 (fix) |
   | Yes | Yes | Yes | No | Coded, tests pass → Phase 4 (review) |
   | Yes | Yes | Yes | Yes | Reviewed → Phase 6 (completion) |

5. **Show summary:**
   ```
   Attaching pipeline to: ARGO-XXXXX — {title}
   Branch: {branch}
   Commits: {n} commits, {files} files changed

   Detected state:
   - Plan: {exists/missing}
   - Code: {n files changed}
   - Tests: {pass/fail/not run}
   - Reviews: {exists/missing}

   Missing phases:
   - [ ] Plan review (Phase 2)
   - [ ] Code review (Phase 4)
   - [ ] UI review (Phase 5)
   - [ ] Figma verification

   Run missing phases? (y/n)
   ```

### Phase 1: Create Artifacts (if missing)

If no plan exists:
- Generate retro-plan from actual code changes (what was done, not what should be done)
- Save to docs/plans/{task-key}/plan.md

If no Figma Node Map and Figma URLs exist:
- Generate Figma Node Map from task Figma URLs
- Add to plan

### Phase 2-5: Run Missing Phases

Only run phases that haven't been done:
- **Plan review** → if no docs/plans/{task-key}/plan-review.md
- **Code review** → if no docs/plans/{task-key}/code-review.md → /review
- **UI review** → if no docs/plans/{task-key}/ui-review.md AND Figma URLs exist → /ui-review
- **Figma verify** → if no docs/plans/{task-key}/figma-verify.md → /verify-figma

### Phase 6: Save Checkpoint

Create checkpoint at current state:
```yaml
task_key: "ARGO-XXXXX"
phase_completed: {latest completed phase}
phase_name: "{name}"
attached_at: "{timestamp}"
attached_from: "existing task — not started with /worker"
```

## Key principle

/attach is NON-DESTRUCTIVE:
- Never rewrites existing code
- Never redoes phases that are already done
- Only adds missing reviews/verifications
- Creates artifacts (plan, checkpoint) for tracking
