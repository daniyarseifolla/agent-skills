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
    action: "Invoke Skill: brainstorming to identify WHAT to test"
    input: "branch changes + figma_urls + task AC"
    output: "test scenarios and focus areas"

  step_1b:
    action: "Invoke Skill: qa-test-planner to generate DETAILED test cases from scenarios"
    input: "brainstorming scenarios + .claude/qa-playbook.md + figma_urls"
    output: "test cases grouped by type (functional, visual, edge, mobile, states)"
    note: "qa-test-planner generates manual test cases, regression suites, and bug scenarios"

  step_1c:
    action: "Invoke Skill: ui-ux-pro-max for UX review checklist"
    input: "page screenshots or component list"
    output: "UX issues found (interaction states, accessibility, visual hierarchy)"
    skip_if: "no screenshots available yet"

  step_2:
    action: "Merge brainstorming + qa-test-planner + ui-ux-pro-max + qa-playbook into test plan"
    inputs:
      - "AC from task (via task-source adapter)"
      - ".claude/qa-playbook.md (if exists) → credentials, edge cases, fragile areas"
      - ".claude/project-practices.md (if exists) → known bugs, patterns"
      - "Figma Node Map from plan (if exists)"
    output_path: "docs/plans/{task-key}/ui-test-plan.md"

    CRITICAL: |
      Test cases are generated from AC + project context, NOT from a fixed list.
      Use Skill: qa-test-planner to generate comprehensive test scenarios.
      Group test cases into PARALLEL AGENT GROUPS — each group runs as a separate agent.

    grouping_strategy: |
      Group test cases by independence (tests that don't share state):
      - Group by page/feature (tests on /search are independent from /profile)
      - Group by test type (functional vs visual vs edge cases)
      - Each group = one parallel agent
      - Max 10 agents (avoid OOM)

    test_plan_format: |
      ## Test Plan: {task-key}

      ### Agent Groups
      | # | Agent Name | Test Cases | Type |
      |---|-----------|-----------|------|
      | 1 | QA: Search functional | F1-F4 | functional |
      | 2 | QA: Search visual | V1-V2 | visual (Figma) |
      | 3 | QA: Search edge cases | E1-E3 | edge cases |
      | 4 | QA: Mobile responsive | M1-M2 | responsive |

      ### Test Cases
      Functional (F1-F8 style):
      - F1: Navigate to /search → page loads, search input visible
      - F2: Type "test" → results update, playlists filtered
      - F3: Clear search → all results shown

      Visual (V1-V5 style):
      - V1: Search page (desktop) → compare with Figma frame
      - V2: Search results card → per-element Figma check

      Edge Cases (E1-E5 style, from qa-playbook):
      - E1: Search with cyrillic "тест" → results correct
      - E2: Search with empty string → no crash
      - E3: Search with 500+ chars → graceful handling

      Mobile (M1-M3 style):
      - M1: Search page at 375px → responsive layout
      - M2: Search page at 768px → tablet layout
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
  CRITICAL: |
    Dispatch N agents IN PARALLEL — one per Agent Group from test plan.
    Use Skill: superpowers:dispatching-parallel-agents for parallel launch.
    Each agent gets: group name, test cases, credentials, app_url.

  dispatch:
    for_each: "Agent Group in ui-test-plan.md"
    launch: "Agent(subagent, model: sonnet)"
    skill: "agent-browser"
    parallel: true
    max_agents: 10

  per_agent_prompt: |
    You are QA agent "{group_name}".
    App URL: {app_url}
    Credentials: {from qa-playbook or task}

    Your test cases:
    {test_cases_for_this_group}

    For each test case:
    1. agent-browser open {url}
    2. agent-browser snapshot -i
    3. Execute test steps (click, fill, verify)
    4. Take screenshot: docs/plans/{task-key}/screenshots/{test_id}.png
    5. Record: PASS / FAIL with details

    Auth: use nativeInputValueSetter for Angular form inputs.
    Report format:
    | Test ID | Description | Result | Screenshot | Notes |

  functional_agent:
    description: "Functional UI testing via agent-browser"
    test_types: [functional, edge_cases]
    setup:
      - "Navigate to app_url"
      - "If login required: use credentials from qa-playbook or task"
      - "For input fields, use nativeInputValueSetter pattern (Angular forms)"

    execution:
      - "For each test case in this group:"
      - "  Navigate to page"
      - "  Execute actions (click, type, select)"
      - "  Verify expected result"
      - "  Take screenshot: docs/plans/{task-key}/screenshots/{test_id}.png"

    tips:
      - "Use CSS selectors, not XPath"
      - "For nth element, use >>nth=0 suffix"
      - "If browser fails, close and retry once"
      - "Clipboard API workaround: document.execCommand('copy') may not work in headless"
    output:
      format: |
        | # | Scenario | Expected | Actual | Result | Screenshot |

  visual_comparator:
    description: "Per-element visual verification against Figma"
    model: sonnet
    run_as: "Agent(subagent)"
    skip_if: "no design_adapter or no figma_urls"

    CRITICAL_RULE: |
      Do NOT just compare screenshots side-by-side.
      For EACH UI element in the Figma Node Map (from plan):
      1. Call get_design_context(fileKey, nodeId) for the specific element
      2. Extract exact CSS values from Figma code hints
      3. Inspect the actual CSS in browser (via agent-browser DevTools or computed styles)
      4. Compare EACH property: size, color, font, spacing, border-radius, shadow
      5. Report exact mismatches with Figma value vs Actual value

    workflow:
      step_1: "Read plan → find Figma Node Map table"
      step_2: "For each node in the map:"
      step_2a: "  Call get_design_context(fileKey, nodeId) → extract expected CSS"
      step_2b: "  In browser: inspect the corresponding element → get actual CSS"
      step_2c: "  Compare property by property"
      step_2d: "  Record: element, property, figma_value, actual_value, match?"
      step_3: "Take full-page screenshots for overall layout comparison"
      step_4: "Compare with existing pages for visual consistency"

    per_element_check:
      properties:
        layout: "display, flex-direction, justify-content, align-items, gap"
        sizing: "width, height, padding, margin"
        typography: "font-family, font-size, font-weight, line-height, letter-spacing, color"
        visual: "background-color, border, border-radius, box-shadow, opacity"

      tolerance:
        size: "±2px"
        color: "exact match (after mapping to project variables)"
        font_size: "±1px"
        spacing: "±2px"
        border_radius: "exact match"
        tolerance_rationale: |
          Render tolerance (±2px): browser rendering introduces sub-pixel differences
          from font rendering engines, box model calculations, and viewport-dependent layout.
          This is looser than the coder's author tolerance (±0px) by design.
          The coder writes exact values; the reviewer checks rendered output.

    output_per_element: |
      | Element | Property | Figma | Actual | Match? |
      |---------|----------|-------|--------|--------|
      | Card | width | 290px | 290px | YES |
      | Card | border-radius | 12px | 8px | NO — fix to 12px |
      | Title | font-size | 16px | 14px | NO — fix to 16px |
      | Title | color | #1A1A1A | #333333 | NO — use $text-primary |

    output_per_screen: |
      | # | Screen | Figma Frame | Elements Checked | Matches | Mismatches |

    severity:
      color_mismatch: MAJOR
      size_mismatch_gt_4px: MAJOR
      size_mismatch_2_4px: MINOR
      font_mismatch: MAJOR
      border_radius_mismatch: MINOR
      spacing_mismatch_gt_4px: MAJOR
      spacing_mismatch_2_4px: MINOR

  screenshot_qa:
    description: "Post-implementation screenshot QA using visual-qa skill"
    skill: "visual-qa"
    when: "After per-element Figma comparison is done"
    purpose: "Catch issues that per-element check misses: overall visual rhythm, alignment across elements, responsive problems, polish details"
    workflow:
      - "Take full-page screenshot of implemented page"
      - "Invoke Skill: visual-qa with screenshot + Figma screenshot as reference"
      - "visual-qa checks 7 categories: layout/spacing, typography, color/contrast, visual hierarchy, component quality, polish/micro-details, responsive"
      - "Merge visual-qa findings into ui-review.md"
    adds_to_review:
      - "Overall visual rhythm and spacing consistency"
      - "Alignment issues across unrelated elements"
      - "Typography scale consistency"
      - "Color palette coherence"
      - "Micro-details: shadows, borders, hover states"
```

---

## 3b. Missing States Audit

```yaml
missing_states_audit:
  CRITICAL: |
    For EVERY interactive component on the page, check if ALL required states are implemented.
    This catches the #2 most common issue: components with only default state.

  required_states:
    button: [default, hover, active, focus-visible, disabled, loading]
    input: [default, hover, focus, filled, error, disabled]
    link: [default, hover, active, focus-visible, visited]
    dropdown: [closed, open, item-hover, item-selected, disabled]
    card: [default, hover, selected (if selectable)]
    modal: [opening-animation, open, closing-animation]
    checkbox: [unchecked, checked, indeterminate, disabled]
    toggle: [off, on, disabled]

  workflow:
    step_1: "List all interactive components on the page"
    step_2: "For each component, check Figma for state frames"
    step_3: "For each component, check code for state CSS (:hover, :focus-visible, :disabled, .loading, etc.)"
    step_4: "Report missing states"

  output: |
    | Component | State | Figma | Code | Status |
    |-----------|-------|-------|------|--------|
    | Save button | hover | YES | YES | OK |
    | Save button | loading | NO | NO | MISSING — add spinner |
    | Search input | error | YES | NO | MISSING — add error style |

  severity:
    no_hover: MAJOR
    no_focus_visible: MAJOR
    no_disabled: MINOR
    no_loading: MAJOR (if async)
    no_error: MAJOR (if validates)
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
