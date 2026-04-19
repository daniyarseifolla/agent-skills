# Architect Skill + Pipeline v4.0 Restructure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add architect capability (3 agents + arbiter + arch-review) and restructure pipeline from fractional phases to clean 1-9 naming with repo layout cleanup.

**Architecture:** Architect lives as a step inside planner (Phase 5). Role adapter provides stack-specific lenses. Standalone facades for `/arch` and `/arch-review`. Pipeline phases renumbered 1-9 with named checkpoints. v3/ flattened to root, v1/ deleted.

**Tech Stack:** Markdown SKILL.md files (this is a skills repo, not code). YAML for config/data.

**Spec:** `docs/superpowers/specs/2026-04-18-architect-and-pipeline-v4-design.md`

---

### Task 1: Repo Layout — Flatten v3/ to Root, Delete v1/

**Files:**
- Delete: `v1/` (entire directory)
- Move: `v3/*` → repo root (pipeline/, adapters/, core/, facades/, commands/, SKILLS_OVERVIEW.md)
- Create: `VERSION`

- [ ] **Step 1: Delete v1/ entirely**

```bash
rm -rf v1/
```

- [ ] **Step 2: Move v3/ contents to root**

```bash
# Move each top-level directory/file from v3/ to root
mv v3/pipeline/ ./pipeline/
mv v3/adapters/ ./adapters/
mv v3/core/ ./core/
mv v3/facades/ ./facades/
mv v3/commands/ ./commands/
mv v3/SKILLS_OVERVIEW.md ./SKILLS_OVERVIEW.md
```

- [ ] **Step 3: Move remaining v3/ files**

Any markdown files at v3/ root that aren't part of the new structure (REPORT.md, CONSENSUS-REVIEW-*.md, REFACTOR-v3.md, README.md) — move to `docs/archive/`:

```bash
mkdir -p docs/archive/
mv v3/*.md docs/archive/  # remaining markdown files
rmdir v3/  # should be empty now
```

- [ ] **Step 4: Create VERSION file**

Create `VERSION` at repo root:
```
4.0
```

- [ ] **Step 5: Update CLAUDE.md**

Replace version references. Remove v3/ path prefix mentions. Update quick reference table to use new paths (without v3/).

Key changes:
- Remove "v3/ — active version" and "v1/ — archived"
- Update to "Version 4.0 — see VERSION file"
- Remove path prefixes (e.g., `v3/SKILLS_OVERVIEW.md` → `SKILLS_OVERVIEW.md`)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: flatten v3/ to root, delete v1/ — repo layout v4.0"
```

---

### Task 2: Core Orchestration — Rename Phases 1-9

**Files:**
- Modify: `core/orchestration/SKILL.md`

- [ ] **Step 1: Rewrite phase_sequence**

Replace the entire `phase_sequence` section with:

```yaml
phase_sequence:
  - { id: 1,  name: analyze,     model: sonnet, mode: inline,            action: "classify complexity, select route" }
  - { id: 2,  name: setup,       model: sonnet, mode: inline,            action: "worktree, CI disable, dev server, confirmation" }
  - { id: 3,  name: research,    model: opus,   mode: inline,            action: "Figma + API + functional map", skip_when: "complexity == S" }
  - { id: 4,  name: impact,      model: sonnet, mode: inline,            action: "consumers, siblings, shared code → impact-report.md" }
  - { id: 5,  name: plan,        model: opus,   mode: inline,            action: "brainstorming + architect (M+) + plan creation" }
  - { id: 6,  name: plan-review, model: opus,   mode: subagent,          action: "validate plan (consensus 3x3 opus for M+)", skip_when: "complexity == S" }
  - { id: 7,  name: implement,   model: sonnet, mode: inline,            action: "evaluate gate, then implement" }
  - { id: 8,  name: review,      model: sonnet, mode: subagent_worktree, action: "code-review + ui-review parallel" }
  - { id: 9,  name: ship,        model: sonnet, mode: inline,            action: "push, MR, deploy, transition, notify" }
```

- [ ] **Step 2: Remove phase_id_normalization**

Delete the entire `phase_id_normalization` section — no longer needed since IDs are clean integers 1-9.

- [ ] **Step 3: Update complexity_matrix route_definitions**

```yaml
route_definitions:
  MINIMAL:  { phases: [1, 2, 4, 5, 7, 8, 9],          note: "skip research, plan-review. Phase 8 ui-review conditional." }
  STANDARD: { phases: [1, 2, 3, 4, 5, 6, 7, 8, 9],    note: "all phases, ui-review conditional on design adapter" }
  FULL:     { phases: [1, 2, 3, 4, 5, 6, 7, 8, 9],    note: "all phases, all tools enabled" }
```

- [ ] **Step 4: Update checkpoint_schema**

Replace `completed_phases` type from `number[]` to named phases:

```yaml
checkpoint_schema:
  completed: "string[] — e.g. [analyze, setup, research]. Named phases, append-only."
  resume: "string|null — named phase to execute next. Primary source for recovery."
  invalidated: "string[] — phases whose results are stale."
  # Remove: completed_phases, resume_phase (old names)
  # Keep all other fields unchanged
```

- [ ] **Step 5: Update next_phase_map**

```yaml
next_phase_map:
  analyze: setup
  setup: research     # or impact if complexity == S (research skipped)
  research: impact
  impact: plan
  plan: plan-review   # or implement if complexity == S (plan-review skipped)
  plan-review: implement
  implement: review
  review: ship
  ship: null          # done
```

- [ ] **Step 6: Update invalidation_rules**

Replace numeric phases with named:

```yaml
invalidation_rules:
  code_review_loop:
    trigger: "review verdict == CHANGES_REQUESTED"
    invalidated: [review]
    resume: implement

  plan_review_loop:
    trigger: "plan-review verdict == NEEDS_CHANGES"
    invalidated: [plan-review]
    resume: plan

  evaluate_return:
    trigger: "implement evaluate gate verdict == RETURN"
    invalidated: [implement]
    resume: plan-review
```

- [ ] **Step 7: Update loop_limits counter paths**

Replace `checkpoint.iteration.plan_review` → keep as-is (iteration counters are not phase names).

- [ ] **Step 8: Update recovery_heuristic**

Replace all "(worker 0.8)" references with named phases:

```yaml
recovery_heuristic:
  - { task_analysis: yes, plan: no, resume: "impact" }
  - { plan: no, resume: "impact" }
  - { plan: yes, evaluate: no, code: no, resume: "implement" }
  - { plan: yes, evaluate: yes, code: no, resume: "implement" }
  - { plan: yes, code: yes, resume: "review" }
```

- [ ] **Step 9: Update confirmation_gates and any remaining numeric references**

Search entire file for patterns like "Phase 0", "Phase 1", etc. Replace with named equivalents.

- [ ] **Step 10: Commit**

```bash
git add core/orchestration/SKILL.md
git commit -m "refactor(orchestration): phases 1-9 with named checkpoints"
```

---

### Task 3: Pipeline Worker — Update Phase Dispatch

**Files:**
- Modify: `pipeline/worker/SKILL.md`

- [ ] **Step 1: Update Startup section**

Replace all phase references: `Phase 0` → `Phase 1: analyze`, etc. Update step_7_route to reference new phase names.

- [ ] **Step 2: Update Confirmation Summary**

Replace "Phase 0 output" → "Phase 1: analyze output". Update worktree reference from Phase 0.5 → Phase 2: setup.

- [ ] **Step 3: Update Pipeline Execution section**

Rewrite entire phases list. Each phase entry:
- Replace `phase: 0` → `phase: 1`, `name: task-analysis` → `name: analyze`
- Replace `phase: 0.5` → `phase: 2`, `name: workspace-setup` → `name: setup`
- Replace `phase: 0.7` → `phase: 3`, `name: deep-analysis` → `name: research`
- Replace `phase: 0.8` → `phase: 4`, `name: impact-analysis` → `name: impact`
- Replace `phase: 1` → `phase: 5`, `name: planning` → `name: plan`
  - Add note: "Includes architect step for M+ (see planner SKILL.md step 5)"
- Replace `phase: 2` → `phase: 6`, `name: plan-review` → `name: plan-review`
- Replace `phase: 3` → `phase: 7`, `name: implementation` → `name: implement`
- Replace `phase: "4+5"` → `phase: 8`, `name: review`
  - Keep parallel dispatch of code-reviewer + ui-reviewer
- Replace `phase: 6` → `phase: 9`, `name: ship`

- [ ] **Step 4: Update checkpoint_rules within phases**

Replace all `completed_phases: [...existing, 4, 5]` → `completed: [...existing, review]` style.
Replace all `resume_phase: 3` → `resume: implement` style.
Replace all `invalidated_phases: [4, 5]` → `invalidated: [review]` style.

- [ ] **Step 5: Update Phase Dispatch section (section 3)**

Replace numeric phase references in before_phase/after_phase/on_loop.

- [ ] **Step 6: Update Autodetect section (section 4)**

No phase references here — no changes needed. Verify.

- [ ] **Step 7: Update Error Handling section (section 5)**

Replace any phase number references.

- [ ] **Step 8: Update Re-routing section (section 6)**

Replace `[after_phase_1, after_phase_2]` → `[after_plan, after_plan-review]`.

- [ ] **Step 9: Add --arch-auto flag**

In the startup/flag parsing section, add:

```yaml
flags:
  --arch-auto: "Pass auto_approve=true to planner's architect step"
  --model: "Override model for architect agents (opus|sonnet)"
```

- [ ] **Step 10: Update description frontmatter**

Change description to remove "Phase 0-6" mentions if any.

- [ ] **Step 11: Commit**

```bash
git add pipeline/worker/SKILL.md
git commit -m "refactor(worker): phases 1-9, named checkpoints, --arch-auto flag"
```

---

### Task 4: New — Pipeline Architect Skill

**Files:**
- Create: `pipeline/architect/SKILL.md`

- [ ] **Step 1: Create directory**

```bash
mkdir -p pipeline/architect/
```

- [ ] **Step 2: Write SKILL.md**

Create `pipeline/architect/SKILL.md` with:

```markdown
---
name: pipeline-architect
description: "Architectural analysis: 3 agents with different lenses propose approaches, arbiter combines. Step inside planner (Phase 5) for M+. Also standalone via /arch."
model: opus
---

# Pipeline Architect

Step 5 inside planner (Phase 5). Proposes 3 architectural approaches through different lenses, then arbiter combines the best elements.

Skipped for S complexity. For M+ — mandatory.

---

## 1. Input

From planner step 4 (brainstorming) output + step 3 (research) output.

\```yaml
input:
  task:
    title: string
    description: string
    acceptance_criteria: string[]
    figma_urls: string[]
  brainstorming_output: "problem space analysis from step 4"
  research_output: "codebase research from step 3"
  generated_context:
    task_analysis_path: "docs/plans/{task-key}/task-analysis.md"
    impact_report_path: "docs/plans/{task-key}/impact-report.md"
    ui_inventory_path: ".claude/ui-inventory.md"
    practices_path: ".claude/project-practices.md"
  role_adapter: "loaded architect-roles adapter"
  tech_stack_adapter: "for codebase research methods"
  flags:
    auto_approve: bool    # --arch-auto
    model: opus|sonnet    # --model override
\```

---

## 2. Three Architect Agents

Dispatched in parallel. Each receives identical input but different lens + freedom level.

\```yaml
dispatch:
  method: "Use Skill: superpowers:dispatching-parallel-agents"
  model: "flags.model (default: opus)"
  agents: 3

agent_1:
  lens: "role_adapter.roles.lens_1"
  freedom: conservative
  instruction: |
    You are {lens.name} with CONSERVATIVE freedom.
    Propose an architectural approach STRICTLY within existing project patterns.
    Show the best solution using what already exists.
    Do not introduce new dependencies, patterns, or abstractions.

    Context:
    - Task: {task.title} — {task.description}
    - AC: {task.acceptance_criteria}
    - Research: {research_output}
    - Brainstorming: {brainstorming_output}
    - Stack constraints: {role_adapter.stack_constraints}

    Your lens focus: {lens.focus}
    Research codebase via: {lens.codebase_research}
    Read generated context files if they exist.

    Output format: see section 3.

agent_2:
  lens: "role_adapter.roles.lens_2"
  freedom: balanced
  instruction: |
    You are {lens.name} with BALANCED freedom.
    Use current patterns as foundation.
    May propose targeted improvements if benefit is clear.
    For each deviation from current patterns — justify the cost.

    [same context block as agent_1]

agent_3:
  lens: "role_adapter.roles.lens_3"
  freedom: challenger
  instruction: |
    You are {lens.name} with CHALLENGER freedom.
    Propose an alternative approach. You MUST indicate:
    - Which files the migration would touch
    - How much this adds to task scope
    - Why the current approach is worse
    - What happens if we DON'T do this now

    [same context block as agent_1]
\```

---

## 3. Agent Output Format

Each agent writes to `.tmp/`:

\```yaml
output_path: "docs/plans/{task-key}/.tmp/arch-agent-{N}-{freedom}.md"

format: |
  ## Approach: {lens_name} ({freedom_level})

  ### Summary
  {2-3 sentences — essence of the approach}

  ### Architecture
  - Component structure: ...
  - Data flow: ...
  - Key decisions: ...

  ### Files
  - Create: {list with purpose}
  - Modify: {list with change description}

  ### Trade-offs
  | Pro | Con |
  |-----|-----|
  | ... | ... |

  ### Cost Estimate
  - Complexity vs current approach: +0% / +20% / +50%
  - Migration debt: none / low / medium

  ### Verdict: SUCCESS | PARTIAL | FAILED
\```

---

## 4. Arbiter (Pipeline Mode)

4th agent (opus). Runs after 3 architect agents complete.

\```yaml
arbiter:
  activation: "pipeline mode (called from planner step 5)"
  skip_in: "standalone mode (user sees all 3 and picks)"
  model: opus

  input: "3 approach files from .tmp/"
  action: |
    1. Read all 3 approach files
    2. Compare by: AC coverage, cost, risk, innovation
    3. Combine best decisions from different approaches
    4. Justify selection of each element
    5. If challenger proposes something valuable — include with cost note

  overengineering_filter:
    BLOCKER_if:
      - "Introduces abstraction for a single use case"
      - "Adds >30% to task scope without proportional benefit"
      - "Proposes pattern not supported by tech-stack adapter"

  output: "docs/plans/{task-key}/architecture.md"

  confirmation:
    if_auto_approve_false: |
      Show architecture.md to user:
      "Рекомендованный архитектурный подход (из элементов подходов 1, 2, 3):
       {summary}
       Proceed? (y / edit / show alternatives)"
      Options:
        y: proceed to plan creation
        edit: user modifies, max 3 edits
        show alternatives: display all 3 original approaches
    if_auto_approve_true: "Proceed directly to plan creation"
\```

---

## 5. Standalone Output (no arbiter)

\```yaml
standalone:
  activation: "called from /arch facade"
  arbiter: "skip — user sees all 3"

  output: |
    Show all 3 approaches + comparison table:

    ## Approach 1: {lens_name} (Conservative)
    {full approach}

    ## Approach 2: {lens_name} (Balanced)
    {full approach}

    ## Approach 3: {lens_name} (Challenger)
    {full approach}

    ## Comparison
    | Criteria        | Approach 1 | Approach 2 | Approach 3 |
    |-----------------|-----------|-----------|-----------|
    | AC coverage     | ...       | ...       | ...       |
    | Cost vs current | +0%       | +15%      | +40%      |
    | Risk            | low       | medium    | medium    |
    | Innovation      | none      | moderate  | high      |

  after_display: "User selects / discusses / asks questions"
  optional_save: "Save chosen approach to architecture.md"
\```

---

## 6. Runtime Artifacts

\```yaml
artifacts:
  temporary:
    - "docs/plans/{task-key}/.tmp/arch-agent-1-conservative.md"
    - "docs/plans/{task-key}/.tmp/arch-agent-2-balanced.md"
    - "docs/plans/{task-key}/.tmp/arch-agent-3-challenger.md"
  final:
    - "docs/plans/{task-key}/architecture.md"
  cleanup: "Worker cleanup removes .tmp/ with other artifacts"
\```
```

Note: Escape the triple backticks in the actual file (the `\``` ` above are escapes for this plan — write real triple backticks in the file).

- [ ] **Step 3: Commit**

```bash
git add pipeline/architect/
git commit -m "feat(architect): new pipeline skill — 3 agents + arbiter"
```

---

### Task 5: New — Role Adapter

**Files:**
- Create: `adapters/architect-roles/SKILL.md`
- Create: `adapters/architect-roles/angular.yaml`
- Create: `adapters/architect-roles/generic.yaml`

- [ ] **Step 1: Create directory**

```bash
mkdir -p adapters/architect-roles/
```

- [ ] **Step 2: Write SKILL.md (adapter contract)**

Create `adapters/architect-roles/SKILL.md`:

```markdown
---
name: adapter-architect-roles
description: "Architect role adapter. Provides stack-specific lenses for architect agents. Loaded by planner when architect step runs."
disable-model-invocation: true
---

# Architect Roles Adapter

Defines 3 lenses per tech stack for architect agents. Each lens has a name, focus area, and codebase research method.

## Contract

\```yaml
type: architect-roles

provides:
  roles:
    lens_1: { name: string, focus: string, codebase_research: string }
    lens_2: { name: string, focus: string, codebase_research: string }
    lens_3: { name: string, focus: string, codebase_research: string }
  stack_constraints: string[]
  generated_context: string[]

consumes:
  tech_stack_adapter: "for codebase research methods referenced in codebase_research"

loading:
  method: "Read YAML file matching detected stack"
  lookup: "adapters/architect-roles/{stack}.yaml"
  fallback: "adapters/architect-roles/generic.yaml"
  override: "--stack flag from /arch or pipeline"
\```

## Adapter Files

| File | Stack | Lenses |
|------|-------|--------|
| angular.yaml | Angular/Nx | Component, State & Data, Integration |
| generic.yaml | Any (fallback) | Structure, Data, Quality |
```

- [ ] **Step 3: Write angular.yaml**

Create `adapters/architect-roles/angular.yaml`:

```yaml
stack: angular

generated_context:
  - "docs/plans/{task-key}/task-analysis.md"
  - "docs/plans/{task-key}/impact-report.md"
  - ".claude/ui-inventory.md"
  - ".claude/project-practices.md"

roles:
  lens_1:
    name: "Component Architect"
    focus: |
      UI decomposition: standalone components, projection, host directives,
      reuse of existing components, lazy loading
    codebase_research: "tech_stack_adapter.module_lookup"

  lens_2:
    name: "State & Data Architect"
    focus: |
      Signals, computed, linkedSignal, httpResource,
      services vs component state, caching, optimistic updates
    codebase_research: "tech_stack_adapter.patterns + tech_stack_adapter.api_discovery"

  lens_3:
    name: "Integration Architect"
    focus: |
      Forms, error handling, loading states, guards,
      interceptors, a11y, responsive
    codebase_research: "tech_stack_adapter.patterns"

stack_constraints:
  - "Standalone components only (no NgModules)"
  - "Signals over BehaviorSubject for new code"
  - "OnPush change detection"
```

- [ ] **Step 4: Write generic.yaml**

Create `adapters/architect-roles/generic.yaml`:

```yaml
stack: "*"

generated_context:
  - "docs/plans/{task-key}/task-analysis.md"
  - "docs/plans/{task-key}/impact-report.md"

roles:
  lens_1:
    name: "Structure Architect"
    focus: "modules, components, layers, separation of concerns"
    codebase_research: "Glob + Grep for project structure"

  lens_2:
    name: "Data Architect"
    focus: "state management, data flow, API integration, caching"
    codebase_research: "Glob + Grep for services and state"

  lens_3:
    name: "Quality Architect"
    focus: "performance, error handling, edge cases, resilience"
    codebase_research: "Glob + Grep for error patterns"

stack_constraints: []
```

- [ ] **Step 5: Commit**

```bash
git add adapters/architect-roles/
git commit -m "feat(adapter): architect-roles — angular + generic lenses"
```

---

### Task 6: Modify Planner — Add Architect Step

**Files:**
- Modify: `pipeline/planner/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Change: `"Called by pipeline/worker Phase 1."` → `"Called by pipeline/worker Phase 5: plan."`

- [ ] **Step 2: Update header**

Change: `Phase 1. Researches codebase, produces implementation plan.` → `Phase 5: plan. Researches codebase, runs architect (M+), produces implementation plan.`

- [ ] **Step 3: Add architect to input section**

Add to input yaml:

```yaml
  architect_roles_adapter: "loaded architect-roles adapter (null if no role adapter)"
  flags:
    auto_approve: bool    # --arch-auto, passed from worker
    architect_model: opus|sonnet  # --model, passed from worker
    mode: "full|architect-only"   # architect-only for standalone /arch
```

- [ ] **Step 4: Insert architect step between brainstorming and plan creation**

After current `step_4_brainstorming`, add new `step_5_architect`:

```yaml
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
      Plan creation (step_6) reads architecture.md as primary design input.
      Planner does NOT reconsider architectural decisions — it concretizes them.
      If planner spots a problem → writes to known_risks, does not change approach.

  step_5b_architect_only:
    activation: "mode == architect-only (standalone /arch)"
    action: "Load Skill: pipeline-architect in standalone mode"
    input: "same as step_5_architect"
    output: "Display 3 approaches + comparison (no arbiter)"
    after: "STOP — do not proceed to plan creation"
```

- [ ] **Step 5: Update plan creation step**

Current `step_6_plan_creation` (renumber from step_5 to step_6 since architect is now step_5):

Add conditional input:

```yaml
  step_6_plan_creation:
    # ... existing content ...
    architecture_input:
      when: "architecture.md exists (M+ with architect)"
      action: "Read architecture.md — use chosen approach as basis for plan"
      planner_role: "Translate approach into implementation parts, order, commits"
      planner_does_not: "Reconsider architectural decisions"
      on_problem: "Write to known_risks. Plan-reviewer catches it."
    when_no_architecture:
      action: "Use brainstorming output directly (S complexity)"
```

- [ ] **Step 6: Renumber remaining steps**

- Current step_5 → step_6 (plan creation) — if not already
- Current step_6 → step_7 (checklist)
- Current step_7 → step_8 (handoff)

- [ ] **Step 7: Update all internal phase references**

Replace "Phase 1" → "Phase 5: plan" in any comments/references within the file.

- [ ] **Step 8: Commit**

```bash
git add pipeline/planner/SKILL.md
git commit -m "feat(planner): add architect step for M+ tasks"
```

---

### Task 7: New — Facades and Commands

**Files:**
- Create: `facades/architect/SKILL.md`
- Create: `facades/arch-review/SKILL.md`
- Create: `commands/arch.md`
- Create: `commands/arch-review.md`

- [ ] **Step 1: Create facades/architect/SKILL.md**

```markdown
---
name: architect
description: "Standalone architectural analysis. Proposes 3 approaches from different lenses with trade-off comparison. Use when user says /arch, \"архитектурный совет\", \"предложи архитектуру\", \"как лучше спроектировать\", \"какой подход выбрать\"."
---

# Architect — Facade

Standalone architectural consultation. Launches 3 architect agents with stack-specific lenses, shows comparison.

## Activation

Triggers:
- `/arch` command
- "архитектурный совет", "предложи архитектуру"
- "как лучше спроектировать", "какой подход выбрать"
- "architect advice", "architectural perspective"

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| --stack | Override tech-stack detection | autodetect |
| --model | Override agent model | opus |

## Input Variants

| Variant | Example |
|---------|---------|
| With task key | `/arch ARGO-12345` — fetch from Jira |
| With description | `/arch "notification system with websocket"` |
| Bare | `/arch` — ask user what to architect |

## Delegation

1. Determine tech stack:
   - If `--stack` flag → use it
   - Else: read `.claude/project.yaml`
   - Else: autodetect from package.json etc.

2. Load adapters:
   - tech-stack adapter (for codebase research)
   - architect-roles adapter (for lenses)

3. If task key provided:
   - Load task-source adapter
   - Fetch task (title, AC, description, Figma URLs)

4. Run brainstorming:
   - Invoke `superpowers:brainstorming` to explore problem space

5. Invoke planner in architect-only mode:
   ```yaml
   Skill: pipeline-planner
   mode: architect-only
   ```
   This runs steps 3-5 only (research + brainstorming + architect).
   Shows 3 approaches + comparison table. No arbiter.

6. User interaction:
   - User selects / discusses / asks questions
   - Optional: save chosen approach to `architecture.md`
```

- [ ] **Step 2: Create facades/arch-review/SKILL.md**

```markdown
---
name: arch-review
description: "Retrospective architectural review. 3 reviewers analyze code → 3 alternatives proposed. Use when user says /arch-review, \"оцени архитектуру\", \"review architecture\", \"как улучшить архитектуру\"."
---

# Arch-Review — Facade

Post-implementation or existing code architectural analysis. Sequential: 3 review agents → 3 alternative agents.

## Activation

Triggers:
- `/arch-review` command
- "оцени архитектуру", "review architecture"
- "как улучшить архитектуру", "архитектурный ревью"
- "предложи улучшения к коду"

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| --stack | Override tech-stack detection | autodetect |
| --model | Override agent model | opus |
| --scope | Path or module to focus on | auto-detect from git diff |

## Input Variants

| Variant | Example |
|---------|---------|
| After task | `/arch-review ARGO-12345` — review completed task |
| Existing code | `/arch-review src/features/notifications` — review module |
| Bare | `/arch-review` — ask user what to review |

## Flow

### Phase A: Review (3 agents parallel)

1. Load role adapter (same lenses as /arch)
2. Determine scope:
   - If task key → `git diff develop...HEAD` for changed files
   - If path → that directory
   - If bare → ask user
3. Dispatch 3 review agents in parallel
4. Each reviews code through their lens (review mode, not proposal mode)
5. Aggregate: consensus findings (2+ agents agree)

Review agent instruction template:
\```yaml
instruction: |
  You are {lens.name} in REVIEW mode.
  Analyze existing code through your lens.
  Find: over-abstractions, under-abstractions, pattern violations,
  missed reuse opportunities, unnecessary complexity.
  Rate: 1-10 per area.
  Output: structured findings with severity (BLOCKER/MAJOR/MINOR).
\```

Output per agent: `docs/plans/{scope}/.tmp/review-agent-{N}.md`

### Phase B: Alternatives (3 agents parallel)

Input: aggregated review findings from Phase A.

1. Dispatch 3 alternative agents with freedom gradient:
   - Agent 1: Conservative — fix within current patterns
   - Agent 2: Balanced — targeted improvements, justify cost
   - Agent 3: Challenger — alternative architecture + migration plan

Alternative agent instruction template:
\```yaml
agent_1_conservative:
  instruction: |
    Review findings: {aggregated_findings}
    For each finding — propose a fix within current patterns.
    No new dependencies, no new abstractions.
    Show: what to change, estimated effort, risk.

agent_2_balanced:
  instruction: |
    Review findings: {aggregated_findings}
    For each finding — propose improvement, may introduce targeted changes.
    Justify cost of each deviation.

agent_3_challenger:
  instruction: |
    Review findings: {aggregated_findings}
    Propose alternative architecture for the reviewed code.
    May suggest significant refactoring if justified.
    MUST include: migration plan, effort estimate, what breaks during migration.
\```

Output per agent: `docs/plans/{scope}/.tmp/alt-agent-{N}.md`

### Display

Show review report + 3 alternatives + comparison:

\```markdown
## Architectural Review: {scope}

### Review Summary
| Area | Score | Key Finding |
|------|-------|-------------|
| {lens_1} | 7/10 | {finding} |
| {lens_2} | 5/10 | {finding} |
| {lens_3} | 8/10 | {finding} |

### Consensus Findings (2+ agents agree)
| # | Finding | Severity | Agents | Impact |

### Alternative 1: Conservative
{targeted fixes}

### Alternative 2: Balanced
{improvements with justified deviations}

### Alternative 3: Challenger
{alternative architecture + migration plan}

### Comparison
| Criteria | Alt 1 | Alt 2 | Alt 3 |
|----------|-------|-------|-------|
| Effort   | low   | medium | high |
| Risk     | none  | low    | medium |
| Improvement | incremental | moderate | significant |
\```
```

- [ ] **Step 3: Create commands/arch.md**

```markdown
---
description: "Standalone architectural analysis. Usage: /arch [ARGO-12345] [--stack=angular] [--model=sonnet]"
---

# Architect

Arguments: $ARGUMENTS

1. Load Skill: architect (facade)
2. Pass arguments and flags
3. Facade handles stack detection, adapter loading, agent dispatch

If no arguments provided, ask user what to architect.
```

- [ ] **Step 4: Create commands/arch-review.md**

```markdown
---
description: "Retrospective architectural review. Usage: /arch-review [ARGO-12345|path] [--stack=angular] [--model=sonnet]"
---

# Arch-Review

Arguments: $ARGUMENTS

1. Load Skill: arch-review (facade)
2. Pass arguments and flags
3. Facade handles scope detection, review agents, alternative agents

If no arguments provided, ask user what to review.
```

- [ ] **Step 5: Commit**

```bash
git add facades/architect/ facades/arch-review/ commands/arch.md commands/arch-review.md
git commit -m "feat: /arch and /arch-review facades + commands"
```

---

### Task 8: Update Existing Pipeline Skills — Phase References

**Files:**
- Modify: `pipeline/plan-reviewer/SKILL.md`
- Modify: `pipeline/coder/SKILL.md`
- Modify: `pipeline/code-reviewer/SKILL.md`
- Modify: `pipeline/ui-reviewer/SKILL.md`
- Modify: `pipeline/impact-analyzer/SKILL.md`
- Modify: `pipeline/code-researcher/SKILL.md`
- Modify: `core/consensus-review/SKILL.md`
- Modify: `core/metrics/SKILL.md`
- Modify: `core/security/SKILL.md`
- Modify: `pipeline/figma-coding-rules/SKILL.md`

For each file, the changes are the same pattern:

- [ ] **Step 1: Update pipeline/plan-reviewer/SKILL.md**

- Description: `"Called by pipeline/worker Phase 2."` → `"Called by pipeline/worker Phase 6: plan-review."`
- Header: `Phase 2.` → `Phase 6: plan-review.`
- Any body references to "Phase 1" → "Phase 5: plan", "Phase 3" → "Phase 7: implement"

- [ ] **Step 2: Update pipeline/coder/SKILL.md**

- Description: `"Called by pipeline/worker Phase 3."` → `"Called by pipeline/worker Phase 7: implement."`
- Header: `Phase 3.` → `Phase 7: implement.`
- Any references to "Phase 2" → "Phase 6: plan-review", "Phase 4" → "Phase 8: review"

- [ ] **Step 3: Update pipeline/code-reviewer/SKILL.md**

- Description: `"Called by pipeline/worker Phase 4."` → `"Called by pipeline/worker Phase 8: review."`
- Header: `Phase 4.` → `Phase 8: review.`
- References to "Phase 3" → "Phase 7: implement", "Phase 6" → "Phase 9: ship"

- [ ] **Step 4: Update pipeline/ui-reviewer/SKILL.md**

- Header/description references to Phase 5 → Phase 8: review (part of parallel review)
- Any "Phase 4+5" references → "Phase 8: review"

- [ ] **Step 5: Update pipeline/impact-analyzer/SKILL.md**

- Description: `"Called by pipeline/worker Phase 0.8."` → `"Called by pipeline/worker Phase 4: impact."`
- Header: `Phase 0.8.` → `Phase 4: impact.`

- [ ] **Step 6: Update pipeline/code-researcher/SKILL.md**

- Any phase references in description or body.

- [ ] **Step 7: Update core/consensus-review/SKILL.md**

- References like "Phase 4", "Phase 5", "Phase 2" → new names
- Section "integration" → update pipeline_worker phase references

- [ ] **Step 8: Update core/metrics/SKILL.md**

- Remove or update phase_id_normalization references
- Phase IDs are now clean 1-9, no normalization needed

- [ ] **Step 9: Update core/security/SKILL.md**

- Minimal — check for any phase references.

- [ ] **Step 10: Update pipeline/figma-coding-rules/SKILL.md**

- Any references to "Phase 3" → "Phase 7: implement" or coder phase.

- [ ] **Step 11: Also check AGENT.md and README.md at repo root**

- If they reference v3/ paths or old phase numbers → update.

- [ ] **Step 12: Commit**

```bash
git add pipeline/ core/
git commit -m "refactor: update all pipeline/core skills to phases 1-9"
```

---

### Task 9: Update Facades and Commands — Phase References

**Files:**
- Modify: `facades/jira-worker/SKILL.md`
- Modify: `facades/ship/SKILL.md`
- Modify: `facades/deploy/SKILL.md`
- Modify: `facades/figma-audit/SKILL.md`
- Modify: `facades/community-sync/SKILL.md`
- Modify: `facades/scan-ui-inventory/SKILL.md`
- Modify: `facades/scan-qa-playbook/SKILL.md`
- Modify: `facades/scan-practices/SKILL.md`
- Modify: `commands/attach.md`
- Modify: `commands/continue.md`
- Modify: `commands/progress.md`
- Modify: `commands/plan.md`
- Modify: All other commands/*.md

- [ ] **Step 1: Update facades/jira-worker/SKILL.md**

- "Phase 1 (Planning)" → "Phase 5: plan"
- Any other phase references

- [ ] **Step 2: Update facades/ship/SKILL.md**

- "Phase 6" → "Phase 9: ship" in description
- Any "Extracted from Phase 6" → "Extracted from Phase 9: ship"

- [ ] **Step 3: Update facades/deploy/SKILL.md, community-sync/SKILL.md**

- Check for phase references, update if found.

- [ ] **Step 4: Update facades/figma-audit/SKILL.md**

- Check for phase references, update if found.

- [ ] **Step 5: Update commands/attach.md — CRITICAL**

This file has the most phase references. Update:
- "Phase 0.7 (deep analysis)" → "Phase 3: research"
- "Phase 0.8 (impact analysis)" → "Phase 4: impact"
- "Phase 3 (analysis skipped)" → "Phase 7: implement"
- "Phase 4 (review)" → "Phase 8: review"
- "Phase 6 (completion)" → "Phase 9: ship"
- All `completed_phases` arrays in checkpoint examples: `[0, 1, 3]` → `[analyze, plan, implement]`
- All `resume_phase: 6` → `resume: ship`
- Classification table states: update all phase references
- "Phase 2-5: Run Missing Phases" → "Phase 6-8: Run Missing Phases"

- [ ] **Step 6: Update commands/continue.md, progress.md, plan.md**

- continue.md: any phase references
- progress.md: any phase references
- plan.md: "Phase 0" → "Phase 1: analyze", "Phase 1" → "Phase 5: plan"

- [ ] **Step 7: Update remaining commands**

Quick scan of: cr.md, code-review.md, ui-review.md, ship.md, deploy.md, sync.md, cleanup.md, scan-ui.md, scan-qa.md, scan-practices.md, verify-figma.md, figma.md

Most are simple wrappers — verify no phase references.

- [ ] **Step 8: Commit**

```bash
git add facades/ commands/
git commit -m "refactor: update all facades/commands to phases 1-9"
```

---

### Task 10: Rewrite SKILLS_OVERVIEW.md

**Files:**
- Modify: `SKILLS_OVERVIEW.md`

- [ ] **Step 1: Rewrite architecture diagram**

Replace the ASCII diagram with updated structure (no v3/ prefix, architect in pipeline, architect-roles in adapters).

- [ ] **Step 2: Rewrite Skill Catalog tables**

Update all tables:
- Pipeline: add architect skill, update phase numbers for all skills
- Adapters: add architect-roles
- Facades: add architect, arch-review
- Commands: add /arch, /arch-review

- [ ] **Step 3: Rewrite Pipeline Phases table**

New table with phases 1-9, named phases, models.

- [ ] **Step 4: Update Complexity Routing table**

Include architect row (skip for S, yes for M+).

- [ ] **Step 5: Update Adapter Contracts**

Add architect-roles contract to the list.

- [ ] **Step 6: Update Project Configuration section**

No v3/ prefix in paths.

- [ ] **Step 7: Update Output Files section**

Add architecture.md and arch-agent-*.md to artifacts list.

- [ ] **Step 8: Update all remaining sections**

Superpowers Integration, External Skill Dependencies, MCP Dependencies — verify no stale references.

- [ ] **Step 9: Commit**

```bash
git add SKILLS_OVERVIEW.md
git commit -m "docs: rewrite SKILLS_OVERVIEW.md for v4.0"
```

---

### Task 11: Final — Update CLAUDE.md and Verify

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md**

- Version reference: "v3/" → "Version 4.0"
- Remove "v1/ — archived"
- Update quick reference table (add /arch, /arch-review triggers)
- Update "See SKILLS_OVERVIEW.md" link (remove v3/ prefix)
- Add architect and arch-review to trigger table

New quick reference rows:
```
| "архитектурный совет", /arch | architect | planner (architect step) |
| "оцени архитектуру", /arch-review | arch-review | 3 review → 3 alternatives |
```

- [ ] **Step 2: Verify all files**

Run a quick verification:
```bash
# Check no v3/ references remain in skill files
grep -r "v3/" pipeline/ adapters/ core/ facades/ commands/ SKILLS_OVERVIEW.md CLAUDE.md || echo "Clean"

# Check no old phase numbers (0.5, 0.7, 0.8) remain
grep -rn "Phase 0\." pipeline/ adapters/ core/ facades/ commands/ || echo "Clean"
grep -rn "phase: 0\." pipeline/ core/ || echo "Clean"

# Check new files exist
ls pipeline/architect/SKILL.md adapters/architect-roles/SKILL.md facades/architect/SKILL.md facades/arch-review/SKILL.md commands/arch.md commands/arch-review.md VERSION
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for v4.0"
```

- [ ] **Step 4: Final verification commit (if grep found issues)**

Fix any remaining stale references found in step 2.

```bash
git add -A
git commit -m "fix: remaining v3 and old phase references"
```
