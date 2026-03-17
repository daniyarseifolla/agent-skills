---
name: pipeline-worker
description: "Project-agnostic development pipeline orchestrator. Manages phases, checkpoints, recovery, and adapter loading. Called by facade skills — not directly by user."
---

# Pipeline Worker

Thin orchestrator. Delegates all work to pipeline phases. Manages flow, checkpoints, recovery.

---

## 1. Startup

```yaml
startup:
  step_1_config:
    action: "Read .claude/project.yaml"
    fallback: "Autodetect (see section 3)"
    output: "config object with adapter types"

  step_2_adapters:
    action: "Load adapters based on config"
    mapping:
      task-source: "adapter-{config.task-source}"
      ci-cd: "adapter-{config.ci-cd}"
      tech-stack: "adapter-{config.tech-stack}"
      design: "adapter-{config.design}"
    on_missing: "WARN, continue without that adapter type"

  step_3_core:
    action: "Load core-orchestration"
    provides: [phase_sequence, handoff_contracts, checkpoint_schema, loop_limits]

  step_4_recovery:
    action: "Check docs/plans/{task-key}/checkpoint.yaml"
    found: "Resume from checkpoint.phase_completed + 1"
    not_found: "Start from Phase 0"

  step_5_task:
    action: "Fetch task via task-source adapter"
    call: "adapter.fetch_task(key)"
    output: "structured task object"

  step_6_classify:
    action: "Classify complexity"
    inputs: [adapter.get_complexity_hints(task), ac_count, modules_mentioned]
    output: "S|M|L|XL"

  step_7_route:
    action: "Select route from core-orchestration complexity_matrix"
    S: MINIMAL
    M: STANDARD
    L_XL: FULL
```

---

## Confirmation Summary

display_before_start:
  format: |
    **Task:** {task_key} — {title}
    **Project:** {project_name} ({tech_stack})
    **Complexity:** {S|M|L|XL} → Route: {MINIMAL|STANDARD|FULL}
    **Modules:** {detected_modules}
    **AC:** {ac_count} items
    **Figma:** {yes/no} ({url_count} URLs)
    **Credentials:** {if found in description}

    Proceed? (y/n)

  skip_if: "autonomous mode (--auto flag)"

---

## Branch Management

```yaml
branch_naming:
  format: "feat/{task_key}"
  example: "feat/ARGO-12345"
  steps:
    - "Check if branch already exists: git branch -a | grep {task_key}"
    - "If exists, ask user: switch to existing or create new?"
    - "Create: git checkout -b feat/{task_key}"
    - "Unset upstream to avoid accidental push to wrong branch: git branch --unset-upstream"
```

---

## 2. Pipeline Execution

Phases from core-orchestration. Worker dispatches each, validates handoffs, writes checkpoints.

```yaml
phases:
  - phase: 0
    name: task-analysis
    model: sonnet
    mode: inline
    action: "Classify complexity, select route (steps 5-7 above)"
    checkpoint: true

  - phase: 1
    name: planning
    skill: "pipeline-planner"
    model: opus
    mode: inline
    input: "task, complexity, route, tech_stack_adapter, design_adapter"
    output: "plan file path"
    checkpoint: true

  - phase: 2
    name: plan-review
    skill: "pipeline-plan-reviewer"
    model: sonnet
    mode: subagent
    skip_if: "complexity == S"
    input: "handoff: planner_to_reviewer (core-orchestration contract)"
    output: "verdict: APPROVED|NEEDS_CHANGES|REJECTED"
    checkpoint: true
    loop:
      max: 3
      with: "pipeline-planner"
      counter: "checkpoint.iteration.plan_review"

  - phase: 3
    name: implementation
    skill: "pipeline-coder"
    model: sonnet
    mode: inline
    input: "handoff: reviewer_to_coder, plan_path, tech_stack_adapter"
    output: "branch, parts_implemented, deviations"
    checkpoint: true

  - phase: 4
    name: code-review
    skill: "pipeline-code-reviewer"
    model: sonnet
    mode: subagent_worktree
    input: "handoff: coder_to_reviewer (core-orchestration contract)"
    output: "verdict: APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
    checkpoint: true
    loop:
      max: 3
      with: "pipeline-coder"
      counter: "checkpoint.iteration.code_review"

  - phase: 5
    name: ui-review
    skill: "pipeline-ui-reviewer"
    model: sonnet
    mode: subagent
    skip_if: "complexity == S OR no design adapter"
    input: "branch, figma_urls from task"
    output: "ui review report"
    checkpoint: true

  - phase: 6
    name: completion
    model: sonnet
    mode: inline
    actions:
      - commit: "Create git commit (MANDATORY)"
      - mr: "ASK user → if yes, ci-cd adapter create_mr()"
      - deploy: "ASK user → if yes, ci-cd adapter deploy()"
      - transition: "IF deployed: transition task to 'Ready for Test' via task-source adapter"
      - metrics: "Load core-metrics, collect and store"
      - checkpoint: "phase_completed: 6"
```

---

## 3. Phase Dispatch

```yaml
dispatch:
  before_phase:
    - validate: "handoff payload against core-orchestration contract"
    - check_skip: "evaluate skip_if condition"
    - check_loop: "guard against loop_limits (core-orchestration)"
    - log: "Starting Phase {N}: {name}"

  after_phase:
    - validate: "output handoff payload"
    - write_checkpoint: "docs/plans/{task-key}/checkpoint.yaml"
    - log: "Completed Phase {N}: {name}"

  on_loop:
    - increment: "checkpoint.iteration.{loop_type}"
    - check_limit: "core-orchestration loop_limits"
    - on_exceeded: "STOP, show iteration summary, request user intervention"
```

---

## 4. Autodetect

Fallback when `.claude/project.yaml` is absent.

```yaml
autodetect:
  tech-stack:
    angular: "package.json contains @angular"
    react: "package.json contains 'react' (not react-native)"
    go: "go.mod exists"
    python: "pyproject.toml or requirements.txt exists"

  ci-cd:
    gitlab: ".gitlab-ci.yml exists"
    github: ".github/workflows/ exists"

  task-source:
    jira: "task key matches [A-Z]+-\\d+"
    github-issues: "task key matches #\\d+"

  design:
    figma: "figma.com URL found in task description"
    none: "default when no design URLs detected"

  on_no_match: "WARN: Could not detect project type. Ask user for config."
```

---

## 5. Error Handling

```yaml
errors:
  no_config_no_detect:
    level: WARN
    action: "Ask user for project type or create .claude/project.yaml"

  task_fetch_failed:
    level: ERROR
    action: "Verify task key and MCP connection. Is Atlassian MCP running?"

  project_detect_failed:
    level: WARN
    action: "Ask user for project type"

  adapter_not_found:
    level: ERROR
    message: "Adapter '{name}' not found. Available: {list}"
    action: "List available adapters, ask user"

  phase_failed:
    level: ERROR
    action: "Save checkpoint, show error, ask user"

  handoff_validation_failed:
    level: ERROR
    message: "Missing required fields: {fields}"
    action: "Halt pipeline, report to user"

  loop_exceeded:
    level: STOP
    action: "STOP, show iteration summary (from core-orchestration)"
    do_not: "Auto-proceed or auto-approve"

  git_conflicts:
    level: ERROR
    action: "Show conflicted files, ask user to resolve"

  build_fails:
    level: ERROR
    action: "Show errors. If lint-only: auto-fix with format command. If test: show failures."

  pre_existing_lint_warnings:
    level: INFO
    action: "Ignore — exit code 1 on lint is normal for existing code"

  dev_server_wont_start:
    level: ERROR
    action: "Check if port is in use: lsof -i :4200"

  agent_browser_fails:
    level: WARN
    action: "Close browser, retry once. If still fails, skip UI review."

  glab_not_installed:
    level: ERROR
    action: "Install: brew install glab && glab auth login"

  glab_auth_expired:
    level: ERROR
    action: "Run: glab auth login"

  skill_not_found:
    level: WARN
    action: "Warn, fall back to inline execution"
```

---

## Cleanup

```yaml
trigger: "User says 'cleanup', 'очисти', 'remove plans'"
action: "Remove docs/plans/{task_key}/ directory"
confirmation: "Always ask before deleting"
```

---

## 6. Re-routing

From core-orchestration. Worker applies mid-pipeline.

```yaml
re_routing:
  check_points: [after_phase_1, after_phase_2]
  triggers:
    upgrade: "More AC/modules discovered than estimated"
    downgrade: "Task simpler than estimated"
  actions:
    - update: "checkpoint.complexity, checkpoint.route"
    - adjust: "Enable/disable phases per new route"
    - confirm: "ASK user before proceeding (confirmation gate)"
```
