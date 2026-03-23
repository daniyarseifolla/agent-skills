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
    step_0: "RESEARCH existing patterns — find the closest existing component in the project and study its approach"
    step_1: "If part has UI/CSS → run Figma Extract (section 8) for EVERY element in this part"
    step_2: "Implement code changes per plan using extracted values + existing pattern as template"
    step_3: "If part has UI/CSS → run Figma Self-Verify (section 8b) — compare EVERY CSS property against Figma"
    step_4: "Run tech_stack_adapter lint command"
    step_5: "Run tech_stack_adapter test command"
    step_6: "If verify/lint/test fail → fix → retry"
    step_7: "git add changed files && git commit -m '{task_key}: Part {N} — {part_description}'"
    commit_rule: "One commit per successfully verified part. Do not batch multiple parts into one commit."
    max_retries_per_part: 3

    RESEARCH_FIRST: |
      BEFORE writing ANY code for a UI component:
      1. Find the closest existing component in the project (Glob for similar selectors/names)
      2. Read its .component.ts, .component.html, .component.scss — understand the PATTERN
      3. Note: which mixins it uses, how SCSS is organized, which variables, how layout is done
      4. Use this pattern as your TEMPLATE — copy the approach, adapt for new component
      Example: building a new dialog → find existing dialog → copy its SCSS structure

    STALE_CONTEXT_RULE: |
      If you've made 2+ failed attempts at the same component:
      1. STOP iterating in current context — it's polluted with wrong approaches
      2. The fix: spawn a FRESH subagent with CLEAN context containing ONLY:
         - Figma specs (node-ids + extracted CSS)
         - Existing pattern files (the closest component you found in step_0)
         - Project variables/mixins
      3. Fresh agent with clean context gets it right first try
      4. NEVER keep trial-and-error fixing after 3 attempts — you're making it worse

    CRITICAL: |
      Steps 0, 1 and 3 are MANDATORY for any part that touches CSS/SCSS/HTML templates.
      Step 0 (research) prevents trial-and-error. Step 3 (verify) catches remaining mismatches.
      The loop is: research → extract → write → verify → fix → next component.
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
    action: "Dispatch pipeline-code-researcher via Agent tool"
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

## 8. Figma Implementation

```yaml
figma_rules:
  PREREQUISITE: "If design adapter is active, load Skill: figma-coding-rules BEFORE implementing any part"
  contains: "Figma extraction, self-verify, UI quality check, icon extraction, UI implementation rules"
  loaded_via: "Skill tool — load figma-coding-rules at start of Phase 3"

  integration_with_for_each_part:
    step_0: "RESEARCH existing patterns (unchanged)"
    step_1: "If part has UI → follow figma-coding-rules section 8 (Figma Extract)"
    step_2: "Implement code (unchanged)"
    step_3: "If part has UI → follow figma-coding-rules section 8b (Self-Verify)"
    step_7: "Commit per part (unchanged)"
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

## 11. Library Code

```yaml
library_code:
  rule: "Library/node_modules code is READ-ONLY. Never modify files in node_modules or external libraries."
```
