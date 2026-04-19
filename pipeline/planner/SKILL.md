---
name: pipeline-planner
description: "Use when researching codebase and creating implementation plan with AC mapping. Called by worker Phase 5: plan."
human_description: "Исследует кодовую базу, запускает архитектора (M+), создаёт детальный план реализации с маппингом AC, файлами, сигнатурами."
model: opus
---

# Pipeline Planner

Phase 5: plan. Researches codebase, runs architect (M+), produces implementation plan. AC-driven, adapter-aware.

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
  architect_roles_adapter: "loaded architect-roles adapter (null if no role adapter)"
  ui_inventory_path: ".claude/ui-inventory.md (if exists)"
  task_analysis_path: "docs/plans/{task-key}/task-analysis.md (from Phase 3: research, null for S complexity)"
  impact_report_path: "docs/plans/{task-key}/impact-report.md (from Phase 4: impact)"
  flags:
    auto_approve: bool    # --arch-auto, passed from worker
    architect_model: opus|sonnet  # --model, passed from worker
    mode: "full|architect-only"   # architect-only for standalone /arch
```

---

## 1b. Task Analysis Context

```yaml
task_analysis:
  when: "task_analysis_path is not null"
  action: "Read task-analysis.md BEFORE any research"
  provides:
    screens: "Figma screens with node-ids, types, states — becomes basis for Implementation Parts"
    api: "API endpoints with schemas — informs service design and model creation"
    flows: "User flows — informs component wiring, routing, and navigation"
    gaps: "Missing/broken endpoints — documented as risks/blockers in plan"
    api_strategy: "real|mock — affects service implementation approach"
  skip_step_2: "If task-analysis.md has '## Figma Screens' section → skip step_2_design_context entirely"
  reason: "Phase 3: research already explored all Figma frames. Re-scanning wastes tokens and API calls."
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

  step_1b_impact:
    action: "Read impact-report.md from Phase 4: impact"
    mandatory: true
    input: "impact_report_path"
    use_for:
      must_fix: "Each must-fix item becomes a separate Implementation Part in the plan"
      must_verify: "Each must-verify item is added to the Test Plan section"
      risk_areas: "Noted in plan's risk/known-issues section"
    example: |
      If impact report says:
        Must-Fix: postImagesChange missing disableGoOut()
        Must-Fix: postFilesChange missing disableGoOut()
      Then plan gets:
        Part N: Fix sibling defects from impact report
        - Files: edit-post.component.ts
        - Fix postImagesChange: add this.outgoResolverService.disableGoOut()
        - Fix postFilesChange: add this.outgoResolverService.disableGoOut()

  step_2_design_context:
    skip_if: "no design_adapter or no figma_urls OR (task_analysis_path exists AND task-analysis.md contains '## Figma Screens')"
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

  step_3_consensus_research:
    activation: "complexity >= M"
    fallback_for_S: "Skip consensus, do direct Glob/Grep/Read inline"
    MANDATORY: "Do NOT skip. Do NOT do inline research instead. Dispatch 3 agents."
    action: "3 research agents in parallel — gather maximum information before planning"
    dispatch: "Use Skill: superpowers:dispatching-parallel-agents"

    agent_1_codebase:
      name: "codebase-researcher"
      model: opus
      subagent_type: "general-purpose"
      angle: "Find ALL existing components, services, patterns relevant to this task"
      steps:
        - "Read task-analysis.md → understand screens and flows"
        - "Glob for components matching entity name (e.g., *news*, *post*, *dialog*)"
        - "For each found component: Read .ts, .html, .scss — extract patterns"
        - "Find the CLOSEST existing feature to copy (e.g., existing CRUD dialog)"
        - "Read shared SCSS: variables, mixins, design tokens"
        - "Read ui-inventory.md if exists"
      output: "docs/plans/{task-key}/.tmp/research-codebase.md"
      format: |
        ## Codebase Research
        ### Closest Existing Feature
        {feature_name}: {files} — can be used as template
        ### Relevant Components
        | Component | Path | Reusable? | Notes |
        ### SCSS Patterns
        | Variable/Mixin | Value | Usage |
        ### Verdict: SUCCESS | PARTIAL | FAILED

    agent_2_dependencies:
      name: "dependency-mapper"
      model: sonnet
      subagent_type: "general-purpose"
      angle: "Map all dependencies: routing, imports, services, state management"
      steps:
        - "Read task-analysis.md → understand endpoints and data flow"
        - "Find existing routing config → what routes exist, where to add new"
        - "Find existing services → which API calls already exist"
        - "Find state management → signals/store patterns for this entity"
        - "Find module/import structure → where new components should be declared"
      output: "docs/plans/{task-key}/.tmp/research-dependencies.md"
      format: |
        ## Dependency Map
        ### Routing
        Current routes: {list}. New route needed: {path}
        ### Services
        Existing: {list}. New needed: {list}
        ### State Management
        Pattern: {signals|ngrx|behaviorsubject}. Existing state for entity: {yes|no}
        ### Module Structure
        Target module: {path}. Import chain: {chain}
        ### Verdict: SUCCESS | PARTIAL | FAILED

    agent_3_ux_flow:
      name: "ux-flow-analyst"
      model: opus
      subagent_type: "general-purpose"
      angle: "Map Figma screens → concrete implementation steps with AC coverage"
      steps:
        - "Read task-analysis.md → screens, flows, gaps, API schemas"
        - "For each user flow: screen → user action → component → API call → next screen"
        - "For each AC: which screen(s) + which component(s) implement it"
        - "For each form: Figma fields → Swagger schema fields → validation rules"
        - "Identify: what can be done with existing code, what's new"
      output: "docs/plans/{task-key}/.tmp/research-ux-flow.md"
      format: |
        ## UX Flow Analysis
        ### Flow → Implementation Map
        | # | Flow | Screen | Component | Endpoint | New/Existing |
        ### AC → Component Map
        | AC | Screen | Component | Endpoint | Status |
        ### Form → Schema Map
        | Field | Figma Type | Schema Type | Validation |
        ### Verdict: SUCCESS | PARTIAL | FAILED

    aggregation:
      after: "All 3 agents complete"
      check_verdicts: "Any FAILED → WARN, continue with partial data"
      merge: "Read .tmp/research-*.md → combine into unified research context"
      cleanup: "Keep .tmp/ until plan written (cleanup at step_8)"
      output: "Merged research feeds directly into brainstorming + plan creation"

  step_4_brainstorming:
    action: "Invoke Skill: brainstorming"
    input: "task + task-analysis.md + merged research from step_3 agents"
    output: "design decisions, approach options, selected approach"
    brainstorming_focus:
      - "Which existing components can be reused? (from codebase-researcher)"
      - "What new components are needed? (from ux-flow-analyst)"
      - "What is the minimal approach to satisfy all AC?"
      - "What are the risks and edge cases? (from dependency-mapper)"

  step_5_architect:
    activation: "complexity >= M AND mode != architect-only"
    skip_if: "complexity == S OR no architect_roles_adapter"
    action: "Load Skill: pipeline-architect"
    input:
      task: "pass-through"
      brainstorming_output: "from step_4"
      research_output: "from step_3 agents"
      generated_context: "from architect_roles_adapter.generated_context"
      role_adapter: "architect_roles_adapter"
      tech_stack_adapter: "pass-through"
      flags:
        auto_approve: "from input flags"
        model: "from input flags.architect_model"
    output: "docs/plans/{task-key}/architecture.md"
    on_architecture_md_exists: |
      Plan creation (step_7) reads architecture.md as primary design input.
      Planner does NOT reconsider architectural decisions — it concretizes them.
      If planner spots a problem → writes to known_risks, does not change approach.

  step_5b_architect_only:
    activation: "mode == architect-only (standalone /arch)"
    action: "Load Skill: pipeline-architect in standalone mode"
    input: "same as step_5_architect"
    output: "Display 3 approaches + comparison (no arbiter)"
    after: "STOP — do not proceed to plan creation"

  step_6_codebase_research_fallback:
    note: "Only for S complexity (consensus skipped). M+ use step_3 agents."
    skip_if: "complexity >= M (already done via consensus agents)"
    action: "Research existing code for patterns, dependencies, imports"
    method: "Direct Glob/Grep/Read"
    scope: "focused on known modules"
    output: "relevant files, patterns, import graph"

  step_7_plan_creation:
    action: "Invoke Skill: superpowers:writing-plans"
    output_path: "docs/plans/{task-key}/plan.md"
    architecture_input:
      when: "architecture.md exists (M+ with architect)"
      action: "Read architecture.md — use chosen approach as basis for plan"
      planner_role: "Translate approach into implementation parts, order, commits"
      planner_does_not: "Reconsider architectural decisions"
      on_problem: "Write to known_risks. Plan-reviewer catches it."
    when_no_architecture:
      action: "Use brainstorming output directly (S complexity)"
    required_sections:
      - context: "Task summary, AC list, links"
      - scope: "Files to create, files to modify"
      - architecture: "Design decisions from brainstorming"
      - parts: "Implementation parts in dependency order"
      - ac_mapping: "AC -> implementation part(s)"
      - test_plan: "What to test, how"
      - "Component states (for each UI component: which states to implement)"
      - impact_items: "Must-fix and must-verify items from impact-report.md"
      - config_changes: "Environment, routing, module config (if any)"

  step_8_checklist:
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

  step_9_handoff:
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
    - States: {list ALL states needed: default, hover, disabled, loading, empty, error}
    - Dependencies: {other parts}
    - Signatures: {key method/interface/model definitions for this part}
    - Details: {what to implement}

  signatures_requirement: |
    Each Implementation Part MUST include Signatures with:
    - Method names and their parameters/return types
    - Interface/model shapes (fields and types)
    - Service method signatures if creating/modifying services
    Example:
      Signatures:
        - NotificationService.send(userId: string, message: NotificationPayload): Observable<void>
        - NotificationPayload: { title: string, body: string, type: 'info'|'warning'|'error' }
        - NotificationListComponent: inputs: [notifications: Signal<Notification[]>], outputs: [dismiss: EventEmitter<string>]
    WHY: Coder (sonnet) needs concrete targets, not prose descriptions. Reduces REVISE/RETURN rate.

    ## AC Mapping
    | AC # | Description | Part(s) | How Satisfied |
    How Satisfied column: one sentence per AC describing the concrete mechanism (not just "Part 2")

    ## Test Plan
    {test scenarios, coverage targets}

    ## Impact-Driven Items
    | # | Type | File | Description | Plan Part |
    |---|------|------|-------------|-----------|
    | 1 | must-fix | {file} | {description} | Part {N} |
    | 2 | must-verify | {file} | {description} | Test Plan |

    ## Config Changes
    {routing, modules, environment — if any}
```

---

## 5. Research Delegation (L/XL)

```yaml
code_researcher_dispatch:
  when: "complexity in [L, XL]"
  method: "Agent tool → pipeline-code-researcher"
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
  CRITICAL: |
    These constraints are mandatory for every plan. Violations are BLOCKER in plan-review.
  rules:
    - "Each task = one logical commit"
    - "Map every AC to at least one task"
    - "Include exact file paths (create/modify)"
    - "Include build/lint verification step per task"
    - "NEVER modify library/node_modules code — read-only"
    - "Use path aliases from tech-stack adapter"
```
