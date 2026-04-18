---
description: "Attach pipeline to existing task. Detects current state, creates checkpoint, runs missing phases. Usage: /attach [ARGO-12345]"
---

# Attach Pipeline to Existing Task

Arguments: $ARGUMENTS

## What this does

Connects the v2.2 pipeline to a task already in progress (started without /worker or with old skills).
Detects what's done, creates checkpoint, runs missing phases.

## Steps

### Step 1: Detect Current State

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
   Task analysis: ls docs/plans/{task-key}/task-analysis.md
   Plan: ls docs/plans/{task-key}/plan.md
   Checkpoint: cat docs/plans/{task-key}/checkpoint.yaml
   CI status: is .gitlab-ci.yml modified?
   Worktree: is this a worktree? (git rev-parse --git-dir)
   ```

4. **Classify state:**

   | Analysis? | Plan? | Code changes? | Tests pass? | Reviews exist? | State |
   |-----------|-------|--------------|-------------|---------------|-------|
   | No | No | No | — | — | Nothing done → Phase 3: research |
   | Yes | No | No | — | — | Analyzed, not planned → Phase 4: impact |
   | No | No | Yes | — | — | Coded without plan → Phase 3: research + retro-plan |
   | No | Yes | No | — | — | Planned without analysis → Phase 7: implement |
   | Yes | Yes | No | — | — | Planned, not coded → Phase 7: implement |
   | Yes | Yes | Yes | No | — | Coded, tests fail → Phase 7: implement (fix) |
   | Yes | Yes | Yes | Yes/No | No | Tests pass → Phase 8: review |
   | Yes | Yes | Yes | Yes | Yes | Reviewed → Phase 9: ship |

5. **Write initial checkpoint immediately:**
   ```yaml
   # docs/plans/{task-key}/checkpoint.yaml
   task_key: "{task-key}"
   completed: [{detected_phases}]  # e.g., [analyze, plan, implement] not just "implement"
   resume: "{next phase to run}"     # explicit — derived from classification table
   invalidated: []                  # clean start for attach
   terminal_status: null                   # pipeline is running
   phase_name: "{detected state}"
   attached_at: "{timestamp}"
   attached_from: "existing task — not started with /worker"
   ```
   This checkpoint enables /progress and /continue to find this task.
   NOTE: `completed` is a SET — each subsequent phase APPENDS to the array, never overwrites.

6. **Show summary:**
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
   - [ ] Plan review (Phase 6: plan-review)
   - [ ] Code review (Phase 8: review)
   - [ ] UI review (Phase 8: review)
   - [ ] Figma verification

   Run missing phases? (y/n)
   ```

### Step 2: Create Artifacts (if missing)

If no plan exists:
- Generate retro-plan from actual code changes (what was done, not what should be done)
- Save to docs/plans/{task-key}/plan.md

If no Figma Node Map and Figma URLs exist:
- Generate Figma Node Map from task Figma URLs
- Add to plan

### Step 3: Run Missing Phases

CRITICAL: Use OUR commands, NOT superpowers or feature-dev skills.
Each command below invokes our pipeline skills with OWASP security, plan compliance, and Figma verification.

Only run phases that haven't been done.

IMPORTANT: Use the Skill tool (not Agent tool) to load each skill.
Skills are NOT agent types — they are loaded via `Skill("skill-name")`.

- **Plan review** → if no plan-review.md:
  1. Use the Skill tool to load "pipeline-plan-reviewer"
  2. Follow the loaded skill instructions to review the plan
  3. Save output to docs/plans/{task-key}/plan-review.md
  4. Write checkpoint: `{ ..., completed: [...existing, plan-review], resume: implement, phase_name: "plan-review" }`
  5. If verdict is blocking (NEEDS_CHANGES, CHANGES_REQUESTED):
     Show findings to user. Ask: "Fix issues and re-run? (y/n)"
     Do NOT silently proceed to next phase.

- **Code review** → if no code-review.md:
  1. Use the Skill tool to load "pipeline-code-reviewer"
  2. Follow the loaded skill instructions (standalone mode: detect branch, find plan, run review)
  3. Save output to docs/plans/{task-key}/code-review.md
  4. Write checkpoint: `{ ..., completed: [...existing, review], resume: ship, phase_name: "code-review" }`
  5. If verdict is blocking (CHANGES_REQUESTED):
     Set `invalidated: [review]`, `resume: implement`
     Show findings to user. Ask: "Fix issues and re-run? (y/n)"
     Do NOT silently proceed to next phase.

- **UI review** → if no ui-review.md AND Figma URLs exist:
  1. Use the Skill tool to load "pipeline-ui-reviewer"
  2. Follow the loaded skill instructions (standalone mode)
  3. Save output to docs/plans/{task-key}/ui-review.md
  4. Write checkpoint: `{ ..., completed: [...existing, review], resume: ship, phase_name: "ui-review" }`
  5. If verdict is blocking (NEEDS_CHANGES, CHANGES_REQUESTED):
     Show findings to user. Ask: "Fix issues and re-run? (y/n)"
     Do NOT silently proceed to next phase.

- **Figma verify** → if no figma-verify.md:
  1. Use the Skill tool to load "pipeline-coder"
  2. Execute ONLY section 8b (Figma Self-Verify) — do NOT implement new code
  3. Save output to docs/plans/{task-key}/figma-verify.md
  4. Write checkpoint: `{ ..., completed: [...existing, review], resume: ship, phase_name: "figma-verify" }`
  5. If verdict is blocking (NEEDS_CHANGES, CHANGES_REQUESTED):
     Show findings to user. Ask: "Fix issues and re-run? (y/n)"
     Do NOT silently proceed to next phase.

NEVER use Agent tool with subagent_type for these — they are skills, not agent types.
NEVER use: superpowers:code-reviewer, feature-dev:code-reviewer, or any agent type containing "code-reviewer".

### Step 4: Save Checkpoint

Create checkpoint at current state:
```yaml
task_key: "ARGO-XXXXX"
completed: [{all completed phase names}]  # e.g., [analyze, setup, research, impact, plan, plan-review, implement, review] — SET, not watermark
resume: ship                              # next phase to execute
invalidated: []                           # cleared after all reviews pass
terminal_status: null                              # still running
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
