---
name: pipeline-planner
description: "Planning phase: researches codebase, designs solution, creates implementation plan with AC mapping. Uses opus model for deep analysis. Called by pipeline/worker Phase 1."
model: opus
---

# Pipeline Planner

Phase 1. Researches codebase, produces implementation plan. AC-driven, adapter-aware.

---

## 1. Input

From worker handoff.

```yaml
input:
  task:
    title: string
    description: string
    acceptance_criteria: string[]
    figma_urls: string[]
    priority: string
  complexity: "S|M|L|XL"
  route: "MINIMAL|STANDARD|FULL"
  tech_stack_adapter: "loaded adapter for patterns/commands"
  design_adapter: "loaded adapter for Figma (optional, null if none)"
  ui_inventory_path: ".claude/ui-inventory.md (if exists)"
```

---

## 2. Mode Detection

```yaml
mode_detection:
  figma_first:
    condition: "task.description is empty AND task.figma_urls is non-empty"
    action: "Run figma-first workflow (section 6)"

  standard:
    condition: "task.description has content"
    action: "Normal planning workflow"

  standard_plus_figma:
    condition: "task.description has content AND task.figma_urls non-empty"
    action: "Normal planning + design context enrichment"
```

---

## 3. Workflow

```yaml
steps:
  step_1_component_discovery:
    action: "Read ui_inventory_path if exists"
    fallback_if_no_inventory:
      action: "Scan for shared components manually"
      commands:
        - "Glob: libs/shared/ui/**/*.component.ts"
        - "Glob: libs/shared/components/**/*.component.ts"
        - "Glob: libs/shared/dialogs/**/*.component.ts"
        - "Glob: **/shared/**/*.pipe.ts"
        - "Glob: **/*.mixins.scss"
        - "Glob: **/variables.scss"
      output: "Inline component list for brainstorming input"
    purpose: "Avoid reinventing existing components"

  step_2_design_context:
    skip_if: "no design_adapter or no figma_urls"
    action: "Extract Figma node map for EVERY UI component"
    CRITICAL: |
      For each Figma URL:
      1. Call get_design_context(fileKey, nodeId) → get screenshot + code hints
      2. Identify EVERY distinct UI component/element in the design
      3. For each component, record its Figma node-id
      4. Extract key CSS properties (dimensions, colors, typography, spacing)
      5. Build a Figma Node Map table for the plan
    output: "Figma Node Map table (component → node-id → key CSS properties)"
    node_map_format: |
      | Component | Figma Node ID | Key Properties |
      |-----------|---------------|----------------|
      | Card container | 123:456 | w:290px h:160px radius:12px bg:#F5F5F5 |
      | Card title | 123:457 | font:Inter/600/16px color:#1A1A1A |
      | Card image | 123:458 | w:290px h:100px radius:12px 12px 0 0 |
    WHY: "Without node-ids in the plan, coder will guess CSS values instead of extracting exact ones from Figma"

  step_3_brainstorming:
    action: "Invoke Skill: brainstorming"
    input: "task + component inventory + tech-stack patterns + design context"
    output: "design decisions, approach options, selected approach"
    brainstorming_focus:
      - "Which existing components can be reused? (MUST prefer existing over custom)"
      - "What new components are needed?"
      - "What is the minimal approach to satisfy all AC?"
      - "What are the risks and edge cases?"

  step_4_codebase_research:
    action: "Research existing code for patterns, dependencies, imports"
    S_M:
      method: "Direct Glob/Grep/Read"
      scope: "focused on known modules"
    L_XL:
      method: "Dispatch pipeline-code-researcher (haiku) via Task tool"
      queries:
        - "Find existing patterns for {feature_type}"
        - "Trace imports in {affected_modules}"
        - "Locate similar implementations"
    output: "relevant files, patterns, import graph"

  step_5_plan_creation:
    action: "Invoke Skill: superpowers:writing-plans"
    output_path: "docs/plans/{task-key}/plan.md"
    required_sections:
      - context: "Task summary, AC list, links"
      - scope: "Files to create, files to modify"
      - architecture: "Design decisions from brainstorming"
      - parts: "Implementation parts in dependency order"
      - ac_mapping: "AC -> implementation part(s)"
      - test_plan: "What to test, how"
      - config_changes: "Environment, routing, module config (if any)"

  step_6_checklist:
    action: "Generate checklist from plan parts"
    output_path: "docs/plans/{task-key}/checklist.md"
    format:
      full_mode: |
        ## Checklist: {task_key}

        ### Tasks
        - [ ] Task 1: {description} → AC: {ac_ids} → Commit: `feat(ARGO-XXXXX): {msg}`
        - [ ] Task 2: ...

        ### Verification
        - [ ] Lint passes
        - [ ] Tests pass
        - [ ] Build succeeds

        ### AC Coverage Map
        | AC | Task | Status |
        |----|------|--------|
        | AC-1 | Task 1 | planned |

      simple_mode: |
        ## Checklist: {task_key}
        - [ ] {single task description}
        - [ ] Build + lint passes

  step_7_handoff:
    action: "Form handoff per core-orchestration planner_to_reviewer contract"
    payload:
      artifact_path: "docs/plans/{task-key}/plan.md"
      key_decisions: "extracted from brainstorming step"
      known_risks: "identified during research"
      complexity: "pass-through from input"
```

---

## 4. Plan Format

```yaml
plan_template:
  path: "docs/plans/{task-key}/plan.md"
  structure: |
    # {task-key}: {task.title}

    ## Context
    {task summary, links, figma references}

    ## Acceptance Criteria
    {numbered list from task}

    ## Scope
    ### New Files
    {file list with purpose}
    ### Modified Files
    {file list with change description}

    ## Architecture Decisions
    {from brainstorming — decision, rationale, alternatives rejected}

    ## Figma Node Map (REQUIRED when Figma URLs present)
    | Component | Figma Node ID | Figma URL | Key CSS Properties |
    |-----------|---------------|-----------|-------------------|
    | Header | 123:456 | figma.com/design/xxx?node-id=123-456 | h: 64px, bg: #FFFFFF |
    | Card | 123:789 | figma.com/design/xxx?node-id=123-789 | w: 290px, h: 160px, radius: 12px |

    ## Implementation Parts
    ### Part 1: {name}
    - Files: {list}
    - AC: {mapped AC numbers}
    - Figma nodes: {node-ids from Figma Node Map for this part}
    - Dependencies: {other parts}
    - Details: {what to implement}

    ## AC Mapping
    | AC # | Description | Part(s) |

    ## Test Plan
    {test scenarios, coverage targets}

    ## Config Changes
    {routing, modules, environment — if any}
```

---

## 5. Research Delegation (L/XL)

```yaml
code_researcher_dispatch:
  when: "complexity in [L, XL]"
  method: "Task tool → pipeline-code-researcher"
  queries_generated_from:
    - "Affected modules from AC analysis"
    - "Pattern questions from brainstorming"
    - "Import chain questions for modified files"
  max_dispatches: 3
  merge: "Combine researcher outputs into research summary"
```

---

## 6. Figma-First Mode

```yaml
figma_first:
  when: "task.description is empty AND figma_urls present"
  ac_format: |
    Generated AC use "AC-F{N}" prefix:
    - AC-F1: Page /path displays [component] with [data]
    - AC-F2: Button [label] navigates to [destination]
    - AC-F3: [Component] shows states: loading, error, empty, populated
    - AC-F4: Form validates [fields] with [rules]
  steps:
    - extract: "design_adapter.get_design(url) for each URL"
    - analyze:
        components: "Identify visible UI components"
        interactions: "Buttons, inputs, links, toggles"
        states: "Loading, error, empty, populated"
        responsive: "Breakpoints if visible in variants"
    - generate_ac: "design_adapter.figma_first_mode output"
    - proceed: "Use generated AC as task.acceptance_criteria"
    - note: "Document in plan that AC were generated from Figma"
```

---

## 7. Plan Constraints

```yaml
plan_constraints:
  - "Each task = one logical commit"
  - "Map every AC to at least one task"
  - "Include exact file paths (create/modify)"
  - "Include build/lint verification step per task"
  - "Library code is read-only"
  - "Use path aliases from tech-stack adapter"
```
