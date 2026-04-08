---
name: literal-core-orchestration
description: "Internal orchestration protocols: handoff contracts, checkpoint/recovery, loop limits, evaluate gate, complexity routing, re-routing. Loaded by pipeline/worker — never invoked directly."
disable-model-invocation: true
---

# Core Orchestration

Internal protocol definitions for pipeline execution. Not a user-facing skill.

---

## 1. Pipeline Phases

```yaml
# CANONICAL phase table — single source of truth for all skills
phase_sequence:
  - { id: 0,   name: task-analysis,    model: sonnet, mode: inline,            action: "classify complexity, select route" }
  - { id: 0.5, name: workspace-setup,  model: sonnet, mode: inline,            action: "worktree, CI disable, dev server, confirmation" }
  - { id: 0.7, name: deep-analysis,   model: opus,   mode: inline,            action: "Figma exploration + API discovery + functional map", skip_when: "complexity == S" }
  - { id: 0.8, name: impact-analysis, model: sonnet, mode: inline,            action: "consumers, siblings, shared code → impact-report.md" }
  - { id: 1,   name: planner,          model: opus,   mode: inline,            action: "research codebase, produce plan" }
  - { id: 2,   name: plan-reviewer,    model: opus,   mode: subagent,          action: "validate plan against AC (consensus 3x3 opus for M+)", skip_when: "complexity == S" }
  - { id: 3,   name: coder,            model: sonnet, mode: inline,            action: "evaluate gate, then implement" }
  - { id: 4,   name: code-reviewer,    model: sonnet, mode: subagent_worktree, action: "architecture + security review (core-security + tech-stack security_checks)" }
  - { id: 5,   name: ui-reviewer,      model: sonnet, mode: subagent,          action: "functional + visual review", skip_when: "no design adapter" }
  - { id: 6,   name: completion,        model: sonnet, mode: inline,            action: "commit, collect metrics, store lessons" }

# Phase 4+5 run in PARALLEL when both are active (Iron Law #1)

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

---

## 2. Complexity Routing

```yaml
complexity_matrix:
  S:  { ac: "1-2", modules: 1,    plan_review: skip,     ui_review: if_design_adapter, code_researcher: false, seq_thinking: false,       route: MINIMAL }
  M:  { ac: "3-4", modules: 2,    plan_review: standard, ui_review: if_design_adapter, code_researcher: false, seq_thinking: optional,    route: STANDARD }
  L:  { ac: "5-6", modules: "3+", plan_review: standard, ui_review: true,              code_researcher: true,  seq_thinking: recommended, route: FULL }
  XL: { ac: "7+",  modules: "4+", plan_review: standard, ui_review: true,              code_researcher: true,  seq_thinking: required,    route: FULL }

route_definitions:
  MINIMAL:  { phases: [0, 0.5, 0.8, 1, 3, 4, 5, 6],          note: "skip deep-analysis, plan-review. Phase 5 conditional on design adapter." }
  STANDARD: { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6],   note: "all phases, ui-review conditional on design adapter" }
  FULL:     { phases: [0, 0.5, 0.7, 0.8, 1, 2, 3, 4, 5, 6],   note: "all phases, all tools enabled" }
```

---

## 3. Handoff Protocol

Typed contracts validated before each receiving phase starts.

```yaml
task_schema:
  title: string
  description: string
  acceptance_criteria: string[]
  figma_urls: string[]
  credentials: "object|null — { username, password } or { token } or null"
  priority: "string|null"
  subtasks: "string[]|null"
  source_url: "string — original task URL"
  note: "Produced by task-source adapter fetch_task(). All consumers reference this schema."

handoff_contracts:
  planner_to_reviewer:
    artifact_path: string         # path to plan file
    key_decisions: string[]       # major architecture choices
    known_risks: string[]         # identified risks
    complexity: "S|M|L|XL"
    required: [artifact_path, key_decisions, complexity]

  reviewer_to_coder:
    verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
    approved_notes: string[]      # non-blocking suggestions
    issues: string[]              # if NEEDS_CHANGES
    iteration: "N/3"
    required: [verdict, iteration]

  coder_to_reviewer:
    branch: string
    parts_implemented: string[]
    deviations_from_plan: string[]
    risks_mitigated: string[]
    required: [branch, parts_implemented]

  reviewer_to_completion:
    verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
    comments: string[]
    issues: string[]              # if CHANGES_REQUESTED
    iteration: "N/3"
    required: [verdict, iteration]

  worker_to_planner:
    task: "task_schema — typed object from task-source adapter"
    required: [task, complexity, route, figma_urls, ui_inventory_path, task_analysis_path, impact_report_path]
    optional: [tech_stack_adapter, design_adapter]
    task_analysis_path: "string|null — path to task-analysis.md from Phase 0.7. Null for S complexity."
    impact_report_path: "string — path to impact-report.md from Phase 0.8."
    note: "Worker passes full task object (see task_schema above) + classification results to planner"

  impact_analyzer_to_planner:
    impact_report_path: string
    must_fix_count: number
    must_verify_count: number
    required: [impact_report_path]
    note: "Phase 0.8 output. Planner reads impact-report.md to include must-fix items as plan Parts."

  worker_to_ui_reviewer:
    required: [branch, figma_urls, app_url, credentials]
    optional: [design_adapter, tech_stack_adapter, ui_inventory_path]
    note: "Worker resolves app_url and credentials BEFORE dispatching ui-reviewer"

  coder_evaluate_return:
    required: [plan_issues, blocked_parts]
    optional: [suggestions]
    note: "Coder returns to plan-reviewer when plan is not implementable (RETURN verdict)"

  ui_reviewer_to_completion:
    required: [verdict, score]
    optional: [breakdown, blockers, suggestions]
    verdict_values: "PASS | PASS_WITH_ISSUES | ISSUES_FOUND"
    note: "ISSUES_FOUND is non-blocking (logs_only in verdict_mapping)"

handoff_validation: >
  Before starting a phase, verify all required fields in the incoming
  handoff are present and non-empty. On failure: halt, report missing fields.
```

### Verdict Vocabulary Reference

```yaml
verdict_mapping:
  plan_review:
    verdicts: [APPROVED, NEEDS_CHANGES, REJECTED]
    note: "NEEDS_CHANGES = plan needs revision, loop back to planner"

  code_review:
    verdicts: [APPROVED, APPROVED_WITH_COMMENTS, CHANGES_REQUESTED]
    note: "CHANGES_REQUESTED = code needs fixes, loop back to coder"

  ui_review:
    verdicts: [PASS, PASS_WITH_ISSUES, ISSUES_FOUND]
    note: "PASS_WITH_ISSUES = minor issues logged, proceed. ISSUES_FOUND = issues logged, proceed (no loop)"

  evaluate_gate:
    verdicts: [PROCEED, REVISE, RETURN]
    note: "RETURN = plan not implementable, loop back to plan-review"

  mapping_for_worker:
    description: "Worker must handle all verdict vocabularies. Use this mapping:"
    blocks_progress: [NEEDS_CHANGES, CHANGES_REQUESTED, RETURN, REJECTED]
    allows_progress: [APPROVED, APPROVED_WITH_COMMENTS, PROCEED, REVISE, PASS, PASS_WITH_ISSUES]
    logs_only: [ISSUES_FOUND]
```

---

## 4. Checkpoint Protocol

Path: `docs/plans/{task-key}/checkpoint.yaml`. Overwritten after each phase.

```yaml
checkpoint_schema:
  task_key: string
  completed_phases: "number[] — e.g. [0, 0.5, 0.7, 1, 2]. Set semantics, append-only."
  resume_phase: "number|null — explicit next phase to execute. Written on every checkpoint. Primary source for recovery."
  invalidated_phases: "number[] — phases whose results are no longer valid (e.g. [4, 5] after CHANGES_REQUESTED loop-back). Cleared when those phases re-complete."
  terminal_status: "running|success|failed|stopped_by_user|loop_exceeded|null — set on pipeline exit. null while running."
  phase_name: string
  iteration: { plan_review: "N/3", code_review: "N/3", evaluate_return: "N/2" }
  verdict: string
  complexity: "S|M|L|XL"
  route: "MINIMAL|STANDARD|FULL"
  timestamp: "ISO-8601"
  ci_disabled: "boolean — whether CI was disabled during development"
  worktree_path: "string|null — path to worktree if used, null if working in main repo"
  app_url: "string|null — dev server URL for UI review, resolved in Phase 0.5"
  credentials_path: "string|null — path to .credentials file (gitignored), NOT inline credentials"
  handoff_payload: object
  issues_history: object[]

  DEPRECATED: "phase_completed (scalar) is replaced by completed_phases (array). max(completed_phases) is fallback only — prefer resume_phase."

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

checkpoint_rules:
  write_after: [phase_completion, review_iteration, re_route_decision, terminal_event]
  format: YAML
  location: "docs/plans/{task-key}/checkpoint.yaml"
  overwrite: true
  on_every_write:
    - "Set resume_phase to the next phase that should execute (from next_phase_map or loop target)"
    - "Set invalidated_phases if loop-back occurred (see invalidation_rules)"
    - "Set terminal_status on pipeline exit (success, failed, stopped_by_user, loop_exceeded)"
    - "Clear invalidated_phases entries when those phases re-complete successfully"

invalidation_rules:
  code_review_loop:
    trigger: "Phase 4 verdict == CHANGES_REQUESTED"
    invalidated_phases: [4, 5]
    resume_phase: 3
    reason: "Both review results are artifacts of the rejected code. Phase 4 itself is an assessment of code that will change — its findings are stale after rework."
    clear_when: "Phase 4 and 5 re-complete after coder fix"

  plan_review_loop:
    trigger: "Phase 2 verdict == NEEDS_CHANGES"
    invalidated_phases: [2]
    resume_phase: 1
    reason: "Plan-review result references a plan that will be revised"
    clear_when: "Phase 2 re-completes after planner revision"

  evaluate_return:
    trigger: "Phase 3 evaluate gate verdict == RETURN"
    invalidated_phases: [3]
    resume_phase: 2
    reason: "Coder determined plan is not implementable — return to plan-review"
    clear_when: "Phase 3 re-completes after plan revision"
```

---

## 5. Session Recovery

Strategy: checkpoint-first, heuristic fallback.

```yaml
recovery_from_checkpoint:
  - read: "docs/plans/{task-key}/checkpoint.yaml"
  - resume_from: |
      PRIMARY:  checkpoint.resume_phase (if present and non-null)
      FALLBACK: next_phase_map[max(completed_phases)] (backward compat for old checkpoints)
  - enforce_invalidation: |
      If invalidated_phases is non-empty:
        → resume_phase MUST be <= min(invalidated_phases)
        → If resume_phase > min(invalidated_phases): override resume_phase = min(invalidated_phases)
        → Worker before_phase guard blocks any phase > min(invalidated_phases) until cleared
        → This is an invariant, not a suggestion
  - check_terminal: "If terminal_status is set (success|failed|stopped_by_user|loop_exceeded) → do NOT auto-resume. Show status, ask user."
  - restore: [handoff_payload, iteration_counters, worktree_path, credentials_path, app_url, ci_disabled]

recovery_heuristic:
  # Artifact presence -> resume point (when no checkpoint exists)
  # Uses worker phase IDs (fractional). Heuristic creates checkpoint with resume_phase set.
  - { task_analysis: yes, plan: no, evaluate: "-", code: "-", resume: "Phase 0.8 (worker 0.8) — impact analysis (with task-analysis.md)" }
  - { plan: no,  evaluate: "-", code: "-", resume: "Phase 0.8 (worker 0.8) — impact analysis then planning" }
  - { plan: yes, evaluate: no,  code: no,  resume: "Phase 3 (worker 3) — evaluate gate" }
  - { plan: yes, evaluate: yes, code: no,  resume: "Phase 3 (worker 3) — start coding" }
  - { plan: yes, evaluate: "-", code: yes, resume: "Phase 4 (worker 4) — code review" }

artifact_paths:
  plan: "docs/plans/{task-key}/plan.md"
  evaluate: "docs/plans/{task-key}/evaluate.md"
  code: "git diff --name-only main..HEAD | wc -l > 0"
```

---

## 6. Loop Limits

```yaml
loop_limits:
  plan_review: { max: 3, participants: [planner, plan-reviewer], counter: "checkpoint.iteration.plan_review" }
  code_review: { max: 3, participants: [coder, code-reviewer],   counter: "checkpoint.iteration.code_review" }

  evaluate_return:
    max: 2
    participants: [coder_evaluate, plan_reviewer]
    counter: "checkpoint.iteration.evaluate_return"
    on_exceeded: "STOP → show plan issues from all attempts → request user intervention"
    note: "RETURN from evaluate gate is more severe than NEEDS_CHANGES — lower budget"

  rejected_handling:
    rule: "REJECTED from plan-reviewer → STOP immediately, do not consume loop iteration"
    action: "Show rejection reason to user. Do not re-plan without explicit user guidance."

guard_check:
  when: "BEFORE launching any re-loop phase"
  on_exceeded:
    - STOP
    - display: "iteration summary table (iteration, verdict, issues_raised, issues_resolved)"
    - request: "user intervention required"
    - do_not: "auto-proceed or auto-approve"
```

---

## 7. Evaluate Gate

Coder evaluates the plan before writing any implementation code.

```yaml
evaluate_gate:
  trigger: "Phase 3 start, before any code changes"
  output: "docs/plans/{task-key}/evaluate.md"

  verdicts:
    PROCEED: "Plan valid — begin implementation"
    REVISE:  "Plan mostly valid — document deviations in evaluate.md, continue"
    RETURN:  "Plan not implementable — return to plan-review with {issues, suggestions}"

  checks:
    - "All referenced files/modules accessible?"
    - "Proposed APIs compatible with existing code?"
    - "Hidden dependencies missed?"
    - "Implementation order logical?"
    - "AC testable with proposed approach?"
```

---

## 8. Re-routing

Self-correction when complexity was misclassified at Phase 0.

```yaml
re_routing:
  upgrade_triggers:
    - "Planner discovered more modules/AC than estimated (e.g. S->M)"
    - "Reviewer found architectural issues requiring broader changes (e.g. M->L)"
  downgrade_triggers:
    - "Task simpler than estimated after research (e.g. M->S)"

  actions:
    - update: [checkpoint.complexity, checkpoint.route]
    - adjust: "enable/disable phases per new route"
    - notify: "user via confirmation gate"

  checkpoint_fields:
    re_routed: true
    re_route_detail: "string, e.g. S->M after planning"
```

---

## 9. User Confirmation Gates

These actions ALWAYS require explicit user confirmation before proceeding.

```yaml
confirmation_gates:
  - { action: mr_creation, prompt: "Ready to create MR. Proceed?" }
  - { action: deploy,      prompt: "Ready to deploy to {environment}. Proceed?", applies_to: "all environments" }
  - { action: re_route,    prompt: "Complexity re-assessed: {old} -> {new}. Proceed?" }

gate_rules:
  never_auto_approve: true
  on_timeout: "Write checkpoint with terminal_status: stopped_by_user, resume_phase: current phase. Write terminal metrics. Halt."
  on_rejection: "Write checkpoint with terminal_status: stopped_by_user, resume_phase: current phase. Write terminal metrics. Halt, await instructions."
```

---

## 10. Iron Laws of Agent Orchestration

```yaml
iron_laws:
  1_parallel_first:
    rule: "Never spawn workers sequentially when they are independent"
    action: "Dispatch all independent agents in ONE message with multiple Agent tool calls"
    example: "code-review + ui-review are independent → dispatch both in parallel"

  2_detect_failures:
    rule: "Always check agent results for failure signals"
    action: "After each agent completes, parse output for verdict keywords (APPROVED/FAIL/CHANGES_REQUESTED). If no verdict found → treat as ERROR, ask user."
    never: "Silence does not mean success. Missing verdict = failed agent."

  3_no_cross_worker:
    rule: "Agents do not communicate with each other — everything goes through the orchestrator"
    action: "Worker dispatches agents, collects results, decides next step. Agents never reference other agents' output directly."

  4_structured_handoff:
    rule: "Every agent result must contain: verdict + findings + recommendations"
    enforcement: "Worker parses for verdict keyword. If missing → ERROR."

  5_max_workers:
    rule: "Maximum 7 parallel agents per fan-out"
    why: "More than 7 causes OOM, context pollution, and resource contention"
    applies_to: "ui-reviewer QA agent groups, any dispatching-parallel-agents usage"
```

---

## 11. Task Classification

```yaml
task_classification:
  independent:
    description: "Tasks with no shared state, can run in parallel"
    examples:
      - "Phase 4 (code-review) + Phase 5 (ui-review)"
      - "QA agent groups in ui-reviewer"
    dispatch: "Parallel — multiple Agent calls in one message"

  dependent:
    description: "Task B needs Task A's output"
    examples:
      - "Phase 1 (plan) → Phase 2 (plan-review) — reviewer needs the plan"
      - "Phase 3 (code) → Phase 4 (code-review) — reviewer needs the diff"
    dispatch: "Sequential — wait for A, then start B"

  fan_out_fan_in:
    description: "One input splits into N parallel tasks, results merge back"
    examples:
      - "ui-reviewer: 1 test plan → N QA agents → 1 merged report"
    dispatch: "Parallel dispatch, then aggregate"
    max_fan_out: 7

  pipeline:
    description: "Data flows through a chain of transformations"
    examples:
      - "plan → review → code → review → completion"
    dispatch: "Strictly sequential with handoff contracts"
```

---

## 12. Verdict Parsing Protocol

```yaml
verdict_parsing:
  description: "How worker extracts verdicts from agent free-text output"

  method: "Keyword search in agent output text"

  keywords:
    positive: ["APPROVED", "APPROVED_WITH_COMMENTS", "PROCEED", "PASS", "PASS_WITH_ISSUES"]
    negative: ["NEEDS_CHANGES", "CHANGES_REQUESTED", "REJECTED", "RETURN", "FAIL"]
    non_blocking_negative: ["ISSUES_FOUND"]
    error: ["ERROR", "STOP", "BLOCKED"]

  algorithm:
    step_1: "Search agent output for any keyword from negative list"
    step_1b: "Search for non_blocking_negative keywords (ISSUES_FOUND)"
    step_1b_action: "If found → log findings, do NOT block progress. Proceed to step_3."
    step_2: "If negative found → extract the specific verdict (e.g., CHANGES_REQUESTED)"
    step_3: "If no negative → search for positive keyword"
    step_4: "If positive found → extract verdict"
    step_5: "If NO keyword found → treat as ERROR, show output to user, ask for interpretation"

  never: "Do not assume success when no verdict is found. Missing verdict = failed agent."
```
