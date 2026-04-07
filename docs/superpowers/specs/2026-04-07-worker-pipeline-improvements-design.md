# Worker Pipeline Improvements: Impact Analysis, Verification, Auto-Completion

**Date:** 2026-04-07
**Status:** Approved design
**Scope:** v2.2 pipeline — new skill + modifications to 6 existing skills

---

## Problem Statement

Three recurring issues with the `/worker` pipeline:

1. **Manual deploy/MR details** — user must specify MR title, description, and deploy environment every time, even for simple tasks. The jira adapter has `format_mr_description()` but it's never called.
2. **No verification for S tasks** — code-review and ui-review are skipped for S complexity. Coder writes code, builds, and asks "Create MR?" with zero review.
3. **Neighboring problems ignored** — pipeline fixes only the exact bug described. Similar patterns in sibling components, consumers of shared code, and related conditions are never analyzed.

**Real example:** Bug in `goBack()` bypassing CanDeactivateGuard. Agent fixed it but:
- Didn't notice `postImagesChange`/`postFilesChange` had the same missing `disableGoOut()` call — user caught it
- Didn't run tests or verify the fix works
- Asked "Create MR?" and user had to manually dictate: merge → deploy → track → notify Slack

---

## Solution Overview

| Change | Type | Description |
|--------|------|-------------|
| **Impact Analyzer** (Phase 0.8) | New skill | Scans consumers, siblings, shared code before planning |
| **Core Orchestration** | Modify | Add Phase 0.8, update MINIMAL route, update handoff contracts |
| **Planner** (Phase 1) | Modify | Read impact report, include must-fix items as plan Parts |
| **Code Review** (Phase 4) | Modify | Run for ALL complexities, verify impact report items |
| **UI Review** (Phase 5) | Modify | Run for S when design adapter exists, add regression from impact report |
| **Worker** (Phase 6) | Modify | Replace stepwise ASK with single-confirmation auto-completion flow |

---

## 1. Impact Analyzer — New Skill (Phase 0.8)

### Position in Pipeline

Between deep-analysis (0.7) and planner (1). Runs for ALL complexities.

### Input

```yaml
input:
  task: "task_schema from worker"
  task_analysis_path: "docs/plans/{task-key}/task-analysis.md (null for S)"
  complexity: "S|M|L|XL"
  tech_stack_adapter: "for module structure, import patterns"
```

### Three Analysis Types

| Type | What it finds | Method |
|------|--------------|--------|
| **Consumers** | Who imports/uses the files we're changing | Grep for imports, class inheritance, service injection |
| **Siblings** | Same bug pattern in neighboring components of same module | Grep for identical pattern in sibling files (same directory, same base class) |
| **Shared code** | If modifying a utility/service — all consumers | Grep for all import sites of the modified file |

### Dispatch Strategy

**S complexity — 1 agent (sonnet):**
- Single agent runs all three analysis types inline
- Lightweight: grep/glob only, no deep reading
- Budget: max 30 tool calls, 5 min

**M+ complexity — 3 agents in parallel:**

```yaml
agent_1_consumers:
  name: "consumer-scanner"
  model: sonnet
  angle: "Find all files that import/use the files being changed"
  steps:
    - "Read task description → identify files to be modified"
    - "For each file: grep for its imports across the project"
    - "For class inheritance: grep for 'extends {ClassName}'"
    - "For service injection: grep for constructor injection of the service"
  output: ".tmp/impact-consumers.md"

agent_2_siblings:
  name: "sibling-scanner"
  model: sonnet
  angle: "Find same bug pattern in neighboring components"
  steps:
    - "Identify the pattern being fixed (from task description/AC)"
    - "Glob for sibling files in same directory/module"
    - "Grep for the same problematic pattern in siblings"
    - "Check if siblings have the same base class or shared behavior"
  output: ".tmp/impact-siblings.md"

agent_3_shared:
  name: "shared-code-scanner"
  model: sonnet
  angle: "If task modifies shared utilities/services, find all consumers"
  steps:
    - "Identify if any changed files are in shared/libs/common directories"
    - "Grep for all import sites of those shared files"
    - "Check if interface/API contract changes"
    - "List all consumer components that may need verification"
  output: ".tmp/impact-shared.md"
```

### Output Format

```markdown
## Impact Report: {task-key}

### Must-Fix (same bug/pattern in siblings)
Items here MUST become plan Parts — they have the same defect.
- [ ] {file}:{line} — {description of same pattern}

### Must-Verify (consumers of changed code)
Items here MUST be tested during review — they depend on changed code.
- [ ] {file} — imports {changed_file}, verify behavior unchanged
- [ ] {file} — extends {changed_class}, verify inherited method works

### Risk Areas (shared code consumers)
Items here are informational — planner decides if they need attention.
- [ ] {shared_file} — used by {N} consumers: {list}

### Analysis Summary
- Files to modify: {N}
- Direct consumers found: {N}
- Sibling patterns found: {N}
- Shared code consumers: {N}
```

### Handoff

```yaml
handoff:
  to: "planner (Phase 1)"
  payload:
    impact_report_path: "docs/plans/{task-key}/impact-report.md"
    must_fix_count: number
    must_verify_count: number
```

---

## 2. Core Orchestration Changes

### Phase Table Update

```yaml
# Add after 0.7:
- { id: 0.8, name: impact-analysis, model: sonnet, mode: inline, action: "consumers, siblings, shared code → impact-report.md" }
```

### Route Update

```yaml
route_definitions:
  MINIMAL:  { phases: [0, 0.5, 0.8, 1, 3, 4, 5, 6], note: "Phase 5 conditional on design adapter" }
  STANDARD: { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6], note: "all phases" }
  FULL:     { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6], note: "all phases, all tools" }
```

Key changes to MINIMAL:
- **Added 0.8** (impact analysis) — always runs
- **Added 5** (ui-review) — conditional on design adapter
- **Removed skip_when for Phase 4** (code-review) — already in MINIMAL

### Complexity Matrix Update

```yaml
complexity_matrix:
  S:  { ..., plan_review: skip, ui_review: if_design_adapter, code_review: always }
  # M, L, XL unchanged
```

### New Handoff Contracts

```yaml
handoff_contracts:
  # New:
  impact_analyzer_to_planner:
    impact_report_path: string
    must_fix_count: number
    must_verify_count: number
    required: [impact_report_path]

  # Updated:
  worker_to_planner:
    # Add:
    impact_report_path: "string — path to impact-report.md from Phase 0.8"
```

### Next Phase Map Update

```yaml
next_phase_map:
  "0.7": 0.8    # was: 1
  "0.8": 1      # new
```

---

## 3. Planner Changes (Phase 1)

### New Input

```yaml
input:
  # Add:
  impact_report_path: "docs/plans/{task-key}/impact-report.md"
```

### Workflow Changes

After step_1 (component discovery), before step_3 (consensus research):

```yaml
step_1b_impact:
  action: "Read impact-report.md"
  mandatory: true
  use_for:
    - "must-fix items → become separate Implementation Parts in plan"
    - "must-verify items → added to Test Plan section"
    - "risk areas → noted in plan's risk section"
```

### Plan Template Addition

```markdown
## Impact-Driven Items
### From Impact Report
| # | Type | File | Description | Plan Part |
|---|------|------|-------------|-----------|
| 1 | must-fix | edit-post.component.ts | postImagesChange missing disableGoOut() | Part 2 |
| 2 | must-verify | add-post.component.ts | inherits goBack(), verify guard works | Test Plan |
```

---

## 4. Code Review Changes (Phase 4)

### Run for ALL complexities

Remove from core-orchestration:
```yaml
# Remove skip_when from phase 4 entirely — it already runs for S in MINIMAL route
# But ensure: for S → single agent (no consensus 3x3)
```

Review mode by complexity:
- **S:** Single agent, no consensus. Runs all review areas but inline.
- **M+:** Consensus 3x3 as currently defined.

### New Review Area: Impact Verification

```yaml
impact_verification:
  description: "All items from impact-report.md addressed"
  method: |
    Read impact-report.md:
    - For each must-fix: verify the fix is in the diff (git diff)
    - For each must-verify: verify the consumer still works (read code, check no breaking change)
    - For each risk area: verify shared code interface unchanged OR consumers updated
  severity:
    must_fix_not_addressed: BLOCKER
    must_verify_not_checked: MAJOR
    risk_area_unacknowledged: MINOR
```

---

## 5. UI Review Changes (Phase 5)

### Run for S when design adapter exists

Update skip condition:
```yaml
# Was:
skip_when: "complexity == S OR no design adapter"
# Now:
skip_when: "no design adapter"
```

For S complexity:
- No consensus (single pass, not 3x3)
- Functional testing only (skip per-element Figma comparison)
- Must-verify items from impact report added as regression test cases

### New Input

```yaml
input:
  # Add:
  impact_report_path: "docs/plans/{task-key}/impact-report.md (optional)"
```

### Regression from Impact Report

```yaml
impact_regression:
  when: "impact_report_path exists"
  action: |
    Read must-verify items from impact-report.md.
    For each item that has a UI route/page:
      - Navigate to the page
      - Verify basic functionality still works
      - Screenshot for evidence
  add_to: "test plan as 'Regression' group"
```

---

## 6. Worker Phase 6: Auto-Completion Flow

### Replace Current Phase 6

Current:
```yaml
- mr: "ASK user → if yes, ci-cd adapter create_mr()"
- deploy: "ASK user → if yes, ci-cd adapter deploy()"
```

New:

### Step 1: Auto-Generate

```yaml
auto_generate:
  mr_title: "{task.key}: {task.title}"
  mr_description: "task_source_adapter.format_mr_description(task, plan_summary, git_diff_summary)"
  target_branch: "project.yaml → project.branches.main (fallback: develop)"
  deploy_environment: "test"
```

Where `git_diff_summary` is generated from:
```yaml
git_diff_summary:
  method: "git log {target_branch}..HEAD --oneline"
  format: "Bullet list of commit messages"
```

### Step 2: Single Confirmation

```yaml
confirmation:
  prompt: |
    Завершаю задачу {task_key}: {title}

    MR: feat/{task_key} → {target_branch}
      Title: {mr_title}
      Description: [auto-generated, {N} lines]

    После merge → deploy на {environment} → notify #qa

    Proceed? (y / только MR / отмена)

  options:
    "y": "Full cycle: MR → merge → deploy → track → transition → notify"
    "только MR": "Create MR only, stop after"
    "отмена": "Do nothing, keep checkpoint"
```

### Step 3: Execution (full cycle)

```yaml
completion_flow:
  1_restore_ci:
    condition: "checkpoint.ci_disabled == true"
    action: "ci-cd adapter restore_ci(task_key)"

  2_push:
    action: "git push"

  3_create_mr:
    action: "ci-cd adapter create_mr(branch, mr_title, mr_description, target_branch)"
    output: "mr_url, mr_iid"

  4_wait_mr_pipeline:
    action: "ci-cd adapter wait_for_stage(pipeline, 'build')"
    timeout: 15min

  5_merge:
    action: "glab mr merge {mr_iid} --auto-merge"

  6_wait_merge:
    action: "Poll MR state until state == 'merged'"
    poll_interval: 30s
    timeout: 10min

  7_find_target_pipeline:
    action: "ci-cd adapter get_pipeline(target_branch)"
    note: "Post-merge pipeline on target branch"

  8_wait_build:
    action: "ci-cd adapter wait_for_stage(target_pipeline, 'build')"
    timeout: 15min

  9_deploy:
    action: "ci-cd adapter deploy(target_branch, environment)"

  10_wait_deploy:
    action: "Poll deploy job until success"
    timeout: 10min

  11_transition:
    action: "task_source_adapter.transition(task_key, 'Ready for Test')"
    skip_if: "no task_source adapter"

  12_notify:
    action: "notification_adapter.notify_deploy(task_key, environment)"
    skip_if: "no notification adapter"

  13_report:
    display: |
      Готово:
      - MR: {mr_url}
      - Deploy: {environment} success
      - Jira: Ready for Test
      - Slack: notified #qa
```

### Error Handling

```yaml
completion_errors:
  pipeline_fail:
    action: "Show job log tail, ask: retry / abort"
    on_abort: "Write checkpoint, MR stays open"

  merge_conflict:
    action: "Show conflicted files, stop"
    user_must: "Resolve conflicts manually, then /continue"

  deploy_fail:
    action: "Show deploy log, offer: retry / rollback / abort"

  mr_pipeline_timeout:
    action: "Show pipeline URL, ask: keep waiting / abort"
```

---

## Files Changed Summary

| File | Action | Key Change |
|------|--------|-----------|
| `v2.2/pipeline/impact-analyzer/SKILL.md` | **Create** | New skill — consumers, siblings, shared code analysis |
| `v2.2/core/orchestration/SKILL.md` | Modify | Add Phase 0.8, update routes, add handoff contract, update next_phase_map |
| `v2.2/pipeline/worker/SKILL.md` | Modify | Add Phase 0.8 dispatch, replace Phase 6 with auto-completion flow |
| `v2.2/pipeline/planner/SKILL.md` | Modify | Read impact report, must-fix → plan Parts, must-verify → test plan |
| `v2.2/pipeline/code-reviewer/SKILL.md` | Modify | Run for S (no consensus), add impact_verification review area |
| `v2.2/pipeline/ui-reviewer/SKILL.md` | Modify | Run for S when design adapter, add impact regression tests |
| `v2.2/core/orchestration/SKILL.md` | Modify | Update complexity_matrix S row, MINIMAL route |
