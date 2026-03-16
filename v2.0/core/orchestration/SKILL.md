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
