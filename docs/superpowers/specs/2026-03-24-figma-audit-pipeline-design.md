# /figma — Figma Audit & Implementation Pipeline

**Date:** 2026-03-24
**Status:** Approved
**Author:** Danny + Claude consensus

## Problem

No single command to: generate a Figma node map, compare implementation against design (visual + per-property), and fix/build through subagents. Current tools (`/verify-figma`, `/worker`) handle pieces but not the full cycle.

## Command

```
/figma <figma-url> [app-url]
```

### Phase 0: Pre-flight Detection

Before launching Phase 1, determine mode:

```yaml
preflight:
  step_1: "Parse Figma URL → extract fileKey, nodeId"
  step_2: "Glob project for component files (*.component.ts, *.tsx, *.vue, *.svelte)"
  step_3: "Set code_exists = (component_count > 0)"
  step_4: "Determine mode:"
  mode_table:
    - { condition: "app-url AND code_exists", mode: "audit+fix", phases: "0 → 1 → 2 → 3 → 4" }
    - { condition: "app-url AND NOT code_exists", mode: "build", phases: "0 → 1 → 3 → 4" }
    - { condition: "no app-url", mode: "audit-only", phases: "0 → 1 → 2 (Figma extract only, no browser)" }
  step_5: "Show mode to user, ask confirmation"
  step_6: "If audit-only AND no app-url: Agent 2 (Visual Matcher) skipped in Phase 1, node map will lack CSS selectors"
```

### URL Parsing

Extract `fileKey` and `nodeId` from Figma URL:
- `figma.com/design/:fileKey/:fileName?node-id=:nodeId` → convert `-` to `:` in nodeId
- If nodeId points to a frame → recursive traversal of children
- If nodeId points to a component → single component mode

## Phase 1: Consensus Node Map

3 agents in parallel, different angles. Same Figma input.

### Agent 1 — Structure Mapper

```yaml
angle: "Figma tree structure → code component mapping by NAME"
input: figma-url, fileKey, nodeId
tools: [get_design_context, get_metadata, Glob, Grep]
steps:
  1: "get_design_context for root node → extract full tree"
  2: "For each leaf/component node: extract name, type, CSS properties"
  3: "Glob project for matching component files (by layer name → selector/filename)"
  4: "Build mapping table: node-id | figma-name | component-file | confidence"
output: "node-map-structure.md"
budget: "max 30 tool calls"
```

### Agent 2 — Visual Matcher

```yaml
angle: "Visual position matching — which DOM element = which Figma node"
input: figma-url, app-url, fileKey, nodeId
tools: [get_screenshot, browser_take_screenshot, browser_snapshot, browser_evaluate]
steps:
  1: "get_screenshot from Figma for root frame"
  2: "browser_take_screenshot of app-url"
  3: "Compare visually: identify DOM elements that correspond to Figma nodes by position, size, appearance"
  4: "For ambiguous matches: browser_evaluate to get element bounding boxes, compare with Figma coordinates"
  5: "For each matched element: extract stable CSS selector via browser_evaluate"
  selector_strategy: |
    Primary: document.elementFromPoint(figma_x, figma_y) → build unique selector
    Method: element.tagName + nth-child path OR data-testid/data-cy if available
    Fallback: full CSS path via element.closest('[class]') chain
    Output: querySelector-compatible string for getComputedStyle
  6: "Build mapping table: node-id | figma-name | css-selector | bbox-match-confidence"
output: "node-map-visual.md"
budget: "max 30 tool calls"
skip_when: "audit-only mode (no app-url)"
```

### Agent 3 — Code Scanner

```yaml
angle: "Codebase analysis — find all components, match to Figma layers"
input: figma-url, fileKey, nodeId, project-root
tools: [Glob, Grep, Read, Bash(git)]
steps:
  1: "Glob for all component files (*.component.ts, *.tsx, *.vue, *.svelte)"
  2: "Extract selectors, class names, SCSS file paths"
  3: "Read .claude/ui-inventory.md if exists"
  4: "Match Figma layer names to component selectors/filenames"
  5: "Identify UNMAPPED (in Figma, not in code) and ORPHANED (in code, not in Figma)"
  6: "Build mapping table: component-file | selector | figma-node | status (mapped/unmapped/orphaned)"
output: "node-map-code.md"
budget: "max 30 tool calls"
```

### Aggregation

```yaml
method:
  1: "Read all 3 agent outputs"
  2: "For each Figma node:"
  3: "  - Mapped by 2+ agents → confirmed (high confidence)"
  4: "  - Mapped by 1 agent → low confidence, flag for review"
  5: "  - Unmapped by all 3 → new component (build mode target)"
  6: "For each code component:"
  7: "  - Not in any Figma mapping → orphaned"
minimum_confidence_guard:
  rule: "If fewer than 30% of Figma nodes are mapped at high confidence → HALT"
  action: "Show node map to user with low-confidence flags. Ask: proceed anyway / refine manually / abort"
  note: "Prevents Phase 2 from running on unreliable data"

output: "figma-node-map.md"
format: |
  ## Figma Node Map

  | # | Figma Node | node-id | Component File | CSS Selector | Confidence | Status |
  |---|-----------|---------|----------------|-------------|------------|--------|
  | 1 | CardHeader | 123:456 | card.component.ts | app-card .header | high (3/3) | mapped |
  | 2 | UserAvatar | 123:789 | — | — | — | unmapped (new) |

  ## Summary
  - Mapped: N components (high: X, low: Y)
  - Unmapped: N (new components to build)
  - Orphaned: N (code without Figma match)
```

### Rate Limiting (Phase 1)

```yaml
rate_limiting:
  rule: "Figma MCP max 5 get_design_context calls per minute (adapter-figma Section 8)"
  strategy: "Agent 1 (Structure Mapper) is the heaviest Figma caller. Stagger: launch Agents 2+3 immediately, launch Agent 1 with 15s delay to spread API calls"
  fallback: "If rate limit hit → agent waits 12s, retries. Max 3 retries per call."
```

## Phase 2: Consensus Comparison

3 agents in parallel, different angles. Requires app-url. **Phase 1 aggregation must complete before Phase 2 starts.**

### Agent 1 — Visual Comparator

```yaml
angle: "Screenshot-level visual diff"
input: figma-url, app-url, figma-node-map.md
tools: [get_screenshot, browser_take_screenshot, browser_resize]
steps:
  1: "For each frame in node map:"
  2: "  get_screenshot from Figma"
  3: "  browser_take_screenshot at same viewport size"
  4: "  Compare: spacing rhythm, alignment, visual hierarchy, color consistency"
  5: "Repeat at mobile (375px) and tablet (768px) viewports"
  6: "Score each frame 1-10 (aligned with consensus-review scoring)"
skill_dependency: "visual-qa (on_unavailable: skip, score based on manual comparison)"
output: "comparison-visual.md"
budget: "max 40 tool calls, 8 min"
```

### Agent 2 — Property Auditor

```yaml
angle: "Per-property exact comparison via computed styles"
input: figma-url, app-url, figma-node-map.md
tools: [get_design_context, browser_evaluate, browser_navigate]
steps:
  1: "browser_navigate to app-url"
  2: "For each MAPPED component in node map:"
  3: "  Extract Figma CSS values from get_design_context (already in node map)"
  4: "  browser_evaluate: getComputedStyle for matching DOM element"
  5: "  Compare property-by-property:"
  6: "    font-size, font-weight, line-height, letter-spacing"
  7: "    color, background-color, border, border-radius"
  8: "    padding, margin, gap, width, height"
  9: "    flex-direction, justify-content, align-items"
  10: "    box-shadow, opacity"
  11: "  Classify: OK (exact match) | MISMATCH (value differs) | MISSING (property absent)"
  12: "  Tolerance policy (aligned with figma-coding-rules Section 2):"
  tolerance:
    spacing: "±0px (padding, margin, gap, width, height)"
    colors: "exact hex match"
    font_weight: "exact match"
    font_size: "±0px"
    border_radius: "±1px (subpixel rendering)"
    note: "This is stricter than adapter-figma compare_visual (which allows visual parity). Property auditor uses exact match; Visual Comparator uses visual parity."
output: "comparison-properties.md"
format: |
  | Component | Property | Figma | Browser | Status |
  |-----------|----------|-------|---------|--------|
  | app-card .header | font-size | 16px | 14px | MISMATCH |
  | app-card .header | color | #1A1A1A | #1A1A1A | OK |
budget: "max 40 tool calls, 8 min"
```

### Agent 3 — UX/Interaction Reviewer

```yaml
angle: "States, interactions, responsive behavior, accessibility"
input: app-url, figma-node-map.md
tools: [browser_click, browser_hover, browser_resize, browser_evaluate, browser_take_screenshot, browser_snapshot]
steps:
  1: "For each interactive component in node map:"
  2: "  Test hover state (browser_hover → screenshot)"
  3: "  Test focus state (Tab key → check focus-visible)"
  4: "  Test disabled state (if applicable)"
  5: "  Test loading state (if async)"
  6: "Responsive: resize to 375px, 768px, 1024px, 1440px"
  7: "  Screenshot each breakpoint"
  8: "  Check for overflow, broken layouts, hidden content"
  9: "Accessibility: check contrast, focus order, aria labels"
skill_dependency: "ui-ux-pro-max (on_unavailable: skip advanced UX checks)"
output: "comparison-ux.md"
budget: "max 40 tool calls, 8 min"
```

### Aggregation

```yaml
method:
  1: "Read all 3 agent outputs"
  2: "Consensus findings (2+ agents) → confirmed"
  3: "Conflicts (agents disagree) → flag"
  4: "Unique findings (1 agent) → lower confidence"
  5: "Overall score: average of 3 agents"
output: "figma-comparison.md"
score_thresholds:
  PASS: "≥8.5 — implementation matches design"
  PASS_WITH_ISSUES: "7.0-8.4 — minor deviations"
  ISSUES_FOUND: "<7.0 — significant mismatches"
scoring_note: "All agents use 1-10 scale (consensus-review standard). Final score = average of 3."

property_diff_serialization:
  step: "After Phase 2 aggregation, orchestrator parses comparison-properties.md into structured YAML"
  output_path: "docs/figma-audit/{id}/property-diff.yaml"
  format: |
    components:
      - selector: "app-card .header"
        mismatches:
          - { property: font-size, figma: 16px, browser: 14px }
        ok_count: 12
        mismatch_count: 1
  purpose: "Phase 3 subagents consume this YAML, not the Markdown table"
```

## Phase 3: Implementation

Triggered in audit+fix and build modes. Skipped in audit-only.

### Routing

```yaml
routing:
  per_component:
    inline_fix:
      condition: "≤3 MISMATCH properties AND component exists in code"
      action: "Fix in current session, no subagent"
      steps: [read_figma_values, edit_scss, self_verify, update_figma_verify_md, commit_gate]
      commit_gate: "Same as subagent — figma-verify.md must have no MISMATCH rows for this component before commit"

    subagent_fix:
      condition: ">3 MISMATCH properties AND component exists in code"
      action: "Spawn subagent for this component"

    subagent_build:
      condition: "Component is UNMAPPED (new, no code exists)"
      action: "Spawn subagent to build from scratch"

  max_parallel_subagents: 5
  per_subagent_timeout: "10 min — if exceeded, mark component as unverified, proceed to Phase 4"
  phase_sequencing: "Phase 2 aggregation COMPLETE → Phase 3 subagents → all subagents COMPLETE → reload gate → Phase 4"
```

### Subagent Contract

```yaml
subagent_input:
  component_name: string
  figma_node_id: string
  figma_css: "object — all extracted CSS properties from Figma"
  property_diff: "object — MISMATCH list from Phase 2 (if fix mode)"
  closest_pattern: "string — path to closest existing component (RESEARCH_FIRST)"
  project_variables: "string — path to SCSS variables/tokens"
  mode: "fix | build"

subagent_steps:
  1: "Read closest_pattern component — understand project conventions"
  2: "If fix: read current component, apply Figma values for each MISMATCH"
  3: "If build: create component from scratch using Figma extract + pattern"
  4: "Self-Verify: compare EVERY CSS property against figma_css"
  5: "Commit gate: verify figma-verify.md has no MISMATCH rows"
  6: "git commit -m '{task}: {component_name} — figma {fix|build}'"

subagent_output:
  component_file: string
  properties_fixed: number
  properties_remaining: number
  commit_hash: string
```

### Dev Server Reload Gate (between Phase 3 and Phase 4)

```yaml
reload_gate:
  step_1: "After all Phase 3 subagents complete"
  step_2: "Run tech_stack_adapter.commands.build (verify code compiles)"
  step_3: "If dev server running → wait for hot-reload (check via browser_navigate → verify new content)"
  step_4: "If no hot-reload → prompt user: 'Phase 3 complete. Restart dev server, then confirm to proceed to verification.'"
  step_5: "User confirms → proceed to Phase 4"
```

## Phase 4: Consensus Verification

Identical to Phase 2 but runs AFTER Phase 3 fixes/builds and dev server reload. Same 3 agents, same angles. **Phase 3 must be fully complete before Phase 4 starts.**

```yaml
verification:
  agents: "Same 3 as Phase 2 (Visual + Property + UX)"
  input: "Updated app-url (dev server with new code)"
  additional_output:
    before_score: "from Phase 2"
    after_score: "from Phase 4"
    delta: "improvement"
    remaining_issues: "list"

  verdict_mapping:
    PASS: "score ≥8.5 — done"
    PASS_WITH_ISSUES: "score 7.0-8.4 — report issues, don't re-fix"
    ISSUES_FOUND: "score <7.0 — report to user for manual decision"

  note: "No auto-reloop. Phase 4 runs ONCE. User decides on remaining issues."
```

## Output Files

All outputs written to `docs/figma-audit/{audit-id}/`. Audit ID = Jira task key if available, otherwise `figma-YYYY-MM-DD-HHMMSS`.

```
figma-node-map.md          — Phase 1 result
figma-comparison.md        — Phase 2 result
figma-audit-report.md      — Phase 4 final report (before/after)
.tmp/                      — intermediate agent files (cleaned up after aggregation)
```

## Integration with Existing Skills

```yaml
skills_used:
  - adapter-figma: "get_design_context, get_screenshot, parse_urls"
  - figma-coding-rules: "self-verify, extract, commit gate"
  - visual-qa: "screenshot comparison scoring"
  - css-styling-expert: "CSS architecture decisions (on_unavailable: skip)"
  - refactoring-ui: "UI quality scoring (on_unavailable: skip)"
  - ui-ux-pro-max: "UX review (on_unavailable: skip)"
  - agent-browser OR playwright: "browser automation (headless)"
  - consensus-review: "aggregation pattern"
  - superpowers:dispatching-parallel-agents: "subagent dispatch"

mcp_required:
  - figma: "Figma MCP for design extraction"
  - playwright OR chrome-devtools: "Browser for screenshots + computed styles"

on_mcp_unavailable:
  figma: "HALT — cannot proceed without Figma access"
  browser: "Skip browser phases, run Figma-extract-only mode (partial audit)"
```

## Cost Estimate

```yaml
cost:
  phase_1: "3 agents x ~30 calls = ~90 tool calls"
  phase_2: "3 agents x ~40 calls = ~120 tool calls"
  phase_3: "N subagents x ~20 calls = variable"
  phase_4: "3 agents x ~40 calls = ~120 tool calls"
  total: "~330 + (N x 20) tool calls"
  duration: "~15-25 min for full cycle"
  note: "audit-only skips Phase 3+4 = ~210 calls, ~10 min"
```
