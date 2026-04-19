---
name: pipeline-architect
description: "Use when planner needs architectural analysis for M+ tasks, or when user invokes /arch for standalone consultation. Provides 3 competing approaches from different lenses with trade-off comparison."
human_description: "Запускает 3 агента-архитектора с разными линзами (conservative/balanced/challenger), каждый предлагает свой подход. Арбитр комбинирует лучшие элементы в финальное решение."
model: opus
---

# Pipeline Architect

Step 5 inside planner (Phase 5: plan). Proposes 3 architectural approaches through different lenses, then arbiter combines the best elements.

Skipped for S complexity. For M+ — mandatory.

---

## 1. Input

From planner step 4 (brainstorming) output + step 3 (research) output.

```yaml
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
    auto_approve: bool
    model: opus|sonnet
```

---

## 2. Three Architect Agents

Dispatched in parallel. Each receives identical input but different lens + freedom level.

```yaml
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

    [same context as agent_1]

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

    [same context as agent_1]
```

---

## 3. Agent Output Format

Each agent writes to `.tmp/`:

```yaml
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
```

---

## 4. Arbiter (Pipeline Mode)

4th agent (opus). Runs after 3 architect agents complete.

```yaml
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
```

---

## 5. Standalone Output (no arbiter)

```yaml
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
```

---

## 6. Runtime Artifacts

```yaml
artifacts:
  temporary:
    - "docs/plans/{task-key}/.tmp/arch-agent-1-conservative.md"
    - "docs/plans/{task-key}/.tmp/arch-agent-2-balanced.md"
    - "docs/plans/{task-key}/.tmp/arch-agent-3-challenger.md"
  final:
    - "docs/plans/{task-key}/architecture.md"
  cleanup: "Worker cleanup removes .tmp/ with other artifacts"
```
