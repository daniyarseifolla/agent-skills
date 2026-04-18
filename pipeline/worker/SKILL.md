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
      notification: "adapter-{config.notification}"
    on_missing: "WARN, continue without that adapter type"

  step_3_core:
    action: "Load core-orchestration"
    provides: [phase_sequence, handoff_contracts, checkpoint_schema, loop_limits]

  step_4_recovery:
    action: "Check docs/plans/{task-key}/checkpoint.yaml"
    found:
      primary: "Use checkpoint.resume if present and non-null"
      fallback: "next_phase_map[max(completed)] — for old checkpoints without resume"
      terminal_check: "If checkpoint.terminal_status is set → show status, ask user before resuming"
      invalidated_check: "If checkpoint.invalidated is non-empty → those phases must re-run"
    not_found: "Start from Phase 1: analyze"
    note: "Prefer resume (explicit) over max()+lookup (inferred). Both use next_phase_map as source of truth."

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

  flags:
    --arch-auto: "Pass auto_approve=true to planner's architect step"
    --model: "Override model for architect agents (opus|sonnet)"
```

---

## Confirmation Summary

CRITICAL: "This summary MUST be shown before ANY work begins. It is Phase 1: analyze output."

display_before_start:
  format: |
    **Task:** {task_key} — {title}
    **Project:** {project_name} ({tech_stack})
    **Complexity:** {S|M|L|XL} → Route: {MINIMAL|STANDARD|FULL}
    **Modules:** {detected_modules}
    **AC:** {ac_count} items
    **Figma:** {yes/no} ({url_count} URLs)
    **Credentials:** {if found in description}

    **Workspace options:**
    1. Worktree: использовать изолированный worktree? (y/n) [default: y for M+]
    2. CI: отключить CI на feature-ветке? (y/n) [default: y if .gitlab-ci.yml exists]

    Proceed? (y/n)

  skip_if: "autonomous mode (--auto flag)"

  after_confirm:
    step_1_worktree: "If user chose worktree=y → Invoke Skill: superpowers:using-git-worktrees"
    step_2_branch: "If worktree=n → create branch feat/{task_key} in current repo"
    step_2b_push: "Push branch to remote immediately: git push -u origin feat/{task_key}. Establishes remote tracking."
    step_3_ci: "If user chose CI=y AND not in worktree → ci-cd adapter disable_ci(task_key)"
    step_4_checkpoint: "Save checkpoint: completed: [1], ci_disabled: bool, worktree_path: string|null, app_url: string|null"
    step_4b_credentials: |
      If credentials found in task description:
        Write to docs/plans/{task-key}/.credentials (YAML)
        Add docs/plans/**/.credentials to .gitignore
        Store credentials_path in checkpoint (NOT credentials object)
      NEVER write passwords/tokens directly into checkpoint.yaml

---

## Workspace Setup

```yaml
workspace:
  description: "Ask user about worktree and CI before starting work"

  worktree_decision:
    prompt: |
      Использовать worktree для изоляции? (y/n)
      - Да: отдельная копия repo, не ломает текущий dev server и node_modules
      - Нет: работаем в текущем repo
    default: "y (recommended for M/L/XL tasks)"
    if_yes:
      action: "Invoke Skill: superpowers:using-git-worktrees"
      note: "Worktree создаётся в отдельной директории, основной repo не трогается"
    if_no:
      action: "Work in current repo, create branch directly"

  worktree_safety:
    CRITICAL: |
      NEVER clean up worktree if user's current shell is inside the worktree directory.
      NEVER clean up worktree if user is on the base branch in the main repo.
      Before cleanup:
        1. Check: pwd — are we inside the worktree?
        2. Check: git branch --show-current in main repo — is it the base branch?
        3. If either is true → WARN and skip cleanup, tell user to switch first
    cleanup_rules:
      - "Only cleanup after work is merged or user explicitly asks"
      - "Never auto-cleanup — always ask first"
      - "If worktree has uncommitted changes → REFUSE to cleanup"
      - "Show: 'Worktree at {path} still exists. Remove? (y/n)'"

  ci_decision:
    prompt: |
      CI pipeline detected (.gitlab-ci.yml exists).
      Disable CI during development? (y/n)
      - Да: CI не будет тратить minutes на каждый push
      - Нет: CI работает как обычно
    default: "y"
    flags:
      "--no-ci": "Disable CI without asking"
      "--keep-ci": "Keep CI enabled without asking"
    if_yes:
      action: "ci-cd adapter disable_ci(task_key)"
      checkpoint: "ci_disabled: true"
    if_no:
      action: "Skip, proceed normally"
      checkpoint: "ci_disabled: false"
    skip_if:
      - "Working in worktree (pushes from worktree don't trigger CI on feature branch)"
      - "No .gitlab-ci.yml exists"

  app_url_resolution:
    prompt: "Dev server URL? (auto-detect или укажи вручную)"
    auto_detect:
      - "curl -s -o /dev/null -w '%{http_code}' http://localhost:4200"
      - "curl -s -o /dev/null -w '%{http_code}' http://localhost:6200"
      - "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"
    if_detected: "Store in checkpoint.app_url"
    if_not_detected: "Ask user for URL, store in checkpoint.app_url"
    skip_if: "no design adapter (no UI review needed)"
```

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
  - phase: 1
    name: analyze
    model: sonnet
    mode: inline
    action: "Classify complexity, select route (steps 5-7 above)"
    checkpoint: true

  - phase: 2
    name: setup
    model: inherited
    mode: inline
    actions:
      - worktree: "Ask user: use worktree? (default y for M+) → if yes, Skill: superpowers:using-git-worktrees"
      - branch: "If no worktree → create branch feat/{task_key}"
      - ci: "Ask user: disable CI? (default y if .gitlab-ci.yml exists) → if yes, adapter disable_ci()"
    checkpoint: true
    skip_if: "resuming from checkpoint (workspace already set up)"
    on_resume_skip: |
      Even when Phase 2: setup is skipped during resume, verify workspace state:
        - worktree_path: if set, verify directory exists (cd into it)
        - credentials_path: if set, verify file exists. If missing → WARN, ask user to provide credentials
        - app_url: if set, verify server responds (curl). If unreachable → WARN, ask user to start dev server
        - ci_disabled: restore flag (no verification needed, used at Phase 9: ship)
      This prevents silent failures when workspace state drifted between sessions.

  - phase: 3
    name: research
    model: opus
    mode: inline
    skip_if: "complexity == S"
    action: "Deep task analysis: Figma screens + API discovery + functional map"
    MANDATORY: |
      ALL 3 agents MUST run. Do NOT skip any agent.
      Do NOT do inline analysis instead of dispatching agents.
      Do NOT decide "this is retro mode, skip Agent 3".
      Even for /attach — run all 3 agents if task-analysis.md doesn't exist.
      Use Agent(subagent_type: 'general-purpose') — NOT 'Explore' (Explore can't Write files).
    dispatch: |
      Step 1: mkdir -p docs/plans/{task-key}/screenshots/ && mkdir -p docs/plans/{task-key}/.tmp/
      Step 2: Launch Agent 1 + Agent 2 IN PARALLEL (dispatching-parallel-agents)
        Agent 1 (Figma Explorer, opus):
          - get_metadata(fileKey) → list all frames
          - For each matching frame: get_design_context → extract components/CSS
          - get_screenshot per frame → save to screenshots/
          - Identify: screen types, states, flows, interactive components
          - Output: .tmp/figma-screens.md
          - End with: ## Verdict: SUCCESS | PARTIAL | FAILED
        Agent 2 (API Discovery, sonnet):
          - tech_stack_adapter.api_discovery() → find swagger_url
          - WebFetch(swagger_url) → parse endpoints matching task entity
          - Test endpoints: GET → WebFetch, POST/PUT/DELETE → OPTIONS only (safety)
          - Classify: working / broken / missing / auth_required
          - Output: .tmp/api-analysis.md
          - End with: ## Verdict: SUCCESS | PARTIAL | FAILED
      Step 3: Check verdicts (Iron Law #2)
        Both FAILED → HALT, show error to user
        One FAILED → WARN, continue with partial data
      Step 4: Launch Agent 3 (Functional Mapper, opus) SEQUENTIALLY
        Input: orchestrator passes paths to .tmp/figma-screens.md + .tmp/api-analysis.md
        Maps: screen → action → endpoint → response → next screen
        Maps: form fields → Swagger schema fields
        Finds: gaps (Figma feature without endpoint, schema mismatches)
        Output: .tmp/functional-map.md
      Step 5: Merge .tmp/*.md → docs/plans/{task-key}/task-analysis.md
      Step 6: Confirmation gate
        Show task-analysis.md + screenshots to user
        Options: y (proceed) | edit (max 3 corrections) | abort
        If BROKEN/MISSING endpoints: offer create_backend_tasks (mcp createJiraIssue)
        If user chooses continue_without_api: set api_strategy: mock in task-analysis.md
      Step 7: Write checkpoint, cleanup .tmp/ (only after user confirms)
    checkpoint: true
    output: "task_analysis_path: docs/plans/{task-key}/task-analysis.md"

  - phase: 4
    name: impact
    skill: "pipeline-impact-analyzer"
    model: sonnet
    mode: inline
    action: "Scan consumers, siblings, shared code → impact-report.md"
    input: "task, task_analysis_path, complexity, tech_stack_adapter"
    output: "impact_report_path: docs/plans/{task-key}/impact-report.md"
    checkpoint: true

  - phase: 5
    name: plan
    skill: "pipeline-planner"
    model: opus
    mode: inline
    note: "Includes architect step for M+ (see planner SKILL.md)"
    input: "task, complexity, route, tech_stack_adapter, design_adapter, task_analysis_path, impact_report_path"
    output: "plan file path"
    checkpoint: true

  - phase: 6
    name: plan-review
    skill: "pipeline-plan-reviewer"
    model: opus
    mode: subagent
    skip_if: "complexity == S"
    consensus: "complexity >= M → MANDATORY: dispatch 3 opus subagents (AC, Architecture, Design). Do NOT do inline review. Do NOT skip consensus."
    input: "handoff: planner_to_reviewer (core-orchestration contract)"
    output: "verdict: APPROVED|NEEDS_CHANGES|REJECTED"
    checkpoint: true
    loop:
      max: 3
      with: "pipeline-planner"
      counter: "checkpoint.iteration.plan_review"
      on_NEEDS_CHANGES:
        invalidated: [6]
        resume: 5

  - phase: 7
    name: implement
    skill: "pipeline-coder"
    model: sonnet
    mode: inline
    input: "handoff: reviewer_to_coder, plan_path, tech_stack_adapter"
    output: "branch, parts_implemented, deviations"
    checkpoint: true
    evaluate_gate:
      on_RETURN:
        checkpoint_write:
          invalidated: [7]
          resume: 6
          iteration.evaluate_return: "+= 1"
          handoff_payload: "coder_evaluate_return contract (plan_issues, blocked_parts)"
        action: "Loop back to Phase 6: plan-review — not Phase 5: plan (planner)"
        note: "See core-orchestration invalidation_rules.evaluate_return"

  - phase: 8
    name: review
    description: "Code review + UI review run in parallel (they are independent)"
    consensus: "complexity >= M → MANDATORY: dispatch 3 subagents per reviewer. Do NOT do inline review. Do NOT run Phase 8 reviews sequentially — PARALLEL."
    parallel:
      - skill: "pipeline-code-reviewer"
        model: sonnet
        mode: "subagent_worktree"
        consensus_agents: "Bug hunter + Plan compliance + Security (when M+)"
        input: "handoff from coder"
        output: "code review verdict"
      - skill: "pipeline-ui-reviewer"
        model: sonnet
        mode: subagent
        skip_if: "no design adapter"
        consensus_agents: "Functional + Visual fidelity + States/A11y (when M+)"
        input: "branch, figma_urls"
        output: "ui review report"

    after_parallel:
      - "If code-review returned CHANGES_REQUESTED:"
      - "  → discard ui-review results (tested pre-fix code)"
      - "  → loop back to coder (Phase 7: implement)"
      - "  → after fix, re-run Phase 8: review parallel again"
      - "If code-review returned APPROVED/APPROVED_WITH_COMMENTS:"
      - "  → accept both results"
      - "  → proceed to Phase 9: ship"

    checkpoint_rules:
      on_CHANGES_REQUESTED: |
        completed: [...existing] (do NOT add 8 — results are stale)
        invalidated: [8]
        resume: 7
        iteration.code_review += 1
        Note: Phase 8 verdict itself is an artifact of the rejected code — not a valid completed phase.
      on_APPROVED: |
        completed: [...existing, 8]
        invalidated: [] (clear)
        resume: 9
        Proceed to Phase 9: ship. Do NOT add 9 yet — Phase 9 is ship, it writes its own checkpoint.
      on_APPROVED_plus_ISSUES_FOUND: |
        completed: [...existing, 8]
        invalidated: [] (clear)
        resume: 9
        Log ISSUES_FOUND findings. Proceed to Phase 9: ship.

    checkpoint: true
    loop: "max 3 with coder (per iron_laws)"

  - phase: 9
    name: ship
    model: sonnet
    mode: inline
    actions:
      - commit: "If uncommitted changes exist (from review fixes), commit them. If all parts already committed in Phase 7: implement, skip."
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
          on_cancel: "Write checkpoint: terminal_status: stopped_by_user, resume: 9. STOP."
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
              MANDATORY — Jira transition is a REQUIRED step, not optional.
              task_source_adapter.transition(task_key, 'Ready for Test')
              QA tracks readiness via Jira status — skipping this breaks their workflow.
              skip_if: no task_source adapter loaded (this is the ONLY valid skip reason)
              Do NOT rationalize skipping: "small change", "not critical", "I'll do later" — WRONG.
              If transition API call fails → WARN (don't halt pipeline), log error, continue to step 12.
            12_notify: |
              MUST load adapter-slack skill and follow its template EXACTLY.
              Call: notification_adapter.notify_deploy(task_key, environment)
              Template (4 lines, no extras):
                {mention}
                <{$JIRA_BASE_URL}/browse/{task_key}|{task_key}> задеплоен на {environment}
                {summary — импакт для пользователя, НЕ тех. термины}
                <{env_url from CLAUDE.md/.gitlab-ci.yml: host + base_href}|Тест/Прод>
              NEVER add: MR link, pipeline link, branch name, raw URLs, verification steps.
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
      - checkpoint: "completed: [...existing, 9], terminal_status: success, resume: null"
      - metrics: "Load core-metrics, collect and store (success collection — reads from checkpoint written above)"
      - ordering: "checkpoint BEFORE metrics — metrics reads completed and terminal_status from checkpoint"
```

---

## 3. Phase Dispatch

```yaml
dispatch:
  before_phase:
    - validate: "handoff payload against core-orchestration contract"
    - check_skip: "evaluate skip_if condition"
    - check_invalidation: |
        If this phase is in checkpoint.invalidated:
          → Remove from invalidated (it's about to re-run)
          → Log: "Phase {N}: {name} re-running (was invalidated by loop-back)"
        If ANY phase in invalidated has lower ID than current phase:
          → HALT: "Cannot proceed to Phase {N}: {name} — Phase {invalidated} must re-run first"
          → Set resume to min(invalidated)
          → This prevents skipping to completion with stale review state
    - check_loop: "guard against loop_limits (core-orchestration)"
    - log: "Starting Phase {N}: {name}"

  after_phase:
    - validate: "output handoff payload"
    - write_checkpoint: "docs/plans/{task-key}/checkpoint.yaml"
    - push_checkpoint: |
        After phases that produce commits or artifacts, push to remote:
          Phase 2: setup — git push -u origin feat/{task_key} (establish tracking)
          Phase 7: implement — git push (implementation commits)
          Phase 8: review (after fix loop) — git push (review fix commits)
          Phase 9: ship — git push (final state)
        Phases 1: analyze, 3: research, 4: impact, 5: plan, 6: plan-review — no push needed (no commits, only plan/analysis artifacts)
        Rule: NEVER lose work to a crashed session. If commits exist locally, push them.
    - log: "Completed Phase {N}: {name}"
    - message: |
        Phase {N} ({phase_name}) complete.
        Resume with: /continue {task_key}
        Check progress: /progress {task_key}

  on_loop:
    - increment: "checkpoint.iteration.{loop_type}"
    - check_limit: "core-orchestration loop_limits"
    - on_exceeded: |
        1. Write checkpoint: terminal_status = "loop_exceeded", resume = loop target, handoff = preserve
        2. Write terminal metrics (reads from checkpoint written in step 1)
        3. STOP, show iteration summary, request user intervention
      ordering: "checkpoint → metrics → display → STOP"
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
    action: |
      1. Write checkpoint FIRST:
         - terminal_status: "failed"
         - resume: failed phase (to retry)
         - handoff_payload: preserve last known
      2. Write terminal metrics (reads from checkpoint written in step 1)
      3. Show error, ask user
    ordering: "checkpoint → metrics → display (always this order)"

  handoff_validation_failed:
    level: ERROR
    message: "Missing required fields: {fields}"
    action: "Halt pipeline, report to user"

  loop_exceeded:
    level: STOP
    action: |
      1. Write checkpoint FIRST:
         - terminal_status: "loop_exceeded"
         - resume: current loop target phase (for potential manual re-run)
         - completed: current state (preserve)
         - handoff_payload: last known payload (preserve for repair)
      2. Write terminal metrics (reads from checkpoint written in step 1)
      3. STOP, show iteration summary (from core-orchestration)
    ordering: "checkpoint → metrics → display → STOP (always this order)"
    do_not: "Auto-proceed or auto-approve"

  user_stop:
    level: STOP
    trigger: "User says 'stop', 'отмена', 'abort', rejects confirmation gate, or /continue is declined"
    action: |
      1. Write checkpoint FIRST:
         - terminal_status: "stopped_by_user"
         - resume: current phase (to retry later)
         - handoff_payload: preserve last known
      2. Write terminal metrics (reads from checkpoint written in step 1)
      3. Display: "Pipeline stopped by user at Phase {N}: {name}. Resume with /continue {task_key}"
    ordering: "checkpoint → metrics → display → STOP"

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
  check_points: [after_plan, after_plan-review]
  triggers:
    upgrade: "More AC/modules discovered than estimated"
    downgrade: "Task simpler than estimated"
  actions:
    - update: "checkpoint.complexity, checkpoint.route"
    - adjust: "Enable/disable phases per new route"
    - confirm: "ASK user before proceeding (confirmation gate)"
```
