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
  impact_report_path: "docs/plans/{task-key}/impact-report.md (optional)"
  complexity: "S|M|L|XL"

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
    action: "Invoke Skill: qa-test-planner to generate test scenarios and detailed test cases"
    input: "branch changes + figma_urls + task AC + .claude/qa-playbook.md"
    output: "test cases grouped by type (functional, visual, edge, mobile, states)"
    on_unavailable: "WARN: qa-test-planner unavailable. Generate basic test cases from AC directly."
    note: "qa-test-planner covers both scenario identification and detailed test case generation — separate brainstorming step removed"

  step_1b:
    action: "Invoke Skill: ui-ux-pro-max for UX review checklist"
    input: "page screenshots or component list"
    output: "UX issues found (interaction states, accessibility, visual hierarchy)"
    skip_if: "no screenshots available yet"
    on_unavailable: |
      WARN: Skill ui-ux-pro-max unavailable.
      Required for: UX review checklist (interaction states, accessibility, visual hierarchy).
      Options: (1) Install skill (2) Skip step (3) Abort phase

  step_2:
    action: "Merge qa-test-planner + ui-ux-pro-max + qa-playbook into test plan"
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
      - Max 7 agents (avoid OOM)

    test_plan_format: "See templates/test-plan-template.md"

  step_2b_impact_regression:
    action: "Add regression tests from impact-report.md"
    when: "impact_report_path exists and contains must-verify items"
    method: |
      Read must-verify items from impact-report.md.
      For each item that has a UI route/page:
        - Add test case: navigate to the page, verify basic functionality still works
        - Take screenshot for evidence
      Add these as a 'Regression' test group in the test plan.
    group_name: "Impact Regression"
    note: "These test existing functionality that depends on changed code"
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
    max_agents: 7
    note: "Per Iron Law #5 from core-orchestration"
    on_unavailable_agent_browser: |
      WARN: Skill agent-browser unavailable.
      Required for: functional UI testing via browser automation.
      Options: (1) Install skill (2) Skip step (3) Abort phase
    on_unavailable_dispatching_parallel_agents: |
      WARN: Skill superpowers:dispatching-parallel-agents unavailable.
      Required for: parallel agent dispatch for test groups.
      Options: (1) Install skill (2) Skip step — run agents sequentially (3) Abort phase

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
    on_unavailable: |
      WARN: Skill visual-qa unavailable.
      Required for: post-implementation screenshot QA (visual rhythm, alignment, responsive, polish).
      Options: (1) Install skill (2) Skip step (3) Abort phase
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

## 3c. Agent Budgets

```yaml
budgets:
  per_qa_agent:
    max_tool_calls: 80
    timeout_minutes: 15
    on_timeout: "Stop agent, collect partial results, mark as INCOMPLETE"

  planning_skills:
    brainstorming: "max 5 minutes"
    qa_test_planner: "max 10 minutes"
    ui_ux_pro_max: "max 10 minutes"

  total_phase:
    max_minutes: 60
    on_exceeded: "Stop remaining agents, aggregate what exists, report partial results"

  on_agent_failure:
    action: "Log failure, continue with other agents, include failure in report"
    never: "Do not retry failed agent — time budget does not allow"
```

---

## 3b. Missing States Audit

```yaml
missing_states_audit:
  CRITICAL: |
    For EVERY interactive component on the page, check if ALL required states are implemented.
    This catches the #2 most common issue: components with only default state.

  required_states: "See templates/required-states.yaml"

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
    {verdict} — Score: {score}/10
    Breakdown: functional={functional_pct}%, visual={visual_pct}%, states={states_pct}%
    {blockers if any}

verdict:
  scoring:
    functional: "PASS count / total tests → percentage"
    visual: "matching elements / total elements → percentage"
    states: "implemented states / required states → percentage"
    overall: "weighted average (functional: 0.5, visual: 0.3, states: 0.2)"
  thresholds:
    PASS: "overall >= 90% AND zero MAJOR functional failures"
    PASS_WITH_ISSUES: "overall >= 70% OR only MINOR visual mismatches"
    ISSUES_FOUND: "overall < 70% OR any MAJOR functional failure"
  output_fields:
    verdict: "PASS | PASS_WITH_ISSUES | ISSUES_FOUND"
    score: "1-10 (aligned with consensus-review standard)"
    breakdown: "{ functional_pct, visual_pct, states_pct }"
    blockers: "list of MAJOR issues"
```

---

## 6. Consensus Mode (3 sections x 3 agents = 9 total)

Activated when `complexity >= M`. Full 3x3 consensus. Replaces default test-group dispatch.
Sections sequential (Iron Law #5), agents parallel within section.

```yaml
consensus_mode:
  activation: "complexity >= M"
  note: "This REPLACES the default test-group-parallel dispatch (Section 3). Not additive."
  dispatch: "Use Skill: superpowers:dispatching-parallel-agents per section"
  sections: 3
  agents_per_section: 3
  sequential_sections: true

  section_1_functional:
    name: "Functional Testing"
    agents:
      - angle: "Happy path — main user flows work as expected (CRUD, navigation, forms)"
        tools: [agent-browser, browser_click, browser_fill, browser_navigate]
      - angle: "Edge cases — empty states, long text, special chars, network errors, validation"
        tools: [agent-browser, browser_click, browser_fill]
      - angle: "Data persistence — create → refresh → verify, edit → verify, delete → verify gone"
        tools: [agent-browser, browser_navigate, browser_evaluate]
    output: ".tmp/ui-functional.md"
    budget_per_agent: "max 80 tool calls, 15 min"

  section_2_visual:
    name: "Visual Fidelity"
    skip_if: "no design adapter or no figma_urls"
    agents:
      - angle: "Per-element Figma comparison — CSS properties exact match (getComputedStyle vs Figma)"
        tools: [get_design_context, browser_evaluate, browser_navigate]
      - angle: "Overall visual quality — hierarchy, spacing rhythm, consistency, color palette"
        tools: [get_screenshot, browser_take_screenshot, browser_resize]
      - angle: "Responsive — screenshot at 375, 768, 1024, 1440. Overflow, broken layouts, hidden content"
        tools: [browser_resize, browser_take_screenshot]
    output: ".tmp/ui-visual.md"
    budget_per_agent: "max 80 tool calls, 15 min"

  section_3_states:
    name: "States & Accessibility"
    agents:
      - angle: "Component states — hover, focus-visible, disabled, loading, error for every interactive element"
        tools: [browser_hover, browser_press_key, browser_take_screenshot]
      - angle: "Accessibility — contrast ratio, focus order, aria-labels, keyboard navigation, screen reader"
        tools: [browser_evaluate, browser_press_key, browser_snapshot]
      - angle: "Transitions & micro-interactions — animations smooth (no jank), timing appropriate, no flash"
        tools: [browser_hover, browser_click, browser_take_screenshot]
    output: ".tmp/ui-states.md"
    budget_per_agent: "max 80 tool calls, 15 min"

  aggregation:
    per_section:
      consensus: "2+ agents agree → confirmed"
      conflicts: "agents disagree → flag"
      score: "Average of 3 agents → 1-10"
    cross_section:
      scoring:
        functional: "section_1 score"
        visual: "section_2 score"
        states: "section_3 score"
      states: "implemented states / required → 1-10"
      overall: "weighted average (functional 0.5, visual 0.3, states 0.2)"
    verdict: "PASS (≥8.5) | PASS_WITH_ISSUES (7.0-8.4) | ISSUES_FOUND (<7.0)"
    output: "ui-review.md (merged from 3 agents)"
    cleanup: "rm .tmp/ui-*.md"
```

---

## 6b. S-Complexity Mode

When `complexity == S`. Functional testing only, no consensus.

```yaml
s_complexity_mode:
  activation: "complexity == S"
  dispatch: "Single agent — functional testing only"
  skip: "Per-element Figma comparison (visual fidelity section)"
  keep: "Functional testing, impact regression, missing states audit"
  consensus: "None — single pass"
  budget: "max 80 tool calls, 15 min"
  note: "Lighter than M+ but still catches functional regressions and broken states"
```

---

## 7. Standalone Mode

```yaml
standalone:
  triggers:
    - "UI review"
    - "test the UI"
    - "visual review"
    - "check against Figma"

  behavior:
    step_1: "Detect current git branch"
      command: "git branch --show-current"
      if_empty_detached_head:
        - "git log --oneline -5 | grep -oE '[A-Z]+-[0-9]+' | head -1"
        - "If found → use as task_key"
        - "If not found → ask user for branch name or task key"
    step_2: "Search docs/plans/ for task plan — extract figma_urls"
    step_3: "If no figma_urls found, ask user"
    step_4: "Ask user for app_url if not known"
    step_5: "Load adapters from project.yaml or autodetect"
    step_6: "Run full UI review (sections 2-5)"
    step_7: "Output ui-review.md"
    output_path:
      primary: "docs/plans/{task-key}/ui-review.md"
      fallback: "docs/plans/standalone-{branch-name}/ui-review.md"
      last_resort: "./ui-review.md (current directory)"

  degraded_modes:
    no_figma: "Skip visual comparison, run functional-only tests"
    no_browser_agent: "WARN: agent-browser unavailable. Skip functional testing, run visual-only from Figma comparison"
    no_qa_playbook: "Generate basic test cases from git diff + AC only"
    no_dev_server: "Ask user to start dev server. If not possible → abort UI review with instructions"
```
