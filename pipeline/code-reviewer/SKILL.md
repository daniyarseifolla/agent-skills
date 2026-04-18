---
name: pipeline-code-reviewer
description: "Code review phase: reviews diff against plan, architecture, security, and quality. Runs as sonnet subagent with worktree isolation. Called by pipeline/worker Phase 8: review. Also usable standalone."
model: sonnet
---

# Pipeline Code Reviewer

Phase 8: review. Architecture + security + quality review. Runs in worktree for isolation.

---

## 1. Input

Per core-orchestration coder_to_reviewer contract.

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

---

## 2. Pre-checks

Blocking gates before review begins.

```yaml
pre_checks:
  lint:
    command: "tech_stack_adapter.commands.lint"
    on_fail: "Return CHANGES_REQUESTED immediately — coder must fix"
  test:
    command: "tech_stack_adapter.commands.test"
    on_fail: "Return CHANGES_REQUESTED immediately — coder must fix"
```

---

## 3. Review Areas

```yaml
review:
  plan_compliance:
    description: "Implementation matches approved plan"
    method: "Compare plan parts vs actual file changes (git diff)"
    deviations: "Check if documented in evaluate.md"
    severity:
      undocumented_deviation: MAJOR
      documented_deviation: "acceptable"

  architecture:
    description: "Code follows project architecture patterns"
    method: "Run tech_stack_adapter quality_checks against changed files"
    severity: MAJOR

  security:
    description: "No security vulnerabilities introduced"
    method: "Load core-security, run all grep patterns against changed files"
    severity: "Per core-security classification (BLOCKER or MAJOR)"

  component_reuse:
    description: "No reinvented components"
    method: "Read .claude/ui-inventory.md, flag duplicates in new code"
    severity: MINOR
    skip_if: "no ui-inventory file"

  error_handling:
    description: "Proper error handling patterns"
    checks:
      - "No swallowed errors (empty catch blocks)"
      - "No console.log of sensitive data"
      - "Error boundaries where appropriate"
      - "User-facing errors are translated/friendly"
    severity: MAJOR

  memory_leaks:
    description: "No subscription leaks, timer leaks, or event listener leaks"
    check: "tech-stack adapter memory_leak_checks patterns"
    severity: MAJOR

  design_implementation:
    description: "UI matches Figma design with high fidelity"
    check: "If plan references Figma URLs, verify figma:implement-design skill was used"
    skip_if: "no design adapter or no Figma URLs in plan"
    severity: MAJOR

  test_coverage:
    description: "New code has corresponding tests"
    method: "Every new .ts file should have .spec.ts (per tech_stack_adapter conventions)"
    severity: MAJOR
    exceptions: ["models", "interfaces", "types", "constants", "index files"]

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

---

## 4. Severity & Decision

```yaml
severity:
  BLOCKER: "Security vulnerability, data loss risk — blocks approval"
  MAJOR: "Error handling, missing tests, undocumented deviations, architecture violation — blocks approval"
  MINOR: "Style, naming, docs, minor patterns — does not block"
  NIT: "Preference, cosmetic — does not block"

auto_escalation:
  - condition: "5+ MINOR in same file"
    action: "Escalate to MAJOR for that file"
  - condition: "Any core-security finding"
    action: "Always BLOCKER regardless of pattern severity"

decision:
  APPROVED:
    condition: "0 BLOCKER, 0 MAJOR"
  APPROVED_WITH_COMMENTS:
    condition: "0 BLOCKER, 0 MAJOR, has MINOR/NIT"
  CHANGES_REQUESTED:
    condition: "1+ BLOCKER or 1+ MAJOR or 3+ MINOR"
```

---

## 5. Output

```yaml
output:
  path: "docs/plans/{task-key}/code-review.md"
  format: |
    ## Code Review — {verdict}
    ### Iteration
    {N}/3
    ### Pre-checks
    - Lint: {PASS|FAIL}
    - Test: {PASS|FAIL}
    ### Findings
    | # | File | Line | Severity | Issue | Suggestion |
    |---|------|------|----------|-------|------------|
    | 1 | {file} | {line} | {severity} | {issue} | {suggestion} |
    ### Summary
    BLOCKER: {n}, MAJOR: {n}, MINOR: {n}, NIT: {n}
    ### Verdict
    {APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED}
```

---

## Severity Triage (for worker)

When code-reviewer returns CHANGES_REQUESTED, worker should triage:

| Severity | Worker Action |
|----------|--------------|
| BLOCKER | Return to coder — must fix before proceeding |
| MAJOR | Return to coder — must fix |
| MINOR (1-2) | Show to user, ask: fix now or proceed? |
| MINOR (3+) | Return to coder (auto-escalated) |
| NIT | Show for awareness, proceed |

---

## 6. Handoff

Per core-orchestration reviewer_to_completion contract.

```yaml
handoff:
  payload:
    verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
    comments: "non-blocking notes (MINOR/NIT)"
    issues: "blocking findings (if CHANGES_REQUESTED)"
    iteration: "N/3"
  validation: "All required fields per core-orchestration contract"
```

---

## 7. Loop Behavior

```yaml
loop:
  max: 3
  guard: "core-orchestration loop_limits"
  per_iteration:
    - "Receive updated code from coder"
    - "Re-run pre-checks"
    - "Re-run full review"
    - "Verify previous issues resolved"
    - "Report new findings if any"
  on_exceeded: "STOP, show iteration summary, request user intervention"
```

---

## 8. Consensus Mode (3 sections x 3 agents = 9 total)

Activated when `complexity >= M`. Full 3x3 consensus. Sections sequential, agents parallel.

```yaml
consensus_mode:
  activation: "complexity >= M"
  dispatch: "Use Skill: superpowers:dispatching-parallel-agents per section"
  sections: 3
  agents_per_section: 3
  sequential_sections: true

  section_1_correctness:
    name: "Correctness & Logic"
    agents:
      - angle: "Bug hunter — logic errors, edge cases, off-by-one, null handling"
        focus: [error_handling]
      - angle: "Plan compliance — compare implementation vs plan, find deviations, check evaluate.md"
        focus: [plan_compliance, test_coverage]
      - angle: "Type safety — any casts, unsafe assertions, missing generics, race conditions"
        focus: [error_handling, memory_leaks]

  section_2_architecture:
    name: "Architecture & Patterns"
    agents:
      - angle: "Clean architecture — separation of concerns, dependency direction, SRP"
        focus: [architecture]
      - angle: "Project patterns — follows existing patterns in codebase, correct imports, module boundaries"
        focus: [architecture, component_reuse]
      - angle: "Security — core-security grep patterns (grep -P), tech_stack_adapter.security_checks"
        focus: [security, design_implementation]

  section_3_quality:
    name: "Code Quality & UX"
    agents:
      - angle: "Readability — naming, complexity, magic numbers, dead code"
        focus: [plan_compliance]
      - angle: "Performance — N+1, unnecessary re-renders, memory leaks, subscription leaks"
        focus: [memory_leaks]
      - angle: "Component quality — reuse, states, accessibility, Figma fidelity"
        focus: [component_reuse, design_implementation]

  aggregation:
    per_section:
      consensus: "2+ agents agree → confirmed"
      conflicts: "disagree on severity → escalate to higher"
      score: "Average of 3 agents"
    cross_section:
      verdict: "Worst verdict across 3 sections"
      output: "code-review.md grouped by section with consensus/unique findings"
```

---

## 8b. S-Complexity Mode

When `complexity == S`. Single-agent review, no consensus.

```yaml
s_complexity_mode:
  activation: "complexity == S"
  dispatch: "Inline — single agent, no subagent dispatch"
  review_areas: "All areas from Section 3 (same checklist, same severity rules)"
  consensus: "None — single pass"
  note: "Same rigor, less parallelism. Every review area still applies."

  CRITICAL_S_ENFORCEMENT: |
    S-complexity does NOT mean reduced verification. It means fewer reviewers.
    Pre-checks (lint + test) are BLOCKING gates for S — same as M/L/XL.
    test_coverage check is MAJOR for S — same as M/L/XL.
    If coder skipped lint/test (verification_gate not passed) → CHANGES_REQUESTED immediately.
    Do NOT rationalize: "it's a small change, tests aren't critical" — run them.
```

---

## 9. Standalone Mode

```yaml
standalone:
  triggers:
    - "code review"
    - "review my code"
    - "review this branch"

  behavior:
    step_1: "Detect current git branch"
      command: "git branch --show-current"
      if_empty_detached_head:
        - "git log --oneline -5 | grep -oE '[A-Z]+-[0-9]+' | head -1"
        - "If found → use as task_key"
        - "If not found → ask user for branch name or task key"
    step_2: "Search docs/plans/ for plan matching branch or task key"
    step_3_plan_found: "Run full review including plan compliance"
    step_3_no_plan: "Run review without plan compliance (diff-only mode)"
    step_4: "Load tech_stack_adapter from project.yaml or autodetect"
    step_5: "Load core-security"
    step_6: "Execute review areas (section 3), skip plan_compliance if no plan"
    step_7: "Output code-review.md"
    output_path:
      primary: "docs/plans/{task-key}/code-review.md"
      fallback: "docs/plans/standalone-{branch-name}/code-review.md"
      last_resort: "./code-review.md (current directory)"
```
