---
name: figma-audit
description: "Figma audit & implementation pipeline. Generates consensus node map, compares visual + per-property + UX, fixes/builds via subagents, verifies with consensus review. Triggered by /figma command or phrases like 'проверь верстку', 'figma audit', 'сравни с макетом'."
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_press_key
---

# Figma Audit Pipeline

Full-cycle Figma design comparison and implementation. Orchestrates 4 phases: consensus node map → visual/property/UX comparison → implementation → verification.

---

## Phase 0: Preflight

```yaml
preflight:
  step_1_parse_url:
    action: "Extract fileKey and nodeId from Figma URL"
    url_patterns:
      - "figma.com/design/:fileKey/:fileName?node-id=:nodeId"
      - "figma.com/design/:fileKey/branch/:branchKey/:fileName"
    nodeId_fix: "Convert '-' to ':' in nodeId (e.g., '123-456' → '123:456')"
    branch_handling: "If branch URL → use branchKey as fileKey"

  step_2_detect_mode:
    action: "Determine audit mode based on inputs"
    checks:
      - "Glob project: *.component.ts, *.tsx, *.vue, *.svelte → set code_exists = true if any found"
      - "app_url provided in arguments? → set has_app_url = true"
    modes:
      audit_fix:
        condition: "has_app_url AND code_exists"
        phases: "0, 1, 2, 3, 4"
        description: "Compare Figma vs live app, fix mismatches in existing code"
      build:
        condition: "has_app_url AND NOT code_exists"
        phases: "0, 1, 3, 4"
        description: "Build new components from Figma design, then verify"
      audit_only:
        condition: "NOT has_app_url"
        phases: "0, 1, 2"
        description: "Map Figma nodes and compare without live browser (no fixes)"

  step_3_preflight_checks:
    figma_mcp:
      action: "Call get_metadata(fileKey)"
      on_success: "Set figma_mcp_available = true. Record file name and last_modified."
      on_failure: "HALT — show: 'Figma MCP unavailable. Check connection in Claude Code settings.'"
    browser_mcp:
      action: "If has_app_url → browser_navigate(app_url)"
      on_success: "Set browser_mcp_available = true"
      on_failure: "WARN: Browser MCP unavailable. Falling back to audit-only mode. Set has_app_url = false."

  step_4_confirm:
    display: |
      Figma Audit Pipeline
      ─────────────────────────────────
      Mode:       {mode}
      Figma:      {figma_url}
      Frame ID:   {nodeId}
      File:       {figma_file_name} (last modified: {last_modified})
      App URL:    {app_url | 'not provided'}
      Components: {component_count} files found in project
      Phases:     {phase_list}
      Output dir: docs/figma-audit/{audit_id}/
      ─────────────────────────────────
    action: "Ask user: 'Proceed with audit? (y/n)' — HALT if user says no"

  step_5_create_output_dir:
    audit_id_rules:
      - "If Jira task key available in context (e.g., ARGO-1234) → use it as audit_id"
      - "Else → generate: figma-{YYYY-MM-DD}-{HHMMSS}"
    action: "Bash: mkdir -p docs/figma-audit/{audit_id}/.tmp/"
    confirm: "Write docs/figma-audit/{audit_id}/audit-meta.yaml with mode, figma_url, app_url, audit_id, date"
```

---

## Phase 1: Consensus Node Map

3 agents in parallel, each mapping Figma nodes to code from a different angle. Requires Phase 0 to complete.

```yaml
node_map:
  dispatch: "Launch all 3 agents using Agent tool — Agents 2 and 3 start immediately, Agent 1 starts after 15s delay"

  rate_limiting:
    strategy: "Agent 1 is the heaviest Figma caller (get_design_context on full tree). Delay it 15s to avoid rate-limit contention."
    note: "Max 5 get_design_context calls per minute per adapter-figma rate limits"
    per_call_limit: "Max 5 get_design_context per minute"

  agent_1_structure:
    name: "structure-mapper"
    model: sonnet
    delay: "15 seconds before launch"
    budget: "max 30 tool calls"
    prompt: |
      You are the Structure Mapper agent for a Figma audit (Phase 1).

      Inputs:
      - Figma fileKey: {fileKey}
      - Figma nodeId: {nodeId}
      - Project root: {project_root}
      - Output path: docs/figma-audit/{audit_id}/.tmp/node-map-structure.md

      Your job: map the Figma component tree to project component files.

      Steps:
      1. Call get_design_context(fileKey, nodeId) — extract the full component tree
         - Prefer one parent-level call over multiple child calls (rate limit optimization)
         - From the response, extract all leaf/component nodes: name, type, CSS properties
      2. For each component node found:
         - Glob the project: *.component.ts, *.tsx, *.vue, *.svelte
         - Match Figma layer name → component filename
           (e.g., "CardHeader" → card-header.component.ts, CardHeader.tsx)
         - Match Figma layer name → likely CSS selector
           (e.g., "CardHeader" → .card-header, app-card-header, [data-card-header])
         - Assign confidence: HIGH (exact match), MEDIUM (partial match), LOW (no match)
      3. Build a mapping table:

      | node-id | figma-name | figma-type | component-file | selector-guess | confidence |
      |---------|------------|------------|----------------|----------------|------------|

      4. List any Figma nodes with NO matching component file as: UNMAPPED

      Write full output (table + unmapped list) to:
      docs/figma-audit/{audit_id}/.tmp/node-map-structure.md

      Budget: max 30 tool calls. Stop when complete.

  agent_2_visual:
    name: "visual-matcher"
    model: sonnet
    skip_when: "audit-only mode (has_app_url = false) — skip entirely, write empty file"
    budget: "max 30 tool calls"
    prompt: |
      You are the Visual Matcher agent for a Figma audit (Phase 1).

      Inputs:
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - App URL: {app_url}
      - Output path: docs/figma-audit/{audit_id}/.tmp/node-map-visual.md

      Your job: map Figma nodes to DOM elements using visual screenshot comparison.

      Steps:
      1. get_screenshot(fileKey, nodeId) → capture Figma screenshot
      2. browser_navigate(app_url) → browser_take_screenshot → capture browser screenshot
      3. Visually compare the two screenshots:
         - Identify which DOM regions correspond to which Figma node by position/shape
         - For each matched region, use browser_evaluate to extract a stable CSS selector:
           ```js
           const el = document.elementFromPoint(x, y);
           function getSelector(el) {
             if (el.dataset.testid) return `[data-testid="${el.dataset.testid}"]`;
             if (el.id) return `#${el.id}`;
             const path = [];
             let node = el;
             while (node && node !== document.body) {
               const parent = node.parentElement;
               if (!parent) break;
               const idx = Array.from(parent.children).indexOf(node) + 1;
               path.unshift(`${node.tagName.toLowerCase()}:nth-child(${idx})`);
               node = parent;
             }
             return path.join(' > ');
           }
           return getSelector(el);
           ```
      4. Build mapping table:

      | node-id | figma-name | css-selector | bbox-x | bbox-y | confidence |
      |---------|------------|--------------|--------|--------|------------|

      bbox-confidence: HIGH (clear visual match), MEDIUM (approximate), LOW (guess)

      Write output to:
      docs/figma-audit/{audit_id}/.tmp/node-map-visual.md

      Budget: max 30 tool calls.

  agent_3_code:
    name: "code-scanner"
    model: sonnet
    budget: "max 30 tool calls"
    prompt: |
      You are the Code Scanner agent for a Figma audit (Phase 1).

      Inputs:
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - Project root: {project_root}
      - Output path: docs/figma-audit/{audit_id}/.tmp/node-map-code.md

      Your job: enumerate all project components and match them to Figma layer names.

      Steps:
      1. Glob the project:
         - *.component.ts → extract @Component({ selector: '...' }) values
         - *.tsx, *.jsx → extract component function/class names
         - *.vue → extract component name from <script> or filename
         - *.svelte → use filename
         For each: record { component-file, selector, scss-file (if co-located) }
      2. Check for docs/ui-inventory.md — if present, read it for shared component catalog
      3. Call get_design_context(fileKey, nodeId) → extract Figma layer names from tree
      4. Match: Figma layer names ↔ component selectors and filenames
         - Normalize both sides: lowercase, remove hyphens/underscores, strip suffixes (.component, etc.)
         - Classify each component:
           MAPPED   — Figma layer + code component both found, match confident
           UNMAPPED — Figma layer exists, no code component found
           ORPHANED — Code component exists, not found in Figma tree
      5. Build mapping table:

      | component-file | selector | figma-node-id | figma-name | status |
      |----------------|----------|---------------|------------|--------|

      Write output to:
      docs/figma-audit/{audit_id}/.tmp/node-map-code.md

      Budget: max 30 tool calls.

  aggregation:
    trigger: "After all 3 agents complete (or agent_2 skipped in audit-only)"
    steps:
      - read: "Read all 3 files: .tmp/node-map-structure.md, .tmp/node-map-visual.md, .tmp/node-map-code.md"
      - merge_logic: |
          For each Figma node-id:
          - Mapped by 2+ agents → confidence: HIGH
          - Mapped by 1 agent only → confidence: LOW
          - Not mapped by any agent → status: UNMAPPED (build target in build/audit+fix mode)
          For each code component:
          - Not found in any agent map → status: ORPHANED
      - confidence_guard:
          threshold: "30% of total nodes must be HIGH confidence"
          on_fail: |
            HALT — show the partial map to user:
            "Only {N}% of Figma nodes mapped with high confidence (threshold: 30%).
            The design tree may be complex or component naming differs significantly.
            Review the partial map below and either:
            a) Confirm to proceed anyway
            b) Provide component naming conventions for a retry
            c) Cancel"
          on_pass: "Proceed to write final node map"
      - output_format: |
          # Figma Node Map
          **Audit ID:** {audit_id}
          **Generated:** {datetime}
          **Mode:** {mode}

          ## Summary
          | Metric | Count |
          |--------|-------|
          | Total Figma nodes | {N} |
          | High confidence mapped | {N} ({%}) |
          | Low confidence mapped | {N} ({%}) |
          | Unmapped (build targets) | {N} |
          | Orphaned code components | {N} |

          ## Node Map
          | node-id | figma-name | figma-type | component-file | css-selector | confidence | status |
          |---------|------------|------------|----------------|--------------|------------|--------|

          ## Unmapped Figma Nodes (Build Targets)
          | node-id | figma-name | figma-type | reason |
          |---------|------------|------------|--------|

          ## Orphaned Code Components
          | component-file | selector | reason |
          |----------------|----------|--------|
    output: "docs/figma-audit/{audit_id}/figma-node-map.md"
    cleanup: "Bash: rm -rf docs/figma-audit/{audit_id}/.tmp/ — ONLY after figma-node-map.md is written and confirmed"
```

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
    budget: "max 40 tool calls, 8 min"
    prompt: |
      You are the Visual Comparator for Figma audit Phase 2.

      Inputs:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - Figma fileKey: {fileKey}, nodeId: {nodeId}
      - App URL: {app_url}
      - Output path: docs/figma-audit/{audit_id}/.tmp/comparison-visual.md

      Steps:
      1. Read figma-node-map.md → get list of frames/components
      2. For each frame:
         a. get_screenshot(fileKey, frame_nodeId) → Figma screenshot
         b. browser_take_screenshot at matching viewport → browser screenshot
         c. Compare: spacing rhythm, alignment, visual hierarchy, color consistency
      3. Repeat at 3 viewports:
         - Desktop: browser_resize(1440, 900) → take_screenshot
         - Tablet:  browser_resize(768, 1024) → take_screenshot
         - Mobile:  browser_resize(375, 812)  → take_screenshot
      4. Score each frame 1-10 per viewport
      5. Load Skill: visual-qa if available (on_unavailable: score based on manual comparison)

      Output format:
      ## Visual Comparison
      | Frame | Desktop | Tablet | Mobile | Score | Findings |
      |-------|---------|--------|--------|-------|----------|

      Overall score: average of all frame scores.
      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-visual.md
      Budget: max 40 tool calls.

  agent_2_property:
    name: "property-auditor"
    model: sonnet
    budget: "max 40 tool calls, 8 min"
    prompt: |
      You are the Property Auditor for Figma audit Phase 2.

      Inputs:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - App URL: {app_url}
      - Output path: docs/figma-audit/{audit_id}/.tmp/comparison-properties.md

      Steps:
      1. Read figma-node-map.md → list of MAPPED components with CSS selectors
      2. browser_navigate(app_url)
      3. For each mapped component:
         a. Get Figma CSS values from node map (or call get_design_context if needed)
         b. browser_evaluate: `window.getComputedStyle(document.querySelector('{selector}'))`
         c. Compare property-by-property:
            - font-size, font-weight, line-height, letter-spacing
            - color, background-color, border, border-radius
            - padding-top, padding-right, padding-bottom, padding-left
            - margin, gap, width, height
            - flex-direction, justify-content, align-items
            - box-shadow, opacity
         d. Tolerance policy:
            - spacing (padding, margin, gap, width, height): ±0px
            - colors: exact hex match
            - font-weight: exact match
            - font-size: ±0px
            - border-radius: ±1px (subpixel rendering)
         e. Classify each property: OK | MISMATCH | MISSING
      4. Score: (OK_count / total_properties) * 10

      Output format:
      | Component | Property | Figma | Browser | Status |
      |-----------|----------|-------|---------|--------|

      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-properties.md
      Budget: max 40 tool calls.

  agent_3_ux:
    name: "ux-reviewer"
    model: sonnet
    budget: "max 40 tool calls, 8 min"
    prompt: |
      You are the UX/Interaction Reviewer for Figma audit Phase 2.

      Inputs:
      - figma-node-map.md at: docs/figma-audit/{audit_id}/figma-node-map.md
      - App URL: {app_url}
      - Output path: docs/figma-audit/{audit_id}/.tmp/comparison-ux.md

      Steps:
      1. Read figma-node-map.md → identify interactive components
      2. browser_navigate(app_url)
      3. For each interactive component:
         a. browser_hover → browser_take_screenshot (hover state)
         b. browser_press_key Tab → check focus-visible (focus state)
         c. Test disabled state if applicable
         d. Test loading state if async
      4. Responsive: browser_resize to each breakpoint → browser_take_screenshot
         - 375px, 768px, 1024px, 1440px
         - Check for overflow, broken layouts, hidden content
      5. Accessibility:
         - browser_evaluate contrast ratios for text/background pairs
         - Check focus order (Tab sequence makes sense)
         - browser_snapshot → inspect aria-labels, roles
      6. Load Skill: ui-ux-pro-max if available (on_unavailable: basic checks only)
      7. Score 1-10 per category: states, responsive, accessibility
         Overall score: average of 3 categories.

      Write to: docs/figma-audit/{audit_id}/.tmp/comparison-ux.md
      Budget: max 40 tool calls.

  aggregation:
    trigger: "After all 3 agents complete"
    steps:
      - read: "Read all 3 files: .tmp/comparison-visual.md, .tmp/comparison-properties.md, .tmp/comparison-ux.md"
      - consensus_logic: |
          For each finding:
          - Reported by 2+ agents → confirmed
          - Reported by 1 agent only → flag as lower confidence
          - Agents explicitly disagree → flag as conflict for user
      - scoring: "Overall score = average of 3 agent scores (visual + property + UX)"
      - verdict:
          PASS: "score ≥8.5 — implementation matches design"
          PASS_WITH_ISSUES: "score 7.0–8.4 — minor deviations"
          ISSUES_FOUND: "score <7.0 — significant mismatches"
    property_diff_serialization:
      action: "Parse comparison-properties.md → structured YAML for Phase 3 subagents"
      format: |
        components:
          - selector: "app-card .header"
            mismatches:
              - { property: font-size, figma: 16px, browser: 14px }
            ok_count: 12
            mismatch_count: 1
      output: "docs/figma-audit/{audit_id}/property-diff.yaml"
    output: "docs/figma-audit/{audit_id}/figma-comparison.md"
    cleanup: "Bash: rm -rf docs/figma-audit/{audit_id}/.tmp/ — ONLY after figma-comparison.md and property-diff.yaml are written"
```

---

## Phase 3: Implementation

Triggered in audit+fix and build modes. Skipped in audit-only. Phase 2 COMPLETE → Phase 3 → all COMPLETE → reload gate → Phase 4.

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
      - "Self-Verify: load figma-coding-rules Section 2 — compare every CSS property against Figma"
      - "Update figma-verify.md → no MISMATCH rows for this component"
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
      1. RESEARCH_FIRST: Read closest_pattern — understand project conventions before writing any code
      2. {if fix} Read current component, fix each MISMATCH using exact Figma values
         {if build} Create component from scratch: .ts + .html + .scss using Figma extract + pattern
      3. Self-Verify: load Skill figma-coding-rules Section 2
         - Compare EVERY CSS property against Figma values
         - flex-direction MUST be verified explicitly
      4. Commit gate: figma-verify.md must have ZERO MISMATCH rows for this component before committing
      5. git commit -m "figma-{mode}: {component_name}"

      Output (write to stdout):
      component_file: {path}
      properties_fixed: {N}
      properties_remaining: {N}
      commit_hash: {hash}

    on_timeout: "Mark component as UNVERIFIED in implementation-summary.md, proceed to reload gate"

  after_all_complete:
    collect: "Read all subagent outputs + inline fix results"
    output: "docs/figma-audit/{audit_id}/implementation-summary.md"
    format: |
      # Implementation Summary

      **Audit ID:** {audit_id}
      **Phase 3 completed:** {datetime}

      | Component | Mode | Properties Fixed | Properties Remaining | Status | Commit |
      |-----------|------|-----------------|---------------------|--------|--------|
```

---

## Reload Gate

Runs after all Phase 3 fixes/builds complete, before Phase 4.

```yaml
reload_gate:
  step_1:
    action: "Confirm all Phase 3 subagents and inline fixes are complete"
    condition: "implementation-summary.md written"
  step_2:
    action: "Run tech_stack_adapter.commands.build"
    on_failure: "HALT — show build errors, ask user to fix before proceeding"
  step_3:
    check: "Hot-reload detected? (watch for browser auto-refresh or server log)"
    on_hot_reload: "Proceed automatically to Phase 4"
    on_no_hot_reload: "Prompt user: 'Please restart your dev server, then confirm when ready.'"
  step_4:
    action: "Wait for user confirmation"
    prompt: "Dev server restarted and app is running? (y/n)"
    on_confirm: "Proceed to Phase 4"
    on_deny: "HALT — wait for user to resolve"
```

---

## Phase 4: Consensus Verification

Same 3 agents as Phase 2, re-run after fixes. Phase 3 must be fully complete before Phase 4 starts.

```yaml
verification:
  dispatch: "Same as Phase 2 — reuse agent prompts with updated context"
  prerequisite: "implementation-summary.md written AND reload gate confirmed"
  input_change: "Agents compare AFTER implementation (new browser state post-reload)"

  agents:
    agent_1_visual:
      name: "visual-comparator"
      model: sonnet
      prompt: "Same as Phase 2 agent_1_visual — compare updated browser screenshots vs Figma"
      budget: "max 40 tool calls, 8 min"

    agent_2_property:
      name: "property-auditor"
      model: sonnet
      prompt: "Same as Phase 2 agent_2_property — re-evaluate computed CSS properties after fixes"
      budget: "max 40 tool calls, 8 min"

    agent_3_ux:
      name: "ux-reviewer"
      model: sonnet
      prompt: "Same as Phase 2 agent_3_ux — re-check states, responsive, accessibility after fixes"
      budget: "max 40 tool calls, 8 min"

  additional_output:
    before_score: "Phase 2 overall average score"
    after_score: "Phase 4 overall average score"
    delta: "after_score - before_score"
    remaining_mismatches: "list of MISMATCH rows still present from property auditor"

  aggregation:
    steps:
      - "Read all 3 Phase 4 agent outputs"
      - "Consensus: 2+ agents agree → confirmed finding"
      - "Conflicts: flag for user"
      - "Compute after_score = average of 3 agent scores"
      - "Compute delta = after_score - before_score"
      - "Collect remaining_mismatches from Phase 4 property auditor"
    output: "docs/figma-audit/{audit_id}/figma-verification.md"

  verdict:
    PASS: "after_score ≥8.5 — implementation matches design"
    PASS_WITH_ISSUES: "after_score 7.0–8.4 — minor deviations remain"
    ISSUES_FOUND: "after_score <7.0 — significant mismatches remain"

  no_reloop: "Phase 4 runs ONCE. User decides on remaining issues — no automatic re-entry."
```

---

## Final Report

Generated after Phase 4 completes (or after Phase 2 in audit-only mode).

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

    ---

    ## Scores

    | Phase | Visual | Property | UX | Average |
    |-------|--------|----------|----|---------|
    | Before (Phase 2) | {v1} | {p1} | {u1} | {avg1} |
    | After (Phase 4)  | {v2} | {p2} | {u2} | {avg2} |
    | Delta            | {dv} | {dp} | {du} | {davg} |

    ## Verdict: {PASS|PASS_WITH_ISSUES|ISSUES_FOUND}

    ---

    ## Node Map Summary

    | Metric | Count |
    |--------|-------|
    | Total Figma nodes | {total} |
    | Mapped (high confidence) | {mapped} |
    | Built (new components) | {built} |
    | Fixed | {fixed} |
    | Remaining issues | {remaining} |

    ---

    ## Remaining Issues

    | # | Component | Property | Figma | Browser | Severity |
    |---|-----------|----------|-------|---------|----------|

    ---

    ## Components Modified

    | # | Component | Mode | Properties Fixed | Commit |
    |---|-----------|------|-----------------|--------|
```
