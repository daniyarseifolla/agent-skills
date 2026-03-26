---
name: core-metrics
description: "Pipeline metrics collection and storage. Loaded by pipeline/worker at completion — never invoked directly."
disable-model-invocation: true
---

# Core Metrics

Metrics schema and collection procedure for pipeline completion phase.

---

## 1. Metrics Schema

```yaml
metrics:
  task_key: string
  complexity: "S|M|L|XL"
  route: "MINIMAL|STANDARD|FULL"
  phases_completed: number
  iterations:
    plan_review: number
    code_review: number
  re_routed: boolean
  re_route_detail: "string|null"   # e.g., "S->M after planning"
  evaluate_result: "PROCEED|REVISE|RETURN"
  issues_found:
    blocker: number
    major: number
    minor: number
    nit: number
  files_changed: number
  lines_added: number
  lines_removed: number
  duration:
    total_minutes: "number — total pipeline duration"
    per_phase: "object — { deep_analysis: N, planning: N, plan_review: N, implementation: N, code_review: N, ui_review: N }"
  outcome: "success | failed | stopped_by_user | loop_exceeded"
  stopped_at_phase: "number | null — which phase stopped (if not completed)"
  stopped_reason: "string | null — why stopped"
  timestamp: "ISO-8601"
```

## 1b. Validation Rules

```yaml
validation:
  required: [task_key, complexity, route, phases_completed, outcome, timestamp]
  rules:
    task_key: "regex: [A-Z]+-\\d+"
    complexity: "enum: S|M|L|XL"
    route: "enum: MINIMAL|STANDARD|FULL"
    phases_completed: "integer 0-7"
    iterations.plan_review: "integer 0-3"
    iterations.code_review: "integer 0-3"
    iterations.evaluate_return: "integer 0-2"
    outcome: "enum: success|failed|stopped_by_user|loop_exceeded"
    files_changed: "integer >= 0"
    lines_added: "integer >= 0"
    lines_removed: "integer >= 0"
    duration.total_minutes: "number > 0 or null"
    timestamp: "ISO-8601 format"
  on_invalid:
    missing_required: "WARN, write partial metrics with _validation_errors field"
    invalid_value: "WARN, coerce to closest valid value or set null"
    never: "Do not skip metrics collection entirely due to one bad field"
```

## 1c. Phase ID Mapping

```yaml
phase_ids:
  source: "core/orchestration phase_id_normalization.metrics_mapping"
  mapping:
    0: task-analysis
    1: workspace-setup
    2: planning
    3: plan-review
    4: implementation
    5: code-review
    6: ui-review
    7: completion
  storage_type: "integer 0-7"

  normalization_table:
    # Worker phase → Metrics phase ID
    "0":     0   # task-analysis → 0
    "0.5":   1   # workspace-setup → 1
    "0.7":   1.5 # deep-analysis → 1.5 (Phase 0.7)
    "1":     2   # planner → 2
    "2":     3   # plan-review → 3
    "3":     4   # coder (implementation) → 4
    "4":     5   # code-review → 5
    "5":     6   # ui-review → 6
    "6":     7   # completion → 7
```

---

## 2. Collection

Worker collects at Phase 6 (Completion).

```yaml
collection_sources:
  - source: "docs/plans/{task-key}/checkpoint.yaml"
    fields:
      - complexity
      - route
      - iteration.plan_review
      - iteration.code_review
      - re_routed
      - re_route_detail
      - phases_completed: "length(completed_phases)"

  - source: "docs/plans/{task-key}/evaluate.md"
    fields:
      - evaluate_result

  - source: "code-review handoff payload"
    fields:
      - issues_found.blocker
      - issues_found.major
      - issues_found.minor
      - issues_found.nit

  - source: "git diff --stat main..HEAD"
    fields:
      - files_changed
      - lines_added
      - lines_removed

  - source: "checkpoint timestamps"
    fields: [duration.total_minutes, duration.per_phase]
    method: |
      For each phase transition:
        phase_start = checkpoint[N-1].timestamp (or pipeline_start for phase 0)
        phase_end = checkpoint[N].timestamp
        per_phase[phase_name] = (phase_end - phase_start) in minutes
      total_minutes = completion.timestamp - phase_0.timestamp
    fallback: "If checkpoint timestamps missing → set duration fields to null"
```

---

## 3. Storage

```yaml
storage:
  primary:
    path: "docs/plans/{task-key}/metrics.yaml"
    format: YAML
    overwrite: true

  secondary:
    condition: "MCP Memory server available"
    method: "store as entity"
    entity:
      name: "{task-key}-metrics"
      entityType: "pipeline_metrics"
      observations: "serialized metrics object"
```

---

## 4. Aggregation

```yaml
status: "Not yet implemented. Metrics files at docs/plans/*/metrics.yaml can be queried manually."
```

---

## 5. Error Handling

```yaml
error_handling:
  source_missing:
    checkpoint_yaml: "WARN, set checkpoint-derived fields to null"
    evaluate_md: "set evaluate_result to null"
    code_review_payload: "set issues_found to all zeros"
    git_diff: "WARN, try: git log --stat main..HEAD as fallback"
  source_malformed:
    action: "WARN, attempt partial parse, set unparseable fields to null"
  storage_failure:
    primary_file: "WARN, retry once. If still fails → dump metrics to stdout"
    mcp_memory: "WARN only — MCP memory is optional, skip on failure"
  rule: "Never crash Phase 7 (completion) over metrics. Metrics are best-effort."
```

---

## 6. Consumers

```yaml
consumers:
  worker_completion:
    reads: "metrics.yaml after write"
    purpose: "Display pipeline summary to user"
    display: |
      Pipeline complete: {task_key}
      Duration: {total_minutes}min | Files: {files_changed} (+{lines_added}/-{lines_removed})
      Iterations: plan {plan_review}/3, code {code_review}/3
      Issues: {blocker}B / {major}M / {minor}m

  progress_command:
    reads: "checkpoint.yaml (partial metrics derivable)"
    purpose: "Show current phase and iteration counts"

  cleanup_command:
    preserves: "metrics.yaml even when deleting other plan artifacts"
    reason: "Historical data for future complexity calibration"
```
