---
name: core-orchestration
description: "Internal orchestration protocols: handoff contracts, checkpoint/recovery, loop limits, evaluate gate, complexity routing, re-routing. Loaded by pipeline/worker — never invoked directly."
disable-model-invocation: true
---

# Core Orchestration

Internal protocol definitions for pipeline execution. Not a user-facing skill.

---

## 1. Pipeline Phases

```yaml
phase_sequence:
  - { id: 0, name: task-analysis,  model: sonnet, mode: inline,            action: "classify complexity, select route" }
  - { id: 1, name: planner,        model: opus,   mode: inline,            action: "research codebase, produce plan" }
  - { id: 2, name: plan-reviewer,  model: sonnet, mode: subagent,          action: "validate plan against AC", skip_when: "complexity == S" }
  - { id: 3, name: coder,          model: sonnet, mode: inline,            action: "evaluate gate, then implement" }
  - { id: 4, name: code-reviewer,  model: sonnet, mode: subagent_worktree, action: "architecture + security review (core-security)" }
  - { id: 5, name: ui-reviewer,    model: sonnet, mode: subagent,          action: "functional + visual review", skip_when: "complexity == S OR no design adapter" }
  - { id: 6, name: completion,     model: sonnet, mode: inline,            action: "commit, collect metrics, store lessons" }
```

---

## 2. Complexity Routing

```yaml
complexity_matrix:
  S:  { ac: "1-2", modules: 1,    plan_review: skip,     ui_review: skip,              code_researcher: false, seq_thinking: false,       route: MINIMAL }
  M:  { ac: "3-4", modules: 2,    plan_review: standard, ui_review: if_design_adapter, code_researcher: false, seq_thinking: optional,    route: STANDARD }
  L:  { ac: "5-6", modules: "3+", plan_review: standard, ui_review: true,              code_researcher: true,  seq_thinking: recommended, route: FULL }
  XL: { ac: "7+",  modules: "4+", plan_review: standard, ui_review: true,              code_researcher: true,  seq_thinking: required,    route: FULL }

route_definitions:
  MINIMAL:  { phases: [0, 1, 3, 4, 6],       note: "skip plan-review, ui-review" }
  STANDARD: { phases: [0, 1, 2, 3, 4, 5, 6], note: "all phases, ui-review conditional" }
  FULL:     { phases: [0, 1, 2, 3, 4, 5, 6], note: "all phases, all tools enabled" }
```

---

## 3. Handoff Protocol

Typed contracts validated before each receiving phase starts.

```yaml
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
    verdicts: [PASS, ISSUES_FOUND]
    note: "ISSUES_FOUND = issues logged, proceed to completion (no loop)"

  evaluate_gate:
    verdicts: [PROCEED, REVISE, RETURN]
    note: "RETURN = plan not implementable, loop back to plan-review"

  mapping_for_worker:
    description: "Worker must handle all verdict vocabularies. Use this mapping:"
    blocks_progress: [NEEDS_CHANGES, CHANGES_REQUESTED, RETURN, REJECTED]
    allows_progress: [APPROVED, APPROVED_WITH_COMMENTS, PROCEED, REVISE, PASS]
    logs_only: [ISSUES_FOUND]
```

---

## 4. Checkpoint Protocol

Path: `docs/plans/{task-key}/checkpoint.yaml`. Overwritten after each phase.

```yaml
checkpoint_schema:
  task_key: string
  phase_completed: "0-6"
  phase_name: string
  iteration: { plan_review: "N/3", code_review: "N/3" }
  verdict: string
  complexity: "S|M|L|XL"
  route: "MINIMAL|STANDARD|FULL"
  timestamp: "ISO-8601"
  ci_disabled: "boolean — whether CI was disabled during development"
  worktree_path: "string|null — path to worktree if used, null if working in main repo"
  handoff_payload: object
  issues_history: object[]

checkpoint_rules:
  write_after: [phase_completion, review_iteration, re_route_decision]
  format: YAML
  location: "docs/plans/{task-key}/checkpoint.yaml"
  overwrite: true
```

---

## 5. Session Recovery

Strategy: checkpoint-first, heuristic fallback.

```yaml
recovery_from_checkpoint:
  - read: "docs/plans/{task-key}/checkpoint.yaml"
  - resume_from: "phase_completed + 1"
  - restore: [handoff_payload, iteration_counters]

recovery_heuristic:
  # Artifact presence -> resume point (when no checkpoint exists)
  - { plan: no,  evaluate: "-", code: "-", tests: "-", resume: "Phase 1 — start planning" }
  - { plan: yes, evaluate: no,  code: no,  tests: "-", resume: "Phase 3 — evaluate gate" }
  - { plan: yes, evaluate: yes, code: no,  tests: "-", resume: "Phase 3 — start coding" }
  - { plan: yes, evaluate: yes, code: yes, tests: no,  resume: "Phase 3 — fix tests" }
  - { plan: yes, evaluate: yes, code: yes, tests: yes, resume: "Phase 4 — code review" }

artifact_paths:
  plan: "docs/plans/{task-key}/plan.md"
  evaluate: "docs/plans/{task-key}/evaluate.md"
  code: "git diff --name-only main..HEAD | wc -l > 0"
  tests: "run project test command, check exit code"
```

---

## 6. Loop Limits

```yaml
loop_limits:
  plan_review: { max: 3, participants: [planner, plan-reviewer], counter: "checkpoint.iteration.plan_review" }
  code_review: { max: 3, participants: [coder, code-reviewer],   counter: "checkpoint.iteration.code_review" }

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
  on_timeout: "halt pipeline, preserve checkpoint"
  on_rejection: "halt pipeline, preserve checkpoint, await instructions"
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
    positive: ["APPROVED", "APPROVED_WITH_COMMENTS", "PROCEED", "PASS"]
    negative: ["NEEDS_CHANGES", "CHANGES_REQUESTED", "REJECTED", "RETURN", "FAIL", "ISSUES_FOUND"]
    error: ["ERROR", "STOP", "BLOCKED"]

  algorithm:
    step_1: "Search agent output for any keyword from negative list"
    step_2: "If found → extract the specific verdict (e.g., CHANGES_REQUESTED)"
    step_3: "If no negative → search for positive keyword"
    step_4: "If positive found → extract verdict"
    step_5: "If NO keyword found → treat as ERROR, show output to user, ask for interpretation"

  never: "Do not assume success when no verdict is found. Missing verdict = failed agent."
```
