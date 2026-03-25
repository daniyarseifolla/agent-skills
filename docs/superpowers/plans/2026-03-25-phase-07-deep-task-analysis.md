# Phase 0.7 Deep Task Analysis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Phase 0.7 (Deep Task Analysis) to worker pipeline — Figma exploration, Swagger API discovery, functional mapping via consensus agents.

**Architecture:** Worker gets a new phase between 0.5 and 1. Three agents (2 parallel + 1 sequential) write to .tmp/, orchestrator merges into task-analysis.md. Planner reads this instead of re-scanning Figma/Swagger.

**Tech Stack:** Markdown skill files (YAML-structured), Figma MCP, WebFetch for Swagger.

**Spec:** `docs/superpowers/specs/2026-03-25-deep-task-analysis-design.md`

---

## File Structure

```
MODIFY: v2.2/pipeline/worker/SKILL.md           — add Phase 0.7 to phases table
MODIFY: v2.2/core/orchestration/SKILL.md         — phase_sequence, checkpoint, recovery, handoff
MODIFY: v2.2/adapters/angular/SKILL.md           — add api_discovery method
MODIFY: v2.2/pipeline/planner/SKILL.md           — skip step_2 when task-analysis.md exists
MODIFY: v2.2/SKILLS_OVERVIEW.md                  — update adapter contract
```

5 files modified, 0 new files. Phase 0.7 logic lives in worker (inline), not a separate skill.

---

### Task 1: Update core/orchestration — phase table, checkpoint, recovery, handoff

**Files:**
- Modify: `v2.2/core/orchestration/SKILL.md`

- [ ] **Step 1: Add Phase 0.7 to phase_sequence**

In the `phase_sequence` YAML block, add after Phase 0.5:
```yaml
  - { id: 0.7, name: deep-analysis,   model: opus,   mode: inline,            action: "Figma exploration + API discovery + functional map", skip_when: "complexity == S" }
```

- [ ] **Step 2: Add 0.7 to checkpoint_schema**

Change `phase_completed` from:
```
phase_completed: "0|0.5|1|2|3|4|5|6"
```
to:
```
phase_completed: "0|0.5|0.7|1|2|3|4|5|6"
```

- [ ] **Step 3: Add 0.7 to phase_id_normalization**

In `phase_id_normalization.mapping` add:
```yaml
    "0.7":   0.7  # deep-analysis
```
In `metrics_mapping` — no change needed (Phase 0.7 is pre-planning, doesn't get its own metrics phase).

- [ ] **Step 4: Add task_analysis_path to worker_to_planner handoff**

In `handoff_contracts.worker_to_planner`:
```yaml
  worker_to_planner:
    task: "task_schema — typed object from task-source adapter"
    required: [task, complexity, route, figma_urls, ui_inventory_path, task_analysis_path]
    optional: [tech_stack_adapter, design_adapter]
    note: "task_analysis_path is null for S complexity (Phase 0.7 skipped)"
```

- [ ] **Step 5: Add recovery heuristic entry**

In `recovery_heuristic` table, add new row:
```yaml
  - { task_analysis: yes, plan: no, evaluate: "-", code: "-", tests: "-", resume: "Phase 1 — planning (with task-analysis.md context)" }
```

- [ ] **Step 6: Add 0.7 to route_definitions**

Already has 0.5. Verify all routes include 0.7 (except MINIMAL which skips it for S):
```yaml
route_definitions:
  MINIMAL:  { phases: [0, 0.5, 1, 3, 4, 6],              note: "skip deep-analysis, plan-review, ui-review" }
  STANDARD: { phases: [0, 0.5, 0.7, 1, 2, 3, 4, 5, 6],   note: "all phases" }
  FULL:     { phases: [0, 0.5, 0.7, 1, 2, 3, 4, 5, 6],   note: "all phases, all tools" }
```

- [ ] **Step 7: Sync to global + commit**

```bash
cp v2.2/core/orchestration/SKILL.md ~/.claude/skills/orchestration/SKILL.md
git add v2.2/core/orchestration/SKILL.md
git commit -m "feat(orchestration): add Phase 0.7 to phase table, checkpoint, recovery, handoff"
```

---

### Task 2: Add api_discovery to adapter-angular

**Files:**
- Modify: `v2.2/adapters/angular/SKILL.md`

- [ ] **Step 1: Add api_discovery section**

Add new section `## 9. API Discovery` after Section 8 (Cherry-Pick Build Fix Patterns):

```yaml
## 9. API Discovery

Implements the `tech-stack.api_discovery` contract. Called by worker Phase 0.7.

```yaml
api_discovery:
  purpose: "Find API base URL and Swagger/OpenAPI spec URL for Angular projects"
  returns: "{ base_url: string, swagger_url: string, auth_hint: string }"

  chain:
    1_proxy_conf:
      action: "Read proxy.conf.json or proxy.conf.js"
      glob: "proxy.conf.{json,js}"
      extract: "/api target URL → base_url"
      example: '{ "/api": { "target": "https://api.dev.project.com" } } → base_url = https://api.dev.project.com'

    2_environment:
      action: "Read environment.ts or environment.development.ts"
      glob: "src/environments/environment*.ts"
      extract: "apiUrl field → base_url"
      fallback: "If proxy.conf found, skip this step"

    3_derive_swagger:
      action: "Derive swagger_url from base_url"
      patterns:
        - "{base_url}/swagger/v1/swagger.json"
        - "{base_url}/swagger/swagger.json"
        - "{base_url}/api-docs"
      verify: "WebFetch each pattern → first 200 with JSON content-type wins"

    4_project_yaml:
      action: "If chain 1-3 failed → read .claude/project.yaml → api.swagger_url"
      fallback: true

    5_ask_user:
      action: "If all failed → ask user for swagger URL"
      save: "Store in .claude/project.yaml api.swagger_url (only if absent)"

  auth_hint: "If proxy.conf has headers or auth config → extract auth pattern"
```

- [ ] **Step 2: Update SKILLS_OVERVIEW.md adapter contract**

In Adapter Contracts section, `tech-stack` line should already have `security_checks` (from P1). Add `api_discovery`:
```
tech-stack:      commands (lint/test/build), quality_checks, security_checks, api_discovery, patterns, module_lookup
```

- [ ] **Step 3: Sync + commit**

```bash
cp v2.2/adapters/angular/SKILL.md ~/.claude/skills/adapter-angular/SKILL.md
git add v2.2/adapters/angular/SKILL.md v2.2/SKILLS_OVERVIEW.md
git commit -m "feat(adapter-angular): add api_discovery method for Phase 0.7"
```

---

### Task 3: Add Phase 0.7 to worker pipeline

**Files:**
- Modify: `v2.2/pipeline/worker/SKILL.md`

- [ ] **Step 1: Add Phase 0.7 entry to phases YAML**

In the `phases:` block, after Phase 0.5 and before Phase 1, add:

```yaml
  - phase: 0.7
    name: deep-analysis
    model: opus
    mode: inline
    skip_if: "complexity == S"
    action: "Deep task analysis: Figma screens + API discovery + functional map"
    dispatch: |
      Step 1: mkdir -p docs/plans/{task-key}/screenshots/ && mkdir -p docs/plans/{task-key}/.tmp/
      Step 2: Launch Agent 1 (Figma Explorer, opus) + Agent 2 (API Discovery, sonnet) IN PARALLEL
        Agent 1: get_metadata → get_design_context per frame → get_screenshot → identify screens/states/flows
          Output: .tmp/figma-screens.md
          Verdict: SUCCESS | PARTIAL | FAILED
        Agent 2: tech_stack_adapter.api_discovery() → WebFetch swagger → parse → test endpoints (OPTIONS/HEAD only)
          Output: .tmp/api-analysis.md
          Verdict: SUCCESS | PARTIAL | FAILED
      Step 3: Check verdicts
        Both FAILED → HALT, show error, ask user
        One FAILED → WARN, continue with partial data
      Step 4: Launch Agent 3 (Functional Mapper, opus) SEQUENTIALLY
        Input: paths to .tmp/figma-screens.md + .tmp/api-analysis.md (from orchestrator, not convention)
        Output: .tmp/functional-map.md
      Step 5: Merge .tmp/*.md → docs/plans/{task-key}/task-analysis.md
      Step 6: Confirmation gate — show task-analysis.md to user
        y → proceed, write checkpoint, cleanup .tmp/
        edit → user corrects (max 3 edits), update task-analysis.md, re-show
        abort → halt pipeline
        create_backend_tasks → if BROKEN/MISSING endpoints, offer to create Jira issues (mcp__plugin_atlassian_atlassian__createJiraIssue)
        continue_without_api → set api_strategy: mock at top of task-analysis.md
    checkpoint: true
    output: "task_analysis_path: docs/plans/{task-key}/task-analysis.md"
```

- [ ] **Step 2: Update Phase 1 input to include task_analysis_path**

Change Phase 1 input line from:
```yaml
    input: "task, complexity, route, tech_stack_adapter, design_adapter"
```
to:
```yaml
    input: "task, complexity, route, tech_stack_adapter, design_adapter, task_analysis_path"
```

- [ ] **Step 3: Sync + commit**

```bash
cp v2.2/pipeline/worker/SKILL.md ~/.claude/skills/pipeline-worker/SKILL.md
git add v2.2/pipeline/worker/SKILL.md
git commit -m "feat(worker): add Phase 0.7 deep task analysis dispatch"
```

---

### Task 4: Update planner to use task-analysis.md

**Files:**
- Modify: `v2.2/pipeline/planner/SKILL.md`

- [ ] **Step 1: Add task_analysis_path to input**

In Section 1 (Input), add field:
```yaml
  task_analysis_path: "docs/plans/{task-key}/task-analysis.md (from Phase 0.7, null for S complexity)"
```

- [ ] **Step 2: Add task-analysis reading step**

Add new Section 1b after Section 1:

```markdown
## 1b. Task Analysis Context

```yaml
task_analysis:
  when: "task_analysis_path is not null"
  action: "Read task-analysis.md BEFORE any research"
  provides:
    - "Figma screens with node-ids and states (skip step_2_design_context)"
    - "API endpoints with schemas (informs service design)"
    - "User flows (informs component wiring and routing)"
    - "Gaps (documented as risks in plan)"
    - "api_strategy: real|mock (affects service implementation approach)"
  skip_step_2: "If task-analysis.md has Figma Screens section → skip step_2_design_context entirely"
```
```

- [ ] **Step 3: Modify step_2_design_context with skip condition**

Find the `step_2_design_context` section and add:
```yaml
  skip_if: "task_analysis_path exists AND task-analysis.md has '## Figma Screens' section"
  reason: "Phase 0.7 already explored all Figma frames. Re-scanning wastes tokens and API calls."
```

- [ ] **Step 4: Sync + commit**

```bash
cp v2.2/pipeline/planner/SKILL.md ~/.claude/skills/pipeline-planner/SKILL.md
git add v2.2/pipeline/planner/SKILL.md
git commit -m "feat(planner): read task-analysis.md from Phase 0.7, skip redundant Figma scan"
```

---

### Task 5: Final sync + verify

**Files:**
- All modified files

- [ ] **Step 1: Full sync check**

```bash
cd ~/Desktop/pet/agent-skills
for dir in v2.2/core v2.2/pipeline v2.2/adapters v2.2/facades; do
  for skill in $dir/*/SKILL.md; do
    skillname=$(echo $skill | sed 's|v2.2/||;s|/SKILL.md||')
    # ... (use the sync check script from earlier)
  done
done
```

- [ ] **Step 2: Verify Phase 0.7 is consistent across files**

Check that:
- core/orchestration phase_sequence has 0.7
- core/orchestration checkpoint_schema has 0.7
- core/orchestration route_definitions has 0.7 (STANDARD, FULL but not MINIMAL)
- core/orchestration recovery_heuristic has task_analysis entry
- core/orchestration worker_to_planner has task_analysis_path
- worker phases has Phase 0.7 block
- worker Phase 1 input has task_analysis_path
- planner input has task_analysis_path
- planner has skip condition for step_2
- adapter-angular has api_discovery
- SKILLS_OVERVIEW has api_discovery in tech-stack contract

- [ ] **Step 3: Update AGENT.md**

Mark Phase 0.7 as implemented in "Что НЕ сделано" section.

- [ ] **Step 4: Commit**

```bash
git add AGENT.md
git commit -m "docs: Phase 0.7 implemented, update AGENT.md"
```

---

## Execution Order

```
Task 1 (orchestration) → Task 2 (angular adapter) → Task 3 (worker) → Task 4 (planner) → Task 5 (verify)
Sequential — each builds on previous.
```

## Total: 5 tasks, ~20 steps
