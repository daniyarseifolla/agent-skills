---
name: figma-coding-rules
description: "Figma extraction, CSS self-verify, UI quality check, icon rules, and UI implementation rules. Loaded by pipeline-coder when design adapter is active. Never invoked directly by user."
disable-model-invocation: true
---

# Figma Coding Rules

Loaded by pipeline-coder Phase 3 when design adapter is active. Contains all Figma extraction, verification, and UI implementation rules.

---

## 1. Figma Extraction (MANDATORY for UI tasks)

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

  LAYOUT_RULE: |
    NEVER guess flex-direction, justify-content, align-items, gap, padding for ANY container.
    For EVERY container/wrapper element, call get_design_context and read:
    - Auto-layout horizontal → flex-direction: row
    - Auto-layout vertical → flex-direction: column
    - If Figma shows NO auto-layout → do NOT add flexbox
    - gap value → exact px from Figma, not your assumption
    - padding → exact values per side from Figma
    - align-items / justify-content → from Figma alignment settings

    Common mistake: agent assumes flex-direction: column when Figma shows row.
    Rule: if Figma doesn't explicitly show column layout → it's row (default).
    Do NOT "think it looks like column" — READ the Figma node.

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

## 2. Figma Self-Verify (MANDATORY after writing CSS)

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

      step_3_compare:
        action: "Compare EVERY property from section 1 extraction_checklist"
        format_per_property: "Property: Figma says {X} → code has {Y} → MATCH/MISMATCH"

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
    tolerance_rationale: |
      Author tolerance (±0px): you are writing CSS values directly from Figma.
      There is no reason for approximation — write the exact value.
      This is stricter than the UI reviewer's render tolerance (±2px)
      because browser rendering introduces sub-pixel variance.
      Two-stage quality gate: coder writes exact → reviewer catches render drift.

  blocking_rule: |
    Do NOT proceed to the next component/part if current component has unresolved mismatches.
    The ONLY acceptable mismatches:
    - Responsive adjustments explicitly noted in plan
    - Project variable maps to a different but intentionally equivalent value
    All other mismatches MUST be fixed before moving on.
```

---

## 3. UI Quality Check (after all parts)

```yaml
ui_quality_check:
  skill: "refactoring-ui"
  when: "After ALL parts with UI are implemented and Figma Self-Verified"
  purpose: "Catch design quality issues that per-property check misses: hierarchy, spacing rhythm, visual weight balance"

  workflow:
    step_1: "Take screenshot of implemented page(s)"
    step_2: "Invoke Skill: refactoring-ui for scoring (0-10)"
    step_3: "Check: hierarchy, spacing, color, typography, depth, layout"
    step_4_fix:
      if_score_below_8:
        - "Read refactoring-ui feedback → identify top 3 issues by impact"
        - "For each issue: check if fix would conflict with Figma specs"
        - "If conflict → preserve Figma value, note discrepancy in handoff"
        - "If no conflict → apply fix, re-run section 2 (Self-Verify) for changed elements"
        - "If score still < 7 after fixes → STOP, include score + issues in handoff"

  what_it_catches:
    - "Wrong visual hierarchy (all text same weight/size)"
    - "Inconsistent spacing rhythm (8px here, 13px there)"
    - "Label-value hierarchy wrong (label bigger than value)"
    - "Too dense or too sparse layout"
    - "Button hierarchy missing (all buttons same style)"
    - "Shadows/depth inconsistent"
```

---

## 4. Icon Extraction

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

## 5. UI Implementation Rules

### 5a. BLOCKER Tier (must fix before commit)

```yaml
ui_rules_blocker:
  portal_overlay:
    rule: "Any menu, dropdown, tooltip, popover, or modal triggered by click MUST use portal/overlay"
    why: "Without portal, overlay clips by parent overflow:hidden"
    implementation:
      angular: "Use Angular CDK Overlay (@angular/cdk/overlay) or ask user for preferred approach"
      action: "ASK user: use CDK Overlay, PrimeNG OverlayPanel, or custom portal?"
    severity: BLOCKER
```

### 5b. MAJOR Tier (must fix before handoff)

```yaml
ui_rules_major:
  missing_states:
    rule: "For EVERY interactive component, verify ALL states exist"
    required_states:
      - "default — normal resting state"
      - "hover — mouse over"
      - "active/pressed — during click"
      - "focus-visible — keyboard focus"
      - "disabled — non-interactive"
      - "loading — async operation in progress"
      - "empty — no data"
      - "error — validation or API error"
      - "selected — item chosen (if applicable)"
    workflow:
      step_1: "Check Figma for each state — does a frame exist?"
      step_2: "If state missing in Figma → ASK user: implement default behavior or skip?"
      step_3: "If user says 'придумай' → generate reasonable states from project patterns"
    severity: MAJOR

  hidden_fields:
    rule: "Hidden/collapsed elements must use correct CSS"
    patterns:
      visually_hidden: "display: none or visibility: hidden — NOT opacity: 0"
      collapsed: "height: 0 + overflow: hidden + transition — for animated collapse"
      offscreen: "position: absolute; left: -9999px — for screen-reader-only content"
    never: "opacity: 0 without pointer-events: none (invisible but clickable = bug)"
    severity: MAJOR

  focus_states:
    rule: "Every interactive element MUST have visible :focus-visible"
    default: "outline: 2px solid var(--color-focus, #4A90D9); outline-offset: 2px"
    never: "outline: none without replacement (breaks keyboard navigation)"
    severity: MAJOR

  responsive:
    rule: "If Figma has mobile/tablet frames → implement responsive"
    action: "Check Figma for breakpoint variants. If none → ask user"
    severity: MAJOR

  skeleton_loading:
    rule: "Components that load async data MUST have loading state"
    options:
      - "Skeleton placeholder (preferred for content areas)"
      - "Spinner (for buttons, small actions)"
      - "Progress bar (for uploads, long operations)"
    severity: MAJOR
```

### 5c. MINOR Tier (fix if time permits)

```yaml
ui_rules_minor:
  transitions:
    rule: "Every interactive element MUST have CSS transition"
    defaults:
      hover: "transition: background-color 200ms ease, color 200ms ease"
      focus: "transition: box-shadow 200ms ease, outline 200ms ease"
      expand: "transition: height 300ms ease, opacity 200ms ease"
    never: "transition: all (too broad, causes layout jank)"
    duration: "200-300ms for UI interactions, never 0ms, never >500ms"
    severity: MINOR

  z_index:
    rule: "Never hardcode z-index: 9999. Use project scale."
    scale: "base(1) < dropdown(100) < modal(200) < toast(300) < tooltip(400)"
    prefer: "CSS variables: var(--z-dropdown), var(--z-modal), etc."
    severity: MINOR

  overflow_text:
    rule: "Long text MUST have overflow handling"
    patterns:
      single_line: "white-space: nowrap; overflow: hidden; text-overflow: ellipsis"
      multi_line: "display: -webkit-box; -webkit-line-clamp: N; overflow: hidden"
      scrollable: "overflow-y: auto; max-height: Npx"
    severity: MINOR

  cursor:
    rule: "Correct cursor for element state"
    map:
      clickable: "cursor: pointer"
      disabled: "cursor: not-allowed"
      text_input: "cursor: text"
      draggable: "cursor: grab / cursor: grabbing"
      loading: "cursor: wait"
    severity: MINOR

  animation_duration:
    rule: "Standard durations for UI animations"
    scale:
      instant: "100ms — micro-interactions (button press)"
      fast: "200ms — hover, focus, color changes"
      normal: "300ms — expand/collapse, slide"
      slow: "500ms — page transitions, complex animations"
    never: "0ms (jarring) or >1000ms (feels broken)"
    severity: MINOR
```
