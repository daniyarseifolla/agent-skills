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
    purpose: "Identify reusable components — avoid reinventing"
    skip_if: "ui_inventory_path does not exist"

  step_2_design_context:
    skip_if: "no design_adapter or no figma_urls"
    action: "design_adapter.get_design(url) for each figma_url"
    output: "visual references, component mappings, design tokens"

  step_3_brainstorming:
    action: "Invoke Skill: brainstorming"
    input: "task + component inventory + tech-stack patterns + design context"
    output: "design decisions, approach options, selected approach"

  step_4_codebase_research:
    action: "Research existing code for patterns, dependencies, imports"
    S_M:
      method: "Direct Glob/Grep/Read"
      scope: "focused on known modules"
    L_XL:
      method: "Dispatch pipeline/code-researcher (haiku) via Task tool"
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
    format: |
      # {task-key} Checklist
      ## Implementation
      - [ ] Part 1: {description}
      - [ ] Part 2: {description}
      ## Verification
      - [ ] Lint passes
      - [ ] Tests pass
      - [ ] Build succeeds

  step_7_handoff:
    action: "Form handoff per core/orchestration planner_to_reviewer contract"
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

    ## Implementation Parts
    ### Part 1: {name}
    - Files: {list}
    - AC: {mapped AC numbers}
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
  method: "Task tool → pipeline/code-researcher"
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
