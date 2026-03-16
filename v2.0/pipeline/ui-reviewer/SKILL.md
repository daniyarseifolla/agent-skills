---
name: pipeline-ui-reviewer
description: "UI review phase: functional testing via browser agent + visual comparison against Figma designs. Runs as sonnet subagent. Called by pipeline/worker Phase 5. Also usable standalone."
model: sonnet
---

# Pipeline UI Reviewer

Phase 5. Functional testing + visual comparison. Dispatches parallel subagents.

---

## 1. Input

```yaml
input:
  branch: "feature branch"
  figma_urls: "string[] from task (via task-source adapter)"
  app_url: "local dev server URL (ask user if not known)"
  design_adapter: "for Figma screenshots and comparison"
  tech_stack_adapter: "for serve command"
  ui_inventory_path: ".claude/ui-inventory.md (optional)"
```

---

## 2. Test Planning

```yaml
test_planning:
  step_1:
    action: "Invoke Skill: brainstorming"
    input: "branch changes + figma_urls + task AC"
    output: "test scenarios"

  step_2:
    action: "Generate test plan"
    output_path: "docs/plans/{task-key}/ui-test-plan.md"
    covers:
      functional:
        - "Click interactions (buttons, links, toggles)"
        - "Input behavior (forms, validation, submission)"
        - "Navigation (routing, back/forward)"
      state:
        - "Loading state"
        - "Error state"
        - "Empty state"
        - "Populated state"
      visual:
        - "Screen-to-Figma frame mapping"
        - "Comparison points per screen"
```

---

## 3. Parallel Testing

```yaml
parallel_agents:
  functional_tester:
    description: "Functional UI testing via browser agent"
    model: sonnet
    mode: subagent
    steps:
      step_1: "Start dev server if not running (tech_stack_adapter.commands.serve)"
      step_2: "Navigate to relevant pages per test plan"
      step_3: "Execute functional test scenarios"
      step_4: "Take screenshots of each state"
      step_5: "Report pass/fail per scenario with evidence"
    output:
      format: |
        | # | Scenario | Expected | Actual | Result | Screenshot |

  visual_comparator:
    description: "Visual comparison against Figma designs"
    model: sonnet
    mode: subagent
    skip_if: "no design_adapter or no figma_urls"
    steps:
      step_1: "For each figma_url: design_adapter.get_screenshot(url)"
      step_2: "For each corresponding page: take actual screenshot"
      step_3: "Compare dimensions: layout, spacing, sizing"
      step_4: "Compare visual: colors, typography, icons"
      step_5: "Identify: missing elements, extra elements"
    output:
      format: |
        | # | Screen | Figma Frame | Match | Diff Notes |
    note: "Pixel-perfect NOT required — focus on functional/visual parity"
```

---

## 4. Component Reuse Check

```yaml
component_reuse:
  skip_if: "no ui_inventory_path"
  action: "Read ui-inventory, check if new custom components duplicate shared ones"
  method: "Compare new component selectors/names against inventory"
  severity: MINOR
  output: "List of potential duplicates with suggestions"
```

---

## 5. Output

```yaml
output:
  path: "docs/plans/{task-key}/ui-review.md"
  format: |
    ## UI Review
    ### Functional Tests
    | # | Scenario | Expected | Actual | Result | Screenshot |
    |---|----------|----------|--------|--------|------------|
    | 1 | {scenario} | {expected} | {actual} | {PASS|FAIL} | {ref} |

    ### Visual Comparison
    | # | Screen | Figma Frame | Match | Diff Notes |
    |---|--------|-------------|-------|------------|
    | 1 | {screen} | {frame} | {YES|PARTIAL|NO} | {notes} |

    ### Component Reuse
    {findings or "No duplicates found"}

    ### Verdict
    {PASS|ISSUES_FOUND}
    {details if ISSUES_FOUND}

verdict:
  PASS: "All functional tests pass, visual comparison acceptable"
  ISSUES_FOUND: "Failures in functional or visual tests"
```

---

## 6. Standalone Mode

```yaml
standalone:
  triggers:
    - "UI review"
    - "test the UI"
    - "visual review"
    - "check against Figma"

  behavior:
    step_1: "Detect current git branch"
    step_2: "Search docs/plans/ for task plan — extract figma_urls"
    step_3: "If no figma_urls found, ask user"
    step_4: "Ask user for app_url if not known"
    step_5: "Load adapters from project.yaml or autodetect"
    step_6: "Run full UI review (sections 2-5)"
    step_7: "Output ui-review.md"
```
