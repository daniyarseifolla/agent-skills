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
