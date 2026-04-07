# Worker Pipeline Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add impact analysis before planning, enable reviews for all complexities, and automate the full MR→merge→deploy→notify completion flow.

**Architecture:** New Impact Analyzer skill (Phase 0.8) produces `impact-report.md` consumed downstream by planner, code-review, and ui-review. Phase 6 completion replaces stepwise ASK prompts with a single-confirmation auto-completion cycle.

**Tech Stack:** SKILL.md files (YAML-in-markdown), no runtime code.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `v2.2/pipeline/impact-analyzer/SKILL.md` | Create | New skill: consumers, siblings, shared code analysis |
| `v2.2/core/orchestration/SKILL.md` | Modify | Phase table, routes, handoffs, next_phase_map |
| `v2.2/pipeline/worker/SKILL.md` | Modify | Phase 0.8 dispatch block, Phase 6 auto-completion |
| `v2.2/pipeline/planner/SKILL.md` | Modify | New input field, new step reading impact report |
| `v2.2/pipeline/code-reviewer/SKILL.md` | Modify | New input, new review area, S-complexity mode |
| `v2.2/pipeline/ui-reviewer/SKILL.md` | Modify | New input, impact regression, S-complexity support |

---

### Task 1: Create Impact Analyzer Skill

**Files:**
- Create: `v2.2/pipeline/impact-analyzer/SKILL.md`

- [ ] **Step 1: Create the skill file**

```markdown
---
name: pipeline-impact-analyzer
description: "Impact analysis phase: scans consumers, siblings, and shared code to find what else may break. Produces impact-report.md consumed by planner, code-review, and ui-review. Called by pipeline/worker Phase 0.8."
model: sonnet
---

# Pipeline Impact Analyzer

Phase 0.8. Finds what code is affected beyond the direct task scope. Runs for ALL complexities.

---

## 1. Input

```yaml
input:
  task:
    title: string
    description: string
    acceptance_criteria: string[]
  task_analysis_path: "docs/plans/{task-key}/task-analysis.md (null for S)"
  complexity: "S|M|L|XL"
  tech_stack_adapter: "for module structure, import patterns"
```

---

## 2. Analysis Types

```yaml
analysis_types:
  consumers:
    description: "Who imports/uses the files we're changing"
    method:
      - "Identify files to be modified from task description + AC"
      - "For each file: grep for its imports across the project"
      - "For class inheritance: grep for 'extends {ClassName}'"
      - "For service injection: grep for constructor injection of the service"
      - "For template usage: grep for component selectors in HTML files"

  siblings:
    description: "Same bug pattern in neighboring components of same module"
    method:
      - "Identify the pattern being fixed (from task description/AC)"
      - "Glob for sibling files in same directory/module"
      - "Grep for the same problematic pattern in siblings"
      - "Check if siblings share the same base class or mixin"
      - "Check if siblings have analogous methods with the same defect"

  shared_code:
    description: "If task modifies shared utilities/services, find all consumers"
    method:
      - "Identify if any changed files are in shared/libs/common directories"
      - "Grep for all import sites of those shared files"
      - "Check if interface/API contract changes (method signatures, return types)"
      - "List all consumer components that may need verification"
```

---

## 3. Dispatch Strategy

```yaml
dispatch:
  S_complexity:
    mode: "Single agent, inline"
    description: "One sonnet agent runs all 3 analysis types sequentially"
    budget: "max 30 tool calls, 5 min"
    steps:
      - "Read task description → identify files to be modified"
      - "Run consumers analysis (grep imports)"
      - "Run siblings analysis (glob + grep same pattern)"
      - "Run shared code analysis (check if files are in shared dirs)"
      - "Write impact-report.md"

  M_plus_complexity:
    mode: "3 agents in parallel"
    dispatch: "Use Skill: superpowers:dispatching-parallel-agents"
    MANDATORY: "Do NOT skip. Do NOT do inline analysis instead. Dispatch 3 agents."

    agent_1_consumers:
      name: "consumer-scanner"
      model: sonnet
      subagent_type: "general-purpose"
      angle: "Find all files that import/use the files being changed"
      steps:
        - "Read task description + task-analysis.md → identify files to be modified"
        - "For each file: grep for its imports across the project"
        - "For class inheritance: grep for 'extends {ClassName}'"
        - "For service injection: grep for constructor injection of the service"
        - "For template usage: grep for component selectors in HTML files"
      output: "docs/plans/{task-key}/.tmp/impact-consumers.md"
      format: |
        ## Consumer Analysis
        ### Direct Importers
        | File | Import | Type |
        |------|--------|------|
        | {file} | {import_statement} | import/extends/injects |
        ### Verdict: SUCCESS | PARTIAL | FAILED

    agent_2_siblings:
      name: "sibling-scanner"
      model: sonnet
      subagent_type: "general-purpose"
      angle: "Find same bug pattern in neighboring components"
      steps:
        - "Read task description → identify the pattern being fixed"
        - "Glob for sibling files in same directory/module"
        - "Grep for the same problematic pattern in siblings"
        - "Check if siblings share base class or mixin with the affected file"
        - "For each match: read context to confirm it's the same defect"
      output: "docs/plans/{task-key}/.tmp/impact-siblings.md"
      format: |
        ## Sibling Analysis
        ### Same Pattern Found
        | File | Line | Pattern | Confirmed Defect? |
        |------|------|---------|-------------------|
        | {file} | {line} | {pattern_match} | yes/no |
        ### Verdict: SUCCESS | PARTIAL | FAILED

    agent_3_shared:
      name: "shared-code-scanner"
      model: sonnet
      subagent_type: "general-purpose"
      angle: "If task modifies shared utilities/services, find all consumers"
      steps:
        - "Identify if any changed files are in shared/libs/common directories"
        - "If yes: grep for all import sites of those shared files"
        - "Check if interface/API contract will change (method signatures, return types)"
        - "List all consumer components that may need verification"
        - "If no shared files changed: report 'No shared code impact' and SUCCESS"
      output: "docs/plans/{task-key}/.tmp/impact-shared.md"
      format: |
        ## Shared Code Analysis
        ### Shared Files Modified
        | File | Consumer Count | Consumers |
        |------|---------------|-----------|
        | {shared_file} | {N} | {list} |
        ### Interface Changes
        | File | Change | Breaking? |
        ### Verdict: SUCCESS | PARTIAL | FAILED

    aggregation:
      after: "All 3 agents complete"
      check_verdicts: "Any FAILED → WARN, continue with partial data"
      merge: "Read .tmp/impact-*.md → combine into impact-report.md"
      cleanup: "Keep .tmp/ until planner reads report (cleanup at Phase 1)"
```

---

## 4. Output

```yaml
output:
  path: "docs/plans/{task-key}/impact-report.md"
  format: |
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

  empty_report: |
    If no consumers, siblings, or shared code found:
    ## Impact Report: {task-key}
    ### No Impact Found
    No consumers, sibling patterns, or shared code dependencies detected.
    Task scope is self-contained.
```

---

## 5. Handoff

```yaml
handoff:
  to: "planner (Phase 1)"
  payload:
    impact_report_path: string
    must_fix_count: number
    must_verify_count: number
  required: [impact_report_path]
  validation: "impact-report.md must exist and contain at least the Analysis Summary section"
```
```

- [ ] **Step 2: Verify file structure**

Run: `ls v2.2/pipeline/impact-analyzer/SKILL.md`
Expected: file exists

- [ ] **Step 3: Commit**

```bash
git add v2.2/pipeline/impact-analyzer/SKILL.md
git commit -m "feat(pipeline): add impact-analyzer skill (Phase 0.8)"
```

---

### Task 2: Update Core Orchestration

**Files:**
- Modify: `v2.2/core/orchestration/SKILL.md`

Four changes: phase table, complexity routing, handoff contracts, next_phase_map.

- [ ] **Step 1: Add Phase 0.8 to phase table**

In the `phase_sequence` block (after line 20, the deep-analysis entry), add:

```yaml
  - { id: 0.8, name: impact-analysis, model: sonnet, mode: inline, action: "consumers, siblings, shared code → impact-report.md" }
```

- [ ] **Step 2: Update phase_id_normalization**

The current mapping uses integers 0-8 for 9 phases. Adding Phase 0.8 makes 10 phases. Update `worker_to_metrics` and `metrics_mapping`:

```yaml
phase_id_normalization:
  note: "Worker uses fractional IDs (0, 0.5, 0.7, 0.8, 1-6). Metrics use clean integer 0-9."
  worker_to_metrics:
    "0":     0    # task-analysis
    "0.5":   1    # workspace-setup
    "0.7":   2    # deep-analysis
    "0.8":   3    # impact-analysis
    "1":     4    # planning
    "2":     5    # plan-review
    "3":     6    # implementation
    "4":     7    # code-review
    "5":     8    # ui-review
    "6":     9    # completion
  metrics_mapping:
    0: task-analysis
    1: workspace-setup
    2: deep-analysis
    3: impact-analysis
    4: planning
    5: plan-review
    6: implementation
    7: code-review
    8: ui-review
    9: completion
  storage_type: "integer 0-9"
```

- [ ] **Step 3: Update complexity_matrix S row**

Replace line 61:

```yaml
  S:  { ac: "1-2", modules: 1,    plan_review: skip,     ui_review: if_design_adapter, code_researcher: false, seq_thinking: false,       route: MINIMAL }
```

Change: `ui_review: skip` → `ui_review: if_design_adapter`

- [ ] **Step 4: Update route_definitions**

Replace lines 66-69:

```yaml
route_definitions:
  MINIMAL:  { phases: [0, 0.5, 0.8, 1, 3, 4, 5, 6],          note: "skip deep-analysis, plan-review. Phase 5 conditional on design adapter." }
  STANDARD: { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6],   note: "all phases, ui-review conditional on design adapter" }
  FULL:     { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6],   note: "all phases, all tools enabled" }
```

Changes: MINIMAL adds `0.8` and `5`. STANDARD/FULL add `0.8`.

- [ ] **Step 5: Update Phase 5 skip_when**

Replace line 25 (`skip_when` for ui-reviewer):

```yaml
  - { id: 5,   name: ui-reviewer,      model: sonnet, mode: subagent,          action: "functional + visual review", skip_when: "no design adapter" }
```

Change: removed `complexity == S OR` — now only skips when no design adapter.

- [ ] **Step 6: Add new handoff contracts**

After the `worker_to_planner` contract (after line 124), add:

```yaml
  impact_analyzer_to_planner:
    impact_report_path: string
    must_fix_count: number
    must_verify_count: number
    required: [impact_report_path]
    note: "Phase 0.8 output. Planner reads impact-report.md to include must-fix items as plan Parts."
```

Update `worker_to_planner` (line 121) — add `impact_report_path` to required:

```yaml
  worker_to_planner:
    task: "task_schema — typed object from task-source adapter"
    required: [task, complexity, route, figma_urls, ui_inventory_path, task_analysis_path, impact_report_path]
    optional: [tech_stack_adapter, design_adapter]
    task_analysis_path: "string|null — path to task-analysis.md from Phase 0.7. Null for S complexity."
    impact_report_path: "string — path to impact-report.md from Phase 0.8."
    note: "Worker passes full task object (see task_schema above) + classification results to planner"
```

- [ ] **Step 7: Update next_phase_map**

Replace lines 202-212:

```yaml
next_phase_map:
  note: "Lookup table for resume — replaces phase_completed + 1 arithmetic"
  "0":   0.5
  "0.5": 0.7    # or 0.8 if complexity == S (0.7 skipped)
  "0.7": 0.8
  "0.8": 1
  "1":   2      # or 3 if complexity == S (2 skipped)
  "2":   3
  "3":   4
  "4":   5      # or 6 if no design adapter (5 skipped)
  "5":   6
  "6":   null   # done
```

Changes: `0.5→0.7` comment updated, `0.7→0.8` new, `0.8→1` new. Phase 4→5 comment simplified (S no longer skips 5 when design adapter exists).

- [ ] **Step 8: Commit**

```bash
git add v2.2/core/orchestration/SKILL.md
git commit -m "feat(core): add Phase 0.8 impact-analysis, enable reviews for S complexity"
```

---

### Task 3: Update Worker — Phase 0.8 Dispatch

**Files:**
- Modify: `v2.2/pipeline/worker/SKILL.md`

Two changes: add Phase 0.8 dispatch block, rewrite Phase 6.

- [ ] **Step 1: Add Phase 0.8 between Phase 0.7 and Phase 1**

After the Phase 0.7 block (after line 258), before Phase 1 (line 260), insert:

```yaml
  - phase: 0.8
    name: impact-analysis
    skill: "pipeline-impact-analyzer"
    model: sonnet
    mode: inline
    action: "Scan consumers, siblings, shared code → impact-report.md"
    input: "task, task_analysis_path, complexity, tech_stack_adapter"
    output: "impact_report_path: docs/plans/{task-key}/impact-report.md"
    checkpoint: true
```

- [ ] **Step 2: Update Phase 1 input to include impact_report_path**

Replace lines 260-267:

```yaml
  - phase: 1
    name: planning
    skill: "pipeline-planner"
    model: opus
    mode: inline
    input: "task, complexity, route, tech_stack_adapter, design_adapter, task_analysis_path, impact_report_path"
    output: "plan file path"
    checkpoint: true
```

Change: added `impact_report_path` to input.

- [ ] **Step 3: Update Phase 4+5 ui-reviewer skip_if**

Replace line 319:

```yaml
        skip_if: "no design adapter"
```

Change: removed `complexity == S OR`.

- [ ] **Step 4: Commit Phase 0.8 and routing changes**

```bash
git add v2.2/pipeline/worker/SKILL.md
git commit -m "feat(worker): add Phase 0.8 dispatch, enable ui-review for S"
```

---

### Task 4: Update Worker — Phase 6 Auto-Completion

**Files:**
- Modify: `v2.2/pipeline/worker/SKILL.md`

- [ ] **Step 1: Replace Phase 6 actions block**

Replace lines 354-368 (the entire Phase 6 entry) with:

```yaml
  - phase: 6
    name: completion
    model: sonnet
    mode: inline
    actions:
      - commit: "If uncommitted changes exist (from review fixes), commit them. If all parts already committed in Phase 3, skip."
      - restore_ci: "IF checkpoint.ci_disabled == true → ci-cd adapter restore_ci(task_key)"
      - auto_generate:
          mr_title: "{task.key}: {task.title}"
          mr_description: "task_source_adapter.format_mr_description(task, plan_summary, git_diff_summary)"
          target_branch: "project.yaml → project.branches.main (fallback: develop)"
          deploy_environment: "test"
          git_diff_summary: "git log {target_branch}..HEAD --oneline → bullet list of commit messages"
      - confirmation:
          prompt: |
            Завершаю задачу {task_key}: {title}

            MR: feat/{task_key} → {target_branch}
              Title: {mr_title}
              Description: [auto-generated, {N} lines]

            После merge → deploy на {environment} → notify #qa

            Proceed? (y / только MR / отмена)
          options:
            "y": "Full cycle"
            "только MR": "Create MR only"
            "отмена": "Do nothing"
          on_cancel: "Write checkpoint: terminal_status: stopped_by_user, resume_phase: 6. STOP."
      - completion_flow:
          description: "Executed when user confirms 'y' or 'только MR'"
          steps:
            1_push: "git push"
            2_create_mr: |
              ci-cd adapter create_mr(branch, mr_title, mr_description, target_branch)
              Output: mr_url, mr_iid
            3_stop_if_mr_only: "If user chose 'только MR' → skip to checkpoint"
            4_wait_mr_pipeline: |
              ci-cd adapter wait_for_stage(pipeline, 'build')
              Timeout: 15min
            5_merge: "glab mr merge {mr_iid} --auto-merge"
            6_wait_merge: |
              Poll MR state until state == 'merged'
              Poll interval: 30s, timeout: 10min
            7_find_target_pipeline: |
              ci-cd adapter get_pipeline(target_branch)
              Note: post-merge pipeline on target branch
            8_wait_build: |
              ci-cd adapter wait_for_stage(target_pipeline, 'build')
              Timeout: 15min
            9_deploy: "ci-cd adapter deploy(target_branch, environment)"
            10_wait_deploy: "Poll deploy job until success. Timeout: 10min"
            11_transition: |
              task_source_adapter.transition(task_key, 'Ready for Test')
              skip_if: no task_source adapter
            12_notify: |
              notification_adapter.notify_deploy(task_key, environment)
              skip_if: no notification adapter
            13_report: |
              Display:
                Готово:
                - MR: {mr_url}
                - Deploy: {environment} success
                - Jira: Ready for Test
                - Slack: notified #qa
      - completion_errors:
          pipeline_fail: "Show job log tail. Ask: retry / abort. On abort: write checkpoint, MR stays open."
          merge_conflict: "Show conflicted files. STOP. User resolves manually, then /continue."
          deploy_fail: "Show deploy log. Offer: retry / rollback / abort."
          mr_pipeline_timeout: "Show pipeline URL. Ask: keep waiting / abort."
      - checkpoint: "completed_phases: [...existing, 6], terminal_status: success, resume_phase: null"
      - metrics: "Load core-metrics, collect and store (success collection — reads from checkpoint written above)"
      - ordering: "checkpoint BEFORE metrics — metrics reads phases_completed and terminal_status from checkpoint"
```

- [ ] **Step 2: Commit**

```bash
git add v2.2/pipeline/worker/SKILL.md
git commit -m "feat(worker): replace Phase 6 with auto-completion flow (MR→merge→deploy→notify)"
```

---

### Task 5: Update Planner — Read Impact Report

**Files:**
- Modify: `v2.2/pipeline/planner/SKILL.md`

- [ ] **Step 1: Add impact_report_path to input**

Replace lines 17-31 (the input yaml block):

```yaml
input:
  task:
    title: string
    description: string
    acceptance_criteria: string[]
    figma_urls: string[]
    priority: string
  complexity: "S|M|L|XL"
  route: "MINIMAL|STANDARD|FULL"
  tech_stack_adapter: "loaded adapter for patterns/commands"
  design_adapter: "loaded adapter for Figma (optional, null if none)"
  ui_inventory_path: ".claude/ui-inventory.md (if exists)"
  task_analysis_path: "docs/plans/{task-key}/task-analysis.md (from Phase 0.7, null for S complexity)"
  impact_report_path: "docs/plans/{task-key}/impact-report.md (from Phase 0.8)"
```

- [ ] **Step 2: Add step_1b_impact after step_1_component_discovery**

After line 88 (`purpose: "Avoid reinventing existing components"`), insert new step:

```yaml
  step_1b_impact:
    action: "Read impact-report.md from Phase 0.8"
    mandatory: true
    input: "impact_report_path"
    use_for:
      must_fix: "Each must-fix item becomes a separate Implementation Part in the plan"
      must_verify: "Each must-verify item is added to the Test Plan section"
      risk_areas: "Noted in plan's risk/known-issues section"
    example: |
      If impact report says:
        Must-Fix: postImagesChange missing disableGoOut()
        Must-Fix: postFilesChange missing disableGoOut()
      Then plan gets:
        Part N: Fix sibling defects from impact report
        - Files: edit-post.component.ts
        - Fix postImagesChange: add this.outgoResolverService.disableGoOut()
        - Fix postFilesChange: add this.outgoResolverService.disableGoOut()
```

- [ ] **Step 3: Add Impact-Driven Items to plan template**

In step_6_plan_creation `required_sections` (after line 221), add:

```yaml
      - impact_items: "Must-fix and must-verify items from impact-report.md"
```

In section 4 Plan Format (after the `## Test Plan` line in the template, around line 302), add to the plan template:

```markdown
    ## Impact-Driven Items
    | # | Type | File | Description | Plan Part |
    |---|------|------|-------------|-----------|
    | 1 | must-fix | {file} | {description} | Part {N} |
    | 2 | must-verify | {file} | {description} | Test Plan |
```

- [ ] **Step 4: Commit**

```bash
git add v2.2/pipeline/planner/SKILL.md
git commit -m "feat(planner): read impact report, include must-fix as plan Parts"
```

---

### Task 6: Update Code Reviewer — Impact Verification + S-Complexity Mode

**Files:**
- Modify: `v2.2/pipeline/code-reviewer/SKILL.md`

- [ ] **Step 1: Add impact_report_path to input**

Replace lines 17-27 (the input yaml block):

```yaml
input:
  coder_handoff:
    branch: string
    parts_implemented: string[]
    deviations_from_plan: string[]
    risks_mitigated: string[]
  plan_path: "docs/plans/{task-key}/plan.md"
  impact_report_path: "docs/plans/{task-key}/impact-report.md"
  tech_stack_adapter: "for quality checks and lint/test commands"
  complexity: "S|M|L|XL"
  # Auto-loaded: core-security
```

- [ ] **Step 2: Add impact_verification review area**

After the `test_coverage` review area (after line 99), add:

```yaml
  impact_verification:
    description: "All items from impact-report.md addressed"
    method: |
      Read impact-report.md:
      - For each must-fix: verify the fix is present in the diff (git diff)
      - For each must-verify: verify the consumer still works (read code, check no breaking change to interface)
      - For each risk area: verify shared code interface unchanged OR consumers updated
    severity:
      must_fix_not_addressed: BLOCKER
      must_verify_not_checked: MAJOR
      risk_area_unacknowledged: MINOR
    skip_if: "impact-report.md contains 'No Impact Found'"
```

- [ ] **Step 3: Add S-complexity mode**

After the consensus_mode section (after line 251), add:

```yaml
## 8b. S-Complexity Mode

When `complexity == S`. Single-agent review, no consensus.

```yaml
s_complexity_mode:
  activation: "complexity == S"
  dispatch: "Inline — single agent, no subagent dispatch"
  review_areas: "All areas from Section 3 (same checklist, same severity rules)"
  consensus: "None — single pass"
  note: "Same rigor, less parallelism. Every review area still applies."
```

- [ ] **Step 4: Commit**

```bash
git add v2.2/pipeline/code-reviewer/SKILL.md
git commit -m "feat(code-reviewer): add impact verification, support S-complexity mode"
```

---

### Task 7: Update UI Reviewer — Impact Regression + S-Complexity

**Files:**
- Modify: `v2.2/pipeline/ui-reviewer/SKILL.md`

- [ ] **Step 1: Add impact_report_path to input**

Replace lines 17-28 (the input yaml block):

```yaml
input:
  branch: "feature branch"
  figma_urls: "string[] from task (via task-source adapter)"
  app_url: "local dev server URL (ask user if not known)"
  design_adapter: "for Figma screenshots and comparison"
  tech_stack_adapter: "for serve command"
  ui_inventory_path: ".claude/ui-inventory.md (optional)"
  impact_report_path: "docs/plans/{task-key}/impact-report.md (optional)"
  complexity: "S|M|L|XL"

  credentials:
    source: "Extracted from task description by task-source adapter (credentials field)"
    usage: "Passed to functional-tester for login workflow"
    fallback: "If no credentials in task, ask user"
```

- [ ] **Step 2: Add impact regression to test planning**

After step_2 in test_planning (after line 74), add:

```yaml
  step_2b_impact_regression:
    action: "Add regression tests from impact-report.md"
    when: "impact_report_path exists and contains must-verify items"
    method: |
      Read must-verify items from impact-report.md.
      For each item that has a UI route/page:
        - Add test case: navigate to the page, verify basic functionality still works
        - Take screenshot for evidence
      Add these as a 'Regression' test group in the test plan.
    group_name: "Impact Regression"
    note: "These test existing functionality that depends on changed code"
```

- [ ] **Step 3: Add S-complexity mode**

After the consensus_mode section (after line 429), add:

```yaml
## 6b. S-Complexity Mode

When `complexity == S`. Functional testing only, no consensus.

```yaml
s_complexity_mode:
  activation: "complexity == S"
  dispatch: "Single agent — functional testing only"
  skip: "Per-element Figma comparison (visual fidelity section)"
  keep: "Functional testing, impact regression, missing states audit"
  consensus: "None — single pass"
  budget: "max 80 tool calls, 15 min"
  note: "Lighter than M+ but still catches functional regressions and broken states"
```

- [ ] **Step 4: Commit**

```bash
git add v2.2/pipeline/ui-reviewer/SKILL.md
git commit -m "feat(ui-reviewer): add impact regression, support S-complexity mode"
```

---

### Task 8: Sync — Verify All Cross-References

Final verification that all skills reference each other correctly.

- [ ] **Step 1: Verify impact-analyzer output path matches planner input**

Check: `impact-report.md` path is consistent across:
- `v2.2/pipeline/impact-analyzer/SKILL.md` → output.path
- `v2.2/pipeline/planner/SKILL.md` → input.impact_report_path
- `v2.2/pipeline/code-reviewer/SKILL.md` → input.impact_report_path
- `v2.2/pipeline/ui-reviewer/SKILL.md` → input.impact_report_path
- `v2.2/core/orchestration/SKILL.md` → handoff contract

All must use: `docs/plans/{task-key}/impact-report.md`

- [ ] **Step 2: Verify phase numbering is consistent**

Check: Phase 0.8 appears in:
- `core/orchestration/SKILL.md` → phase_sequence, phase_id_normalization, next_phase_map
- `pipeline/worker/SKILL.md` → phases block

- [ ] **Step 3: Verify route definitions match skip_when conditions**

Check:
- MINIMAL includes Phase 5 → Phase 5 `skip_when` no longer says `complexity == S`
- MINIMAL includes Phase 0.8 → Phase 0.8 has no skip_when (runs always)
- S complexity matrix says `ui_review: if_design_adapter` → matches Phase 5 `skip_when: "no design adapter"`

- [ ] **Step 4: Fix any inconsistencies found**

If any cross-reference is wrong, fix it in the relevant file.

- [ ] **Step 5: Commit (if fixes needed)**

```bash
git add v2.2/
git commit -m "fix(pipeline): align cross-references after Phase 0.8 addition"
```
