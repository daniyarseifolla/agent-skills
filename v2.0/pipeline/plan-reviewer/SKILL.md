---
name: pipeline-plan-reviewer
description: "Plan review phase: validates plan against AC, architecture patterns, and completeness. Runs as sonnet subagent for objectivity. Called by pipeline/worker Phase 2."
model: sonnet
---

# Pipeline Plan Reviewer

Phase 2. Validates plan quality and completeness. Runs as subagent for objectivity.

---

## 1. Input

Per core-orchestration planner_to_reviewer contract.

```yaml
input:
  artifact_path: string          # path to plan.md
  key_decisions: string[]        # architecture choices from planner
  known_risks: string[]          # identified risks
  complexity: "S|M|L|XL"
  tech_stack_adapter: "for architecture pattern validation"
  design_adapter: "optional — for Figma coverage check"
```

---

## 2. Review Checklist

```yaml
checks:
  ac_coverage:
    description: "Every AC maps to at least one implementation part"
    method: "Parse AC Mapping table in plan"
    severity: BLOCKER
    fail_if: "Any AC has no mapped part"

  architecture_alignment:
    description: "Plan follows project architecture patterns"
    method: "tech_stack_adapter quality_checks + component_pattern"
    severity: MAJOR
    examples:
      - "Standalone components (Angular)"
      - "Correct module boundaries"
      - "Proper dependency direction"

  scope_completeness:
    description: "All files to create/modify are listed"
    method: "Cross-reference parts with scope section"
    severity: MAJOR
    fail_if: "Part references file not in scope"

  dependency_order:
    description: "Parts ordered by dependency — no circular deps"
    method: "Check part dependencies form a DAG"
    severity: MAJOR

  test_plan:
    description: "Test plan exists and covers key scenarios"
    method: "Verify test section non-empty, covers AC"
    severity: MAJOR

  risk_assessment:
    description: "Known risks have mitigation strategies"
    method: "Each risk in known_risks addressed in plan"
    severity: MINOR

  required_sections:
    description: "Plan has all required sections"
    sections: [Context, Scope, Architecture, Parts, "AC Mapping", Tests]
    severity: MAJOR

  figma_coverage:
    description: "Visual components from design URLs are covered"
    method: "design_adapter present → check component coverage"
    severity: MAJOR
    skip_if: "no design adapter or no figma_urls in task"

  config_changes:
    description: "Routing, module, environment changes documented"
    method: "If parts touch config files, config section must exist"
    severity: MINOR
```

---

## 3. Verdict Logic

```yaml
verdict:
  APPROVED:
    condition: "0 BLOCKER, 0 MAJOR"
    action: "Pass to coder with approved_notes"

  NEEDS_CHANGES:
    condition: "1+ BLOCKER or 1+ MAJOR"
    action: "Return to planner with issues list"

  REJECTED:
    condition: "Fundamental approach is wrong"
    action: "Return to planner with rejection rationale"
    note: "Rare — means complete re-plan needed"

decision_matrix:
  0_blocker_0_major: APPROVED
  0_blocker_1plus_major: NEEDS_CHANGES
  1plus_blocker: NEEDS_CHANGES
  fundamental_flaw: REJECTED
```

---

## 4. Output

```yaml
output:
  path: "docs/plans/{task-key}/plan-review.md"
  format: |
    ## Plan Review — {verdict}
    ### Iteration
    {N}/3
    ### Findings
    | # | Area | Severity | Issue | Suggestion |
    |---|------|----------|-------|------------|
    | 1 | {area} | {severity} | {issue} | {suggestion} |
    ### Summary
    BLOCKER: {n}, MAJOR: {n}, MINOR: {n}
    ### Verdict
    {APPROVED|NEEDS_CHANGES|REJECTED}
    {rationale}
```

---

## 5. Handoff

Per core-orchestration reviewer_to_coder contract.

```yaml
handoff:
  payload:
    verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
    approved_notes: "non-blocking suggestions (if APPROVED)"
    issues: "list of findings with severity (if NEEDS_CHANGES/REJECTED)"
    iteration: "N/3"
  validation: "All required fields per core-orchestration contract"
```

---

## 6. Loop Behavior

```yaml
loop:
  max: 3
  guard: "core-orchestration loop_limits"
  per_iteration:
    - "Receive updated plan from planner"
    - "Re-run full checklist"
    - "Verify previous issues resolved"
    - "Report new findings if any"
  on_exceeded: "STOP, show iteration summary, request user intervention"
```
