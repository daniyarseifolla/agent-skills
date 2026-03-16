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
  timestamp: "ISO-8601"
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
      - phases_completed: phase_completed

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

## 4. Aggregation (Future)

Query interface for stored metrics across tasks.

```yaml
aggregation:
  source: "docs/plans/**/metrics.yaml"
  computations:
    - name: avg_iterations_by_complexity
      group_by: complexity
      aggregate: "mean(iterations.plan_review + iterations.code_review)"
    - name: common_issue_types
      aggregate: "sum(issues_found.*), rank by count"
    - name: re_route_frequency
      aggregate: "count(re_routed == true) / total_tasks"
    - name: evaluate_return_rate
      aggregate: "count(evaluate_result == RETURN) / total_tasks"
```
