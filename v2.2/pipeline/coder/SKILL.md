---
name: pipeline-coder
description: "Implementation phase: evaluates plan critically, then implements code in dependency order. Uses sonnet model. Called by pipeline/worker Phase 3."
model: sonnet
---

# Pipeline Coder

Phase 3. Evaluate gate, then implement. Plan-driven, adapter-aware.

---

## 1. Input

```yaml
input:
  plan_path: "docs/plans/{task-key}/plan.md"
  reviewer_handoff:
    verdict: "APPROVED|NEEDS_CHANGES"
    approved_notes: string[]
    issues: string[]
    iteration: "N/3"
  tech_stack_adapter: "for lint/test/build commands"
  complexity: "S|M|L|XL"
```

---

## 2. Evaluate Gate

Per core-orchestration evaluate_gate protocol. Run before writing any code.

```yaml
evaluate:
  action: "Read plan critically — assess implementability"
  output_path: "docs/plans/{task-key}/evaluate.md"

  checks:
    - "All referenced files/modules accessible?"
    - "Proposed APIs compatible with existing code?"
    - "Hidden dependencies missed?"
    - "Implementation order logical?"
    - "AC testable with proposed approach?"
    - "Reviewer notes addressed?"

  verdicts:
    PROCEED:
      condition: "Plan valid and implementable"
      action: "Begin implementation"
    REVISE:
      condition: "Plan mostly valid but needs adjustments"
      action: "Document deviations in evaluate.md, continue"
    RETURN:
      condition: "Plan not implementable"
      action: "Form handoff back to plan-reviewer with issues"
      handoff: "coder_to_reviewer contract with verdict context"

  output_format: |
    ## Evaluate Result: {PROCEED|REVISE|RETURN}
    ### Assessment
    {analysis of plan implementability}
    ### Adjustments (if REVISE)
    {what differs from plan and why}
    ### Blockers (if RETURN)
    {what makes plan unimplementable}
```

---

## 3. Implementation

```yaml
implement:
  order: "Parts in dependency order from plan"

  for_each_part:
    step_1: "If part has UI/CSS → run Figma Extract (section 8) for EVERY element in this part"
    step_2: "Implement code changes per plan using extracted values"
    step_3: "If part has UI/CSS → run Figma Self-Verify (section 8b) — compare EVERY CSS property against Figma"
    step_4: "Run tech_stack_adapter lint command"
    step_5: "Run tech_stack_adapter test command"
    step_6: "If verify/lint/test fail → fix → retry"
    max_retries_per_part: 3

    CRITICAL: |
      Steps 1 and 3 are MANDATORY for any part that touches CSS/SCSS/HTML templates.
      Do NOT skip step 3 — this is the verification that prevents "approximate CSS" bugs.
      The loop is: extract → write → verify → fix → next component.
      NEVER move to the next part until ALL elements in current part pass Figma verification.

  rules:
    - "Implement ONLY what is in the plan"
    - "No improvements beyond plan scope"
    - "No refactoring outside plan scope"
    - "Document any deviations in evaluate.md (append)"
    - "Follow tech_stack_adapter component/service patterns"
    - "Reuse components from ui-inventory when applicable"

  L_XL_research:
    when: "Stuck on implementation detail for L/XL tasks"
    action: "Dispatch pipeline-code-researcher via Task tool"
    purpose: "Find patterns, imports, existing code to reference"
```

---

## 4. Verification

```yaml
verify:
  step_1_lint:
    command: "tech_stack_adapter.commands.lint"
    on_fail: "Fix issues, retry (max 3)"

  step_2_test:
    command: "tech_stack_adapter.commands.test"
    on_fail: "Fix tests, retry (max 3)"

  step_3_build:
    command: "tech_stack_adapter.commands.build"
    on_fail: "Fix build errors, retry (max 3)"

  on_all_pass: "Form handoff to code-reviewer"
  on_fail_3x: "STOP, show error details, request user help"
```

---

## 5. Handoff

Per core-orchestration coder_to_reviewer contract.

```yaml
handoff:
  to: "pipeline-code-reviewer"
  payload:
    branch: "current git branch"
    parts_implemented: "list of completed parts with file paths"
    deviations_from_plan: "from evaluate.md adjustments section"
    risks_mitigated: "issues addressed during implementation"
  validation: "All required fields per core-orchestration contract"
```

---

## 6. Loop Behavior

When code-reviewer returns CHANGES_REQUESTED.

```yaml
loop:
  trigger: "code-reviewer verdict == CHANGES_REQUESTED"
  input: "code-reviewer handoff with issues list"
  action:
    - "Read issues from code-review handoff"
    - "Fix each issue"
    - "Re-run verification (section 4)"
    - "Form new handoff"
  max: 3
  guard: "core-orchestration loop_limits"
```

---

## 7. Superpowers Integration

```yaml
execution_strategy:
  FULL_mode:
    skill: "superpowers:subagent-driven-development"
    when: "complexity M/L/XL, plan has 3+ parts"
    description: "Fresh subagent per task + two-stage review"

  SIMPLE_mode:
    skill: "superpowers:executing-plans"
    when: "complexity S, plan has 1-2 parts"
    description: "Execute in current session with checkpoints"
```

---

## 8. Figma Implementation (MANDATORY for UI tasks)

```yaml
figma_implementation:
  when: "Plan references Figma URLs or design adapter is active"
  skill: "figma:implement-design"

  CRITICAL_RULE: |
    For EVERY UI element, BEFORE writing any CSS/SCSS:
    1. Call get_design_context with the SPECIFIC Figma node-id from the plan
    2. Extract EXACT values: width, height, padding, margin, gap, border-radius,
       font-family, font-size, font-weight, line-height, letter-spacing,
       color, background-color, border, box-shadow, opacity
    3. Write CSS using these exact values (mapped to project variables where possible)
    4. NEVER guess or approximate values — always extract from Figma

  workflow_per_element:
    step_1: "Read plan → get Figma node-id for the element"
    step_2: "Call get_design_context(fileKey, nodeId) → extract code hints + screenshot"
    step_3: "Extract exact CSS properties from code hints"
    step_4: "Map hex colors to project SCSS variables (e.g., #FF5722 → $color-accent)"
    step_5: "Map spacing to project tokens (e.g., 16px → $spacing-md)"
    step_6: "Write CSS/SCSS using extracted + mapped values"
    step_7: "If code hints are insufficient, call get_screenshot and measure visually"

  extraction_checklist:
    layout: "display, flex-direction, justify-content, align-items, gap"
    sizing: "width, height, min-width, max-width, padding, margin"
    typography: "font-family, font-size, font-weight, line-height, letter-spacing, text-align, color"
    visual: "background-color, border, border-radius, box-shadow, opacity"
    spacing: "gap, padding, margin (top/right/bottom/left)"

  rules:
    - "MUST call get_design_context for EVERY UI component before writing CSS"
    - "MUST use exact px/rem values from Figma, not approximations"
    - "MUST map Figma colors to project SCSS variables / CSS custom properties"
    - "MUST map Figma spacing to project design tokens where they exist"
    - "NEVER hardcode hex colors — use variables"
    - "NEVER guess font-size, spacing, or border-radius — extract from Figma"
    - "MUST use existing SCSS mixins from ui-inventory when applicable"
    - "When Figma shows auto-layout → use flexbox with exact gap values"
    - "When Figma shows fixed dimensions → use exact px unless responsive context requires otherwise"

```

---

## 8b. Figma Self-Verify (MANDATORY after writing CSS)

```yaml
figma_self_verify:
  CRITICAL: |
    After implementing CSS for EACH component, IMMEDIATELY verify every property
    against Figma BEFORE moving to the next component.
    This step catches the #1 problem: agents writing approximate CSS instead of exact values.

  when: "After writing CSS/SCSS for any UI component"
  trigger: "Runs inside for_each_part step_3"

  workflow:
    for_each_element_in_part:
      step_1_recheck_figma:
        action: "Call get_design_context(fileKey, nodeId) again for this element"
        purpose: "Get authoritative CSS values (may have been lost from context)"

      step_2_read_written_css:
        action: "Read the SCSS/CSS you just wrote for this element"
        how: "Read the .scss/.css file, find the selector for this element"

      step_3_compare_property_by_property:
        action: "Compare EVERY property from extraction_checklist"
        checklist:
          - "font-family: Figma says {X} → code has {Y} → MATCH/MISMATCH"
          - "font-size: Figma says {X}px → code has {Y}px → MATCH/MISMATCH"
          - "font-weight: Figma says {X} → code has {Y} → MATCH/MISMATCH"
          - "line-height: Figma says {X}px → code has {Y}px → MATCH/MISMATCH"
          - "letter-spacing: Figma says {X}px → code has {Y} → MATCH/MISMATCH"
          - "color: Figma says {hex} → code has {var/hex} → MATCH/MISMATCH"
          - "padding: Figma says {T R B L}px → code has {values} → MATCH/MISMATCH"
          - "margin: Figma says {T R B L}px → code has {values} → MATCH/MISMATCH"
          - "gap: Figma says {X}px → code has {Y}px → MATCH/MISMATCH"
          - "width/height: Figma says {X}px → code has {Y} → MATCH/MISMATCH"
          - "border-radius: Figma says {X}px → code has {Y}px → MATCH/MISMATCH"
          - "background-color: Figma says {hex} → code has {var/hex} → MATCH/MISMATCH"
          - "border: Figma says {width style color} → code has {values} → MATCH/MISMATCH"
          - "box-shadow: Figma says {values} → code has {values} → MATCH/MISMATCH"
          - "opacity: Figma says {X} → code has {Y} → MATCH/MISMATCH"

      step_4_fix_mismatches:
        action: "For each MISMATCH → fix immediately"
        rule: "Use Figma value, not your approximation"

      step_5_log_verification:
        action: "Write verification result to docs/plans/{task-key}/figma-verify.md"
        format: |
          ## {component_name}
          | Property | Figma | Code | Match |
          |----------|-------|------|-------|
          | font-size | 16px | 16px | YES |
          | font-weight | 700 | 600 | FIXED → 700 |
          | padding | 24px 32px | 20px 24px | FIXED → 24px 32px |
          | color | #1A1A2E | $text-primary (#1A1A2E) | YES |

  tolerance:
    size: "±0px for exact values, ±1px only for computed/inherited"
    color: "exact match (hex must resolve to same value)"
    font_weight: "exact match (700 ≠ 600, bold ≠ semibold)"
    spacing: "±0px — padding and margin must be exact"
    border_radius: "exact match"

  blocking_rule: |
    Do NOT proceed to the next component/part if current component has unresolved mismatches.
    The ONLY acceptable mismatches:
    - Responsive adjustments explicitly noted in plan
    - Project variable maps to a different but intentionally equivalent value
    All other mismatches MUST be fixed before moving on.
```

---

## 8c. Icon Extraction

```yaml
  icon_extraction:
    CRITICAL: "NEVER draw SVG icons manually — always source from Figma or designer"
    problem: |
      Figma MCP cannot export SVG code directly.
      get_design_context returns a raster asset URL (PNG), not SVG.
      Manually drawing SVG leads to wrong stroke/fill, wrong shape, broken masks.
    workflow:
      step_1: "Call get_design_context for the icon node"
      step_2: "Check if asset URL is returned (figma.com/api/mcp/asset/...)"
      step_3: "Try WebFetch on the asset URL — if it returns SVG content, use it"
      step_4: "If PNG/raster → ASK user to export SVG from Figma (File → Export → SVG)"
      step_5: "If user provides SVG → use it directly"
      step_6: "If no SVG available → use <img> with the raster asset URL as fallback"

    css_mask_rule: |
      When using SVG as CSS mask-image:
      - SVG MUST use fill paths, NOT stroke-only paths
      - stroke-only SVG will show as empty rectangle in mask
      - If SVG has stroke without fill → convert stroke to filled path or ask designer

    never_do:
      - "NEVER attempt to hand-draw SVG path data"
      - "NEVER guess icon shapes from screenshots"
      - "NEVER convert stroke SVG to fill by hand — shapes won't match"
      - "If 3 attempts fail → STOP, ask user for the SVG file"
```

---

## 9. CSS Architecture

```yaml
css_architecture:
  skill: "css-styling-expert"
  when: "Writing CSS/SCSS for new components or significant UI changes"
  use_for:
    - "Layout decisions: Grid vs Flexbox, when to use which"
    - "Responsive patterns: mobile-first, fluid typography, container queries"
    - "CSS organization: BEM naming, component scoping, specificity management"
    - "Performance: avoiding repaints, efficient selectors, animation performance (60fps)"
    - "Cross-browser: progressive enhancement, feature detection"
    - "Accessibility: focus management, color contrast, screen reader support"
  workflow:
    step_1: "Extract exact values from Figma (section 8)"
    step_2: "Before writing CSS, check css-styling-expert for patterns applicable to this layout"
    step_3: "Write CSS following expert recommendations + project conventions"
    step_4: "If layout is complex (grid, nested flex, responsive), invoke css-styling-expert for review"
  rules:
    - "Use modern CSS: prefer CSS Grid for 2D layouts, Flexbox for 1D"
    - "Use CSS custom properties for dynamic values (theme-aware)"
    - "Prefer logical properties (inline/block) over physical (left/right) when project supports it"
    - "Animations: use transform/opacity only for GPU-accelerated 60fps"
    - "Never use !important unless overriding third-party styles"
```

---

## 10. Component Reuse Rules

```yaml
component_reuse:
  mandatory:
    - "MUST reuse existing components from .claude/ui-inventory.md"
    - "MUST use existing SCSS mixins for common patterns (spacing, flexbox, typography)"
    - "MUST use design token variables (colors, sizes, shadows)"
    - "NEVER hardcode colors, font sizes, or spacing values"
    - "NEVER create a new component if a shared one covers ≥80% of the need"

  check: "Read .claude/ui-inventory.md before implementing any UI"
```

---

## 10. Library Code

```yaml
library_code:
  rule: "Library/node_modules code is READ-ONLY. Never modify files in node_modules or external libraries."
```
