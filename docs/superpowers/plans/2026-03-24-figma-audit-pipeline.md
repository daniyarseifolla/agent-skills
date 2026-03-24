# /figma Audit Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New `/figma` command that generates a consensus node map, compares implementation vs design (visual + per-property + UX), fixes/builds via subagents, and verifies with consensus review.

**Architecture:** New facade skill `figma-audit` orchestrates 4 phases with consensus pattern. Reuses existing adapter-figma, figma-coding-rules, consensus-review, and browser MCP. New command `/figma` is the entry point.

**Tech Stack:** Markdown skill files (YAML-structured), Claude Code command format, Figma MCP, Playwright MCP.

**Spec:** `docs/superpowers/specs/2026-03-24-figma-audit-pipeline-design.md`

---

## File Structure

```
CREATE: v2.2/facades/figma-audit/SKILL.md          — main facade skill (~250 lines)
CREATE: v2.2/commands/figma.md                       — command entry point (~15 lines)
MODIFY: v2.2/SKILLS_OVERVIEW.md                      — add figma-audit to catalog
MODIFY: AGENT.md                                     — update with new command
```

No new core or pipeline skills needed — the facade orchestrates existing skills (consensus-review pattern, adapter-figma, figma-coding-rules, dispatching-parallel-agents).

---

### Task 1: Create `/figma` command entry point

**Files:**
- Create: `v2.2/commands/figma.md`

- [ ] **Step 1: Write the command file**

```markdown
---
description: "Figma audit & implementation pipeline. Usage: /figma <figma-url> [app-url]"
---

# Figma Audit Pipeline

Arguments: $ARGUMENTS

Load Skill: figma-audit

Execute the figma-audit skill with:
- figma_url: first argument (required — Figma URL)
- app_url: second argument (optional — dev server URL for browser comparison)

If no arguments: ask user for Figma URL.
```

- [ ] **Step 2: Copy to global commands**

```bash
cp v2.2/commands/figma.md ~/.claude/commands/figma.md
```

- [ ] **Step 3: Verify command loads**

Run: `/figma` in Claude Code — should prompt for Figma URL.

- [ ] **Step 4: Commit**

```bash
git add v2.2/commands/figma.md
git commit -m "feat: add /figma command entry point"
```

---

### Task 2: Create figma-audit facade — Phase 0 (preflight) + Phase 1 (consensus node map)

**Files:**
- Create: `v2.2/facades/figma-audit/SKILL.md`

- [ ] **Step 1: Write the skill header + Phase 0 preflight**

```markdown
---
name: figma-audit
description: "Figma audit & implementation pipeline. Generates consensus node map, compares visual + per-property + UX, fixes/builds via subagents, verifies with consensus review. Triggered by /figma command or phrases like 'проверь верстку', 'figma audit', 'сравни с макетом'."
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_press_key
---

# Figma Audit Pipeline

Full-cycle Figma design comparison and implementation.

---

## Phase 0: Preflight

```yaml
preflight:
  step_1_parse_url:
    action: "Extract fileKey and nodeId from Figma URL"
    url_patterns:
      - "figma.com/design/:fileKey/:fileName?node-id=:nodeId"
      - "figma.com/design/:fileKey/branch/:branchKey/:fileName"
    nodeId_fix: "Convert '-' to ':' in nodeId"

  step_2_detect_mode:
    action: "Determine audit mode"
    checks:
      - "Glob project: *.component.ts, *.tsx, *.vue, *.svelte → set code_exists"
      - "app-url provided? → set has_app_url"
    modes:
      audit_fix: { condition: "has_app_url AND code_exists", phases: "0,1,2,3,4" }
      build: { condition: "has_app_url AND NOT code_exists", phases: "0,1,3,4" }
      audit_only: { condition: "NOT has_app_url", phases: "0,1,2" }

  step_3_preflight_checks:
    figma_mcp: "Call get_metadata(fileKey) — if fails → HALT: Figma MCP unavailable"
    browser_mcp: "If has_app_url → browser_navigate(app_url) — if fails → fallback to audit-only"

  step_4_confirm:
    display: |
      Figma Audit Pipeline
      Mode: {mode}
      Figma: {figma_url} (frame: {nodeId})
      App: {app_url | 'not provided'}
      Components found: {component_count}
      Phases: {phase_list}
    action: "Ask user confirmation before proceeding"

  step_5_create_output_dir:
    path: "docs/figma-audit/{audit_id}/"
    audit_id: "Jira task key if available, else figma-YYYY-MM-DD-HHMMSS"
```

---

## Phase 1: Consensus Node Map

3 agents in parallel, different angles.

```yaml
node_map:
  dispatch: "Use Skill: superpowers:dispatching-parallel-agents"

  rate_limiting:
    strategy: "Launch Agents 2+3 immediately, Agent 1 with 15s delay"
    per_call_limit: "Max 5 get_design_context per minute"

  agent_1_structure:
    name: "structure-mapper"
    model: sonnet
    prompt: |
      You are the Structure Mapper agent for Figma audit.

      Input:
      - Figma fileKey: {fileKey}
      - Figma nodeId: {nodeId}
      - Project root: {project_root}

      Steps:
      1. Call get_design_context(fileKey, nodeId) → extract full component tree
      2. For each leaf/component node: extract name, type, all CSS properties
      3. Glob project for matching component files:
         - Match Figma layer name to component filename (e.g., "CardHeader" → card-header.component.ts)
         - Match Figma layer name to CSS selector (e.g., "CardHeader" → .card-header, app-card-header)
      4. Build mapping table in Markdown:
         | node-id | figma-name | figma-type | component-file | confidence |

      Write output to: docs/figma-audit/{audit_id}/.tmp/node-map-structure.md
      Budget: max 30 tool calls.

  agent_2_visual:
    name: "visual-matcher"
    model: sonnet
    skip_when: "audit-only mode (no app-url)"
    prompt: |
      You are the Visual Matcher agent for Figma audit.

      Input:
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - App URL: {app_url}

      Steps:
      1. get_screenshot(fileKey, nodeId) → Figma screenshot
      2. browser_navigate(app_url) → browser_take_screenshot → browser screenshot
      3. Compare visually: which DOM elements correspond to which Figma nodes
      4. For each match: browser_evaluate to extract stable CSS selector:
         ```js
         // For element at position (x, y):
         const el = document.elementFromPoint(x, y);
         // Build selector: prefer data-testid, then tag+nth-child path
         function getSelector(el) {
           if (el.dataset.testid) return `[data-testid="${el.dataset.testid}"]`;
           if (el.id) return `#${el.id}`;
           // Build path: tag:nth-child chain
           const path = [];
           while (el && el !== document.body) {
             const parent = el.parentElement;
             if (!parent) break;
             const idx = Array.from(parent.children).indexOf(el) + 1;
             path.unshift(`${el.tagName.toLowerCase()}:nth-child(${idx})`);
             el = parent;
           }
           return path.join(' > ');
         }
         ```
      5. Build mapping table:
         | node-id | figma-name | css-selector | bbox-confidence |

      Write output to: docs/figma-audit/{audit_id}/.tmp/node-map-visual.md
      Budget: max 30 tool calls.

  agent_3_code:
    name: "code-scanner"
    model: sonnet
    prompt: |
      You are the Code Scanner agent for Figma audit.

      Input:
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - Project root: {project_root}

      Steps:
      1. Glob: *.component.ts, *.tsx, *.vue, *.svelte → list all components
      2. For each: extract selector (from @Component metadata or filename), SCSS file path
      3. Read .claude/ui-inventory.md if exists (for shared components)
      4. Call get_design_context(fileKey, nodeId) → get Figma layer names
      5. Match: Figma layer names ↔ component selectors/filenames
      6. Classify: MAPPED (match found) | UNMAPPED (Figma only) | ORPHANED (code only)
      7. Build mapping table:
         | component-file | selector | figma-node-id | figma-name | status |

      Write output to: docs/figma-audit/{audit_id}/.tmp/node-map-code.md
      Budget: max 30 tool calls.

  aggregation:
    after: "All 3 agents complete"
    steps:
      - "Read .tmp/node-map-structure.md, .tmp/node-map-visual.md, .tmp/node-map-code.md"
      - "Merge: node mapped by 2+ agents → high confidence"
      - "Node mapped by 1 agent → low confidence"
      - "Unmapped by all → new component (build target)"
      - "Code component not in any map → orphaned"
    guard: "If <30% nodes at high confidence → HALT, show map, ask user"
    output: "docs/figma-audit/{audit_id}/figma-node-map.md"
    cleanup: "rm -rf .tmp/ after aggregation confirmed"
```
```

- [ ] **Step 2: Verify YAML structure is valid**

Read back the file, check all YAML blocks parse correctly.

- [ ] **Step 3: Commit**

```bash
git add v2.2/facades/figma-audit/SKILL.md
git commit -m "feat(figma-audit): Phase 0 preflight + Phase 1 consensus node map"
```

---

### Task 3: Add Phase 2 (consensus comparison) to figma-audit

**Files:**
- Modify: `v2.2/facades/figma-audit/SKILL.md`

- [ ] **Step 1: Append Phase 2 section**

```markdown
---

## Phase 2: Consensus Comparison

3 agents in parallel. Requires app-url. Phase 1 aggregation must complete first.

```yaml
comparison:
  dispatch: "Use Skill: superpowers:dispatching-parallel-agents"
  prerequisite: "figma-node-map.md exists and has ≥1 mapped component"

  agent_1_visual:
    name: "visual-comparator"
    model: sonnet
    prompt: |
      You are the Visual Comparator for Figma audit Phase 2.

      Input:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - App URL: {app_url}

      Steps:
      1. Read figma-node-map.md → list of frames/components
      2. For each frame:
         a. get_screenshot(fileKey, frame_nodeId) → Figma screenshot
         b. browser_take_screenshot at matching viewport → browser screenshot
         c. Compare: spacing rhythm, alignment, visual hierarchy, color consistency
      3. Repeat at viewports: desktop (1440px), tablet (768px), mobile (375px)
      4. Score each frame 1-10
      5. Load Skill: visual-qa if available (on_unavailable: score manually)

      Output format:
      ## Visual Comparison
      | Frame | Desktop | Tablet | Mobile | Score | Findings |

      Overall score: average of all frames.
      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-visual.md
      Budget: max 40 tool calls, 8 min.

  agent_2_property:
    name: "property-auditor"
    model: sonnet
    prompt: |
      You are the Property Auditor for Figma audit Phase 2.

      Input:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - App URL: {app_url}

      Steps:
      1. Read figma-node-map.md → list of MAPPED components with CSS selectors
      2. browser_navigate(app_url)
      3. For each mapped component:
         a. Get Figma CSS values (from node map extract or call get_design_context)
         b. browser_evaluate: `window.getComputedStyle(document.querySelector('{selector}'))`
         c. Compare property-by-property:
            - font-size, font-weight, line-height, letter-spacing, color
            - padding-top/right/bottom/left, margin, gap
            - width, height, background-color, border, border-radius
            - flex-direction, justify-content, align-items
            - box-shadow, opacity
         d. Tolerance: ±0px spacing, exact colors/font-weight, ±1px border-radius
         e. Classify: OK | MISMATCH | MISSING
      4. Score: (OK_count / total_properties) * 10

      Output format:
      | Component | Property | Figma | Browser | Status |

      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-properties.md
      Budget: max 40 tool calls, 8 min.

  agent_3_ux:
    name: "ux-reviewer"
    model: sonnet
    prompt: |
      You are the UX/Interaction Reviewer for Figma audit Phase 2.

      Input:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - App URL: {app_url}

      Steps:
      1. Read figma-node-map.md → identify interactive components
      2. For each interactive component:
         a. browser_hover → take_screenshot (hover state)
         b. browser_press_key Tab → check focus-visible
         c. Test disabled/loading states if applicable
      3. Responsive: browser_resize to 375, 768, 1024, 1440
         - Screenshot each → check overflow, broken layouts
      4. Accessibility: evaluate contrast, focus order, aria-labels
      5. Load Skill: ui-ux-pro-max if available (on_unavailable: basic checks only)
      6. Score 1-10 per category: states, responsive, accessibility

      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-ux.md
      Budget: max 40 tool calls, 8 min.

  aggregation:
    steps:
      - "Read all 3 .tmp/comparison-*.md files"
      - "Consensus (2+ agents agree): confirmed findings"
      - "Conflicts: flag for user"
      - "Overall score: average of 3 agent scores"
      - "Verdict: PASS (≥8.5) | PASS_WITH_ISSUES (7.0-8.4) | ISSUES_FOUND (<7.0)"
    property_diff_serialization:
      action: "Parse comparison-properties.md → YAML structure"
      output: "docs/figma-audit/{audit_id}/property-diff.yaml"
    output: "docs/figma-audit/{audit_id}/figma-comparison.md"
    cleanup: "rm -rf .tmp/"
```
```

- [ ] **Step 2: Commit**

```bash
git add v2.2/facades/figma-audit/SKILL.md
git commit -m "feat(figma-audit): Phase 2 consensus comparison (visual + property + UX)"
```

---

### Task 4: Add Phase 3 (implementation) + reload gate to figma-audit

**Files:**
- Modify: `v2.2/facades/figma-audit/SKILL.md`

- [ ] **Step 1: Append Phase 3 + reload gate**

```markdown
---

## Phase 3: Implementation

Triggered in audit+fix and build modes. Skipped in audit-only.

```yaml
implementation:
  prerequisite: "figma-comparison.md exists (audit+fix) OR figma-node-map.md has unmapped nodes (build)"

  routing:
    for_each_component:
      - "Read property-diff.yaml → get mismatch_count per component"
      - "If mismatch_count ≤ 3 AND code exists → INLINE FIX"
      - "If mismatch_count > 3 AND code exists → SUBAGENT FIX"
      - "If component is UNMAPPED (no code) → SUBAGENT BUILD"

  inline_fix:
    steps:
      - "Read Figma values from property-diff.yaml"
      - "Edit .scss/.css file: replace mismatched values"
      - "Run figma-coding-rules Section 2 (Self-Verify)"
      - "Update figma-verify.md → no MISMATCH rows"
      - "Commit gate: verify figma-verify.md clean → git commit"

  subagent_dispatch:
    method: "Use Skill: superpowers:dispatching-parallel-agents"
    max_parallel: 5
    per_subagent_timeout: "10 min"

    subagent_prompt_template: |
      You are a Figma implementation subagent.

      Mode: {mode}  (fix | build)
      Component: {component_name}
      Figma node: {figma_node_id}

      Figma CSS (exact values to match):
      {figma_css_yaml}

      {if fix}
      Current mismatches:
      {property_diff_for_component}
      {endif}

      Closest existing component (STUDY THIS FIRST):
      {closest_pattern_path}

      Project SCSS variables: {variables_path}

      Steps:
      1. Read closest_pattern — understand project conventions (RESEARCH_FIRST)
      2. {if fix} Read current component, fix each MISMATCH using Figma values
         {if build} Create component from scratch: .ts + .html + .scss using Figma extract + pattern
      3. Self-Verify: load Skill figma-coding-rules Section 2
         - Compare EVERY CSS property against Figma
         - flex-direction MUST be verified explicitly
      4. Commit gate: figma-verify.md must have ZERO MISMATCH rows for this component
      5. git commit -m "figma-{mode}: {component_name}"

      Output:
      - component_file: path
      - properties_fixed: N
      - properties_remaining: N
      - commit_hash: hash

    on_timeout: "Mark component as UNVERIFIED, proceed to Phase 4"

  after_all_complete:
    collect: "subagent outputs → implementation-summary.md"
    output: "docs/figma-audit/{audit_id}/implementation-summary.md"
```

---

## Reload Gate

```yaml
reload_gate:
  step_1: "After all Phase 3 subagents/inline fixes complete"
  step_2: "Run tech_stack_adapter.commands.build — verify compilation"
  step_3: "If dev server running and hot-reload detected → proceed"
  step_4: "If no hot-reload → prompt user: 'Restart dev server, then confirm.'"
  step_5: "User confirms → Phase 4"
```
```

- [ ] **Step 2: Commit**

```bash
git add v2.2/facades/figma-audit/SKILL.md
git commit -m "feat(figma-audit): Phase 3 implementation + reload gate"
```

---

### Task 5: Add Phase 4 (consensus verification) + final report to figma-audit

**Files:**
- Modify: `v2.2/facades/figma-audit/SKILL.md`

- [ ] **Step 1: Append Phase 4 + report format**

```markdown
---

## Phase 4: Consensus Verification

Same 3 agents as Phase 2, re-run after fixes. Phase 3 must complete first.

```yaml
verification:
  dispatch: "Same as Phase 2 — reuse agent prompts with updated context"
  input_change: "Agents compare AFTER implementation (new browser state)"

  additional_output:
    before_score: "Phase 2 score"
    after_score: "Phase 4 score"
    delta: "after - before"
    remaining_mismatches: "list from property auditor"

  verdict:
    PASS: "score ≥8.5"
    PASS_WITH_ISSUES: "score 7.0-8.4"
    ISSUES_FOUND: "score <7.0"

  no_reloop: "Phase 4 runs ONCE. User decides on remaining issues."
```

---

## Final Report

```yaml
report:
  output: "docs/figma-audit/{audit_id}/figma-audit-report.md"
  format: |
    # Figma Audit Report

    **Audit ID:** {audit_id}
    **Date:** {date}
    **Mode:** {mode}
    **Figma:** {figma_url}
    **App:** {app_url}

    ## Scores
    | Phase | Visual | Property | UX | Average |
    |-------|--------|----------|----|---------|
    | Before (Phase 2) | {v1} | {p1} | {u1} | {avg1} |
    | After (Phase 4)  | {v2} | {p2} | {u2} | {avg2} |
    | Delta            | {dv} | {dp} | {du} | {davg} |

    ## Verdict: {PASS|PASS_WITH_ISSUES|ISSUES_FOUND}

    ## Node Map Summary
    - Total Figma nodes: {N}
    - Mapped (high confidence): {N}
    - Built (new): {N}
    - Fixed: {N}
    - Remaining issues: {N}

    ## Remaining Issues
    | # | Component | Property | Figma | Browser | Severity |

    ## Components Modified
    | # | Component | Mode | Properties Fixed | Commit |
```
```

- [ ] **Step 2: Commit**

```bash
git add v2.2/facades/figma-audit/SKILL.md
git commit -m "feat(figma-audit): Phase 4 verification + final report"
```

---

### Task 6: Update catalogs + sync global

**Files:**
- Modify: `v2.2/SKILLS_OVERVIEW.md`
- Modify: `AGENT.md`

- [ ] **Step 1: Add figma-audit to SKILLS_OVERVIEW.md facades table**

Add row:
```
| facades/figma-audit | ~250 | "проверь верстку", "figma audit", "/figma", "сравни с макетом" |
```

- [ ] **Step 2: Add /figma to commands table**

Add row:
```
| /figma | ~15 | Figma audit & implementation pipeline |
```

- [ ] **Step 3: Update AGENT.md commands section**

Add `/figma` to Review commands list.

- [ ] **Step 4: Sync to global**

```bash
mkdir -p ~/.claude/skills/figma-audit
cp v2.2/facades/figma-audit/SKILL.md ~/.claude/skills/figma-audit/SKILL.md
cp v2.2/commands/figma.md ~/.claude/commands/figma.md
```

- [ ] **Step 5: Verify sync**

```bash
diff v2.2/facades/figma-audit/SKILL.md ~/.claude/skills/figma-audit/SKILL.md
diff v2.2/commands/figma.md ~/.claude/commands/figma.md
```

- [ ] **Step 6: Commit**

```bash
git add v2.2/SKILLS_OVERVIEW.md AGENT.md
git commit -m "docs: add figma-audit to catalogs, sync global"
```

---

## Execution Order

```
Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6
(sequential — each task builds on the previous)
```

## Total: 6 tasks, ~25 steps
