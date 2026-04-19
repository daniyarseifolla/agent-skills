---
name: pipeline-ui-reviewer
description: "Use when testing UI in browser and comparing against Figma designs. Called by worker Phase 8: review."
human_description: "Тестирует UI в браузере: функциональное тестирование + визуальное сравнение с Figma. Для M+ — consensus."
model: sonnet
---

# Pipeline UI Reviewer

Phase 8: review (parallel). Functional testing + visual comparison. Dispatches parallel subagents.

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

  credentials: "From task-source adapter credentials field; fallback: ask user"
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

  step_1b:
    action: "Invoke Skill: ui-ux-pro-max for UX review checklist"
    input: "page screenshots or component list"
    output: "UX issues found (interaction states, accessibility, visual hierarchy)"
    skip_if: "no screenshots available yet"
    on_unavailable: "WARN: ui-ux-pro-max unavailable → (1) Install (2) Skip (3) Abort"

  step_2:
    action: "Merge qa-test-planner + ui-ux-pro-max + qa-playbook into test plan"
    inputs:
      - "AC from task (via task-source adapter)"
      - ".claude/qa-playbook.md (if exists) → credentials, edge cases, fragile areas"
      - ".claude/project-practices.md (if exists) → known bugs, patterns"
      - "Figma Node Map from plan (if exists)"
    output_path: "docs/plans/{task-key}/ui-test-plan.md"

    CRITICAL: "Test cases from AC + project context, NOT a fixed list. Group into PARALLEL AGENT GROUPS."
    grouping_strategy: "Group by independence (no shared state): by page/feature or test type. Max 7 agents."

    test_plan_format: "See templates/test-plan-template.md"

  step_2b_impact_regression:
    action: "Add regression tests from impact-report.md"
    when: "impact_report_path exists and contains must-verify items"
    method: "For each must-verify item with a UI route: add test case (navigate + verify + screenshot) to 'Regression' group"
    group_name: "Impact Regression"
```

---

## Dev Server Setup

```yaml
detect: "curl localhost ports [4200, 6200, 3000, 8080] → if none running, ask user"
```

---

## 3. Parallel Testing

```yaml
parallel_agents:
  CRITICAL: "Dispatch N agents IN PARALLEL via Skill: superpowers:dispatching-parallel-agents. Each agent gets: group name, test cases, credentials, app_url."

  dispatch:
    for_each: "Agent Group in ui-test-plan.md"
    launch: "Agent(subagent, model: sonnet)"
    skill: "agent-browser"
    parallel: true
    max_agents: 7
    note: "Per Iron Law #5 from core-orchestration"
    on_unavailable_agent_browser: "WARN: agent-browser unavailable → (1) Install (2) Skip (3) Abort"
    on_unavailable_dispatching_parallel_agents: "WARN: dispatching-parallel-agents unavailable → (1) Install (2) Skip (run sequentially) (3) Abort"

  functional_agent:
    description: "Functional UI testing via agent-browser"
    test_types: [functional, edge_cases]
    workflow:
      - "Navigate to app_url; login if needed (credentials from qa-playbook or task)"
      - "For each test case: navigate → execute actions → verify expected result"
      - "Take screenshot: docs/plans/{task-key}/screenshots/{test_id}.png"
      - "Use nativeInputValueSetter for Angular form inputs"
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
      1. Read plan → find Figma Node Map table
      2. Call get_design_context(fileKey, nodeId) → extract expected CSS
      3. In browser: inspect the corresponding element → get actual CSS (getComputedStyle)
      4. Compare EACH property: size, color, font, spacing, border-radius, shadow
      5. Record: element, property, figma_value, actual_value, match?
      6. Take full-page screenshots for overall layout comparison
      7. Compare with existing pages for visual consistency

    per_element_check:
      properties: "layout (display, flex, gap) | sizing (width, height, padding, margin) | typography (font-*, line-height, color) | visual (background, border, border-radius, box-shadow, opacity)"
      tolerance:
        size: "±2px"
        color: "exact match (after mapping to project variables)"
        font_size: "±1px"
        spacing: "±2px"
        border_radius: "exact match"

    output: |
      Per element: | Element | Property | Figma | Actual | Match? |
      Per screen:  | # | Screen | Figma Frame | Elements Checked | Matches | Mismatches |

    severity:
      color_mismatch: MAJOR
      size_mismatch_gt_4px: MAJOR
      size_mismatch_2_4px: MINOR
      font_mismatch: MAJOR
      border_radius_mismatch: MINOR
      spacing_mismatch_gt_4px: MAJOR
      spacing_mismatch_2_4px: MINOR

  screenshot_qa:
    skill: "visual-qa"
    when: "After per-element Figma comparison"
    on_unavailable: "WARN: visual-qa unavailable → (1) Install (2) Skip (3) Abort"
    workflow:
      - "Take full-page screenshot → invoke visual-qa with screenshot + Figma reference"
      - "Checks: layout/spacing, typography, color/contrast, visual hierarchy, component quality, polish, responsive"
      - "Merge findings into ui-review.md"
```

---

## 3c. Agent Budgets

```yaml
budgets:
  per_qa_agent: "max 80 tool calls, 15 min timeout → on timeout: collect partial, mark INCOMPLETE"
  planning_skills: "brainstorming 5 min, qa-test-planner 10 min, ui-ux-pro-max 10 min"
  total_phase: "60 min → on exceeded: stop remaining, aggregate partial results"
  on_agent_failure: "Log, continue with others, include in report. Never retry."
```

---

## 3b. Missing States Audit

```yaml
missing_states_audit:
  CRITICAL: |
    For EVERY interactive component on the page, check if ALL required states are implemented.
    This catches the #2 most common issue: components with only default state.

  required_states: "See templates/required-states.yaml"

  workflow: "List interactive components → check Figma for state frames → check code for state CSS → report missing"

  output: |
    | Component | State | Figma | Code | Status |

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
  scoring: "weighted average (functional 0.5, visual 0.3, states 0.2)"
  thresholds:
    PASS: ">=90% AND zero MAJOR functional failures"
    PASS_WITH_ISSUES: ">=70% OR only MINOR visual mismatches"
    ISSUES_FOUND: "<70% OR any MAJOR functional failure"
  output: "verdict (PASS|PASS_WITH_ISSUES|ISSUES_FOUND), score 1-10, breakdown {functional_pct, visual_pct, states_pct}, blockers"
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
  budget_per_agent: "max 80 tool calls, 15 min"

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

  aggregation:
    per_section: "2+ agents agree → confirmed; disagree → flag; score = avg of 3 → 1-10"
    overall: "weighted average (functional 0.5, visual 0.3, states 0.2)"
    verdict: "PASS (>=8.5) | PASS_WITH_ISSUES (7.0-8.4) | ISSUES_FOUND (<7.0)"
    output: "ui-review.md (merged from 3 sections)"
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
    step_1: "Detect branch: git branch --show-current (detached HEAD → extract task key from git log)"
    step_2: "Search docs/plans/ for task plan → extract figma_urls (ask user if missing)"
    step_3: "Ask user for app_url if not known"
    step_4: "Load adapters from project.yaml or autodetect"
    step_5: "Run full UI review (sections 2-5)"
    step_6: "Output ui-review.md"
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
