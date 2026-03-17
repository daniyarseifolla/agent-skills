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

  credentials:
    source: "Extracted from task description by task-source adapter (credentials field)"
    usage: "Passed to functional-tester for login workflow"
    fallback: "If no credentials in task, ask user"
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

  test_case_format: |
    Functional tests (F1-F8 style):
    - F1: Navigate to /profile → page loads, header shows username
    - F2: Click "Edit" button → edit form appears
    - F3: Clear "Name" field, submit → validation error shown
    - F4: Fill valid data, submit → success snackbar, data saved

    Visual tests (V1-V5 style):
    - V1: Profile page (desktop) → compare with Figma frame "Profile Desktop"
    - V2: Profile page (mobile 375px) → compare with Figma frame "Profile Mobile"
    - V3: Edit modal → compare with Figma frame "Edit Profile Modal"
```

---

## Dev Server Setup

```yaml
detect:
  - "Check if app is running: curl -s -o /dev/null -w '%{http_code}' http://localhost:4200"
  - "If not running, check port 6200 (community projects)"
  - "If neither running, ask user: start dev server or provide URL"
  - "Store app_url for all subsequent tests"

fallback_ports: [4200, 6200, 3000, 8080]
```

---

## 3. Parallel Testing

```yaml
parallel_agents:
  functional_tester:
    description: "Functional UI testing via agent-browser"
    model: sonnet
    run_as: "Agent(subagent)"
    skill: "agent-browser"
    setup:
      - "Navigate to app_url"
      - "If login required: use credentials from task (extracted by jira adapter)"
      - "For input fields, use nativeInputValueSetter pattern (Angular forms don't respond to .value=)"

    execution:
      - "For each test scenario in ui-test-plan.md:"
      - "  Navigate to page"
      - "  Execute actions (click, type, select)"
      - "  Verify expected result"
      - "  Take screenshot: docs/plans/{task-key}/screenshots/F{N}-{name}.png"

    tips:
      - "Use CSS selectors, not XPath"
      - "For nth element, use >>nth=0 suffix"
      - "If browser fails, close and retry once"
      - "Clipboard API workaround: document.execCommand('copy') may not work in headless"
    output:
      format: |
        | # | Scenario | Expected | Actual | Result | Screenshot |

  visual_comparator:
    description: "Visual comparison against Figma designs"
    model: sonnet
    run_as: "Agent(subagent)"
    skip_if: "no design_adapter or no figma_urls"
    steps:
      - "For each Figma URL: design_adapter.get_screenshot(url)"
      - "For each corresponding page: navigate in browser, take screenshot"
      - "Compare descriptively (not pixel-perfect):"
      - "  Layout: element positioning, alignment, grid structure"
      - "  Spacing: margins, padding, gaps between elements"
      - "  Colors: background, text, border colors (compare with design tokens)"
      - "  Typography: font size, weight, line-height"
      - "  Components: correct component used, proper variant"
      - "  States: hover, active, disabled, focus states"
      - "  Border-radius, shadows, opacity"
      - "Compare with existing pages for visual consistency"

    output_per_screen: |
      | Aspect | Figma | Actual | Match? | Notes |
      |--------|-------|--------|--------|-------|
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
