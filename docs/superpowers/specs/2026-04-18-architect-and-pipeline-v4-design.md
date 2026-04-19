# Architect Skill + Pipeline v4.0 Restructure

**Date:** 2026-04-18
**Version:** 4.0
**Scope:** New architect capability + pipeline phase restructure + repo layout cleanup

---

## 1. Problem

Pipeline lacks an architectural perspective. Planner creates implementation plans but doesn't explore alternative approaches. For M+ tasks, architectural decisions are made implicitly inside brainstorming — no structured comparison, no trade-off analysis, no multi-perspective evaluation.

Additionally, pipeline phase numbering has accumulated fractional phases (0.5, 0.7, 0.8) making the system harder to understand and extend.

---

## 2. Goals

1. **Architect capability** — propose 3 architectural approaches from different lenses with trade-off analysis
2. **Arch-review capability** — retrospective architectural analysis: 3 reviewers → 3 alternative proposals
3. **Stack-adaptive roles** — architect lenses are tied to tech stack via role adapter
4. **Freedom gradient** — conservative / balanced / challenger to avoid both overengineering and stagnation
5. **Three modes** — standalone `/arch` (before code), pipeline step (during), `/arch-review` (after code)
6. **Clean pipeline** — rename phases to sequential numbers with semantic names, no fractional phases
7. **Repo cleanup** — flatten v3/ to root, delete v1/, add VERSION file

---

## 3. Pipeline v4.0 — New Phase Structure

### 3.1 Phase Map

```
Phase 1:  analyze     — classify task, determine complexity (S/M/L/XL)
Phase 2:  setup       — worktree, branch, CI toggle
Phase 3:  research    — deep analysis: Figma + API + functional flows
Phase 4:  impact      — consumers, siblings, shared code → impact-report.md
Phase 5:  plan        — brainstorming + architect + plan creation → plan.md
Phase 6:  plan-review — consensus 3×3 → verdict
Phase 7:  implement   — coder → commits
Phase 8:  review      — code-review + ui-review parallel
Phase 9:  ship        — push, MR, deploy, transition, notify
```

### 3.2 Migration Map (old → new)

| Old Phase | New Phase | Name |
|-----------|-----------|------|
| 0 | 1 | analyze |
| 0.5 | 2 | setup |
| 0.7 | 3 | research |
| 0.8 | 4 | impact |
| 1 | 5 (part of plan) | plan |
| 2 | 6 | plan-review |
| 3 | 7 | implement |
| 4+5 | 8 | review |
| 6 | 9 | ship |

### 3.3 Complexity Routing

| Phase | S | M | L/XL |
|-------|---|---|------|
| 1: analyze | yes | yes | yes |
| 2: setup | yes | yes | yes |
| 3: research | skip | yes | yes |
| 4: impact | yes | yes | yes |
| 5: plan | yes (no architect) | yes (with architect) | yes (with architect) |
| 6: plan-review | skip | yes (consensus) | yes (consensus) |
| 7: implement | yes | yes | yes |
| 8: review | 1 agent | consensus | consensus |
| 9: ship | yes | yes | yes |

### 3.4 Checkpoint Format

```yaml
# New format — named phases:
completed: [analyze, setup, research]
resume: impact

# Backward compat for /continue with old checkpoints:
# Worker detects numeric completed_phases → migrates via mapping
```

---

## 4. Architect Skill

### 4.1 Position in Pipeline

Architect is a **step inside planner** (Phase 5), not a separate pipeline phase.

Phase 5 (plan) internal flow:
```
step 1: component discovery        — find existing shared components
step 2: impact reading              — read impact-report.md
step 3: consensus research          — 3 agents explore codebase (M+)
step 4: brainstorming               — understand problem, constraints
step 5: architect                   — 3 approaches + arbiter (M+)
step 6: plan creation               — chosen approach → concrete plan
step 7: checklist + handoff
```

For S complexity: steps 3 and 5 are skipped (no consensus research, no architect).

### 4.2 Three Architect Agents

Dispatched in parallel. Each receives:
- Task (title, description, AC, figma_urls)
- Generated context (task-analysis.md, impact-report.md, ui-inventory.md, project-practices.md)
- Research output from step 3
- Brainstorming output from step 4
- Their lens from role adapter
- Their freedom level

```yaml
agent_1:
  freedom: conservative
  instruction: |
    Propose an approach STRICTLY within existing project patterns.
    Show the best solution using what already exists.
    Do not introduce new dependencies, patterns, or abstractions.

agent_2:
  freedom: balanced
  instruction: |
    Use current patterns as foundation.
    May propose targeted improvements if benefit is clear.
    For each deviation from current patterns — justify the cost.

agent_3:
  freedom: challenger
  instruction: |
    Propose an alternative approach. MUST indicate:
    - Which files the migration would touch
    - How much this adds to task scope
    - Why the current approach is worse
    - What happens if we DON'T do this now
```

### 4.3 Agent Output Format

Each agent produces:
```markdown
## Approach: {lens_name} ({freedom_level})

### Summary
{2-3 sentences — essence of the approach}

### Architecture
- Component structure: ...
- Data flow: ...
- Key decisions: ...

### Files
- Create: {list}
- Modify: {list}

### Trade-offs
| Pro | Con |
|-----|-----|
| ... | ... |

### Cost estimate
- Complexity vs current approach: +0% / +20% / +50%
- Migration debt: none / low / medium
```

### 4.4 Arbiter (Pipeline Mode)

4th agent (opus). Runs after 3 architect agents complete.

```yaml
arbiter:
  input: "3 approach files from .tmp/"
  action: |
    1. Compare 3 approaches by: AC coverage, cost, risk, innovation
    2. Combine best decisions from different approaches
    3. Justify selection of each element
    4. If challenger proposes something valuable — include with cost note
  output: "docs/plans/{task-key}/architecture.md"

  overengineering_filter:
    BLOCKER_if:
      - "Introduces abstraction for a single use case"
      - "Adds >30% to task scope without proportional benefit"
      - "Proposes pattern not supported by tech-stack adapter"
```

### 4.5 Pipeline Flags

```yaml
flags:
  --arch-auto:
    effect: "Arbiter selects approach → passes to plan creation without user confirmation"
    default: false
  --model:
    effect: "Override model for architect agents"
    values: [opus, sonnet]
    default: opus
```

### 4.6 Runtime Artifacts

```
docs/plans/{task-key}/
├── .tmp/arch-agent-1-conservative.md
├── .tmp/arch-agent-2-balanced.md
├── .tmp/arch-agent-3-challenger.md
├── architecture.md                    ← arbiter output (final approach)
```

---

## 5. Standalone Mode (`/arch`)

### 5.1 Triggers

```yaml
command: "/arch"
natural_language:
  - "architect advice", "architectural perspective"
  - "архитектурный совет", "предложи архитектуру"
  - "как лучше спроектировать", "какой подход выбрать"

flags:
  --stack: "override tech-stack detection (angular, react, go, python)"
  --model: "override model (opus|sonnet), default: opus"

input_variants:
  with_task_key: "/arch ARGO-12345"
  with_description: '/arch "notification system with websocket"'
  bare: "/arch — ask user what to architect"
```

### 5.2 Standalone Flow

```
1. Determine stack (--stack flag or autodetect)
2. Load role adapter
3. Brainstorming — understand task, constraints
4. 3 architect agents in parallel
5. Show all 3 approaches + comparison table
6. User selects / discusses / asks questions
7. (optional) Save chosen approach to architecture.md
```

### 5.3 Standalone Output

No arbiter. User sees all 3 approaches + comparison:

```markdown
## Approach 1: {lens_name} (Conservative)
{summary + architecture + trade-offs}

## Approach 2: {lens_name} (Balanced)
{summary + architecture + trade-offs}

## Approach 3: {lens_name} (Challenger)
{summary + architecture + trade-offs}

## Comparison
| Criteria        | Approach 1 | Approach 2 | Approach 3 |
|-----------------|-----------|-----------|-----------|
| AC coverage     | full      | full      | full      |
| Cost vs current | +0%       | +15%      | +40%      |
| Risk            | low       | medium    | medium    |
| Innovation      | none      | moderate  | high      |
```

---

## 6. Role Adapter

### 6.1 New Adapter Type

```yaml
type: architect-roles
contract:
  provides:
    roles: "3 lenses with name, focus"
    stack_constraints: "what NOT to do in this stack"
  consumes:
    tech_stack_adapter: "for codebase research methods"
    generated_context: "known artifact paths"
```

### 6.2 Angular Roles

```yaml
# adapters/architect-roles/angular.yaml
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

### 6.3 Generic Fallback

```yaml
# adapters/architect-roles/generic.yaml
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

### 6.4 Autodetect

Uses the same tech-stack detection as tech-stack adapter. `--stack=angular` flag overrides detection.

If no role adapter file exists for detected stack → use `generic.yaml`.

---

## 7. Planner Modifications

### 7.1 Architect Integration

When architect runs (M+ complexity):
- Step 4 (brainstorming) explores the problem space — constraints, priorities, what matters
- Step 5 (architect) uses brainstorming output + research to generate 3 approaches → arbiter selects
- Step 6 (plan creation) reads `architecture.md` and translates the chosen approach into concrete files, parts, commit order
- Planner does NOT reconsider architectural decisions — it concretizes them
- If planner spots a problem with the approach → writes to `known_risks`, does not change the approach

### 7.2 Planner Modes

```yaml
with_architect:          # architecture.md produced by step 5 (M+)
  architect_output: "architecture.md — chosen approach, files, trade-offs"
  planner_role: "Translate approach into implementation parts, order, commits"
  planner_does_not: "Reconsider architectural decisions"
  on_problem: "Write to known_risks. Plan-reviewer catches it."

without_architect:       # S complexity
  planner_role: "Full flow — brainstorming + plan creation"
  no_changes: "Works exactly as current planner"
```

---

## 8. Repo Layout v4.0

### 8.1 New Structure

```
agent-skills/
├── pipeline/
│   ├── worker/SKILL.md
│   ├── planner/SKILL.md
│   ├── architect/SKILL.md          ← NEW
│   ├── plan-reviewer/SKILL.md
│   ├── coder/SKILL.md
│   ├── code-reviewer/SKILL.md
│   ├── ui-reviewer/SKILL.md
│   ├── impact-analyzer/SKILL.md
│   ├── code-researcher/SKILL.md
│   └── figma-coding-rules/SKILL.md
├── adapters/
│   ├── jira/SKILL.md
│   ├── gitlab/SKILL.md
│   ├── angular/SKILL.md
│   ├── figma/SKILL.md
│   ├── slack/SKILL.md
│   └── architect-roles/            ← NEW
│       ├── SKILL.md
│       ├── angular.yaml
│       └── generic.yaml
├── core/
│   ├── orchestration/SKILL.md
│   ├── consensus-review/SKILL.md
│   ├── security/SKILL.md
│   └── metrics/SKILL.md
├── facades/
│   ├── jira-worker/SKILL.md
│   ├── architect/SKILL.md          ← NEW
│   ├── figma-audit/SKILL.md
│   ├── deploy/SKILL.md
│   ├── community-sync/SKILL.md
│   ├── ship/SKILL.md
│   ├── scan-ui-inventory/SKILL.md
│   ├── scan-qa-playbook/SKILL.md
│   └── scan-practices/SKILL.md
├── commands/
│   ├── arch.md                     ← NEW
│   ├── worker.md
│   ├── plan.md
│   ├── cr.md
│   └── ... (all existing)
├── VERSION
├── SKILLS_OVERVIEW.md
├── CLAUDE.md
└── docs/
```

### 8.2 Migration Steps

1. Delete `v1/` entirely
2. Move `v3/*` contents to repo root
3. Delete empty `v3/`
4. Create `VERSION` file with `4.0`
5. Update all internal path references

---

## 9. Files Changed

### New Files
| File | Purpose |
|------|---------|
| `pipeline/architect/SKILL.md` | Architect skill — 3 agents + arbiter |
| `adapters/architect-roles/SKILL.md` | Role adapter contract |
| `adapters/architect-roles/angular.yaml` | Angular lens definitions |
| `adapters/architect-roles/generic.yaml` | Fallback lens definitions |
| `facades/architect/SKILL.md` | Standalone `/arch` facade |
| `facades/arch-review/SKILL.md` | Standalone `/arch-review` facade |
| `commands/arch.md` | `/arch` command entry point |
| `commands/arch-review.md` | `/arch-review` command entry point |
| `VERSION` | Version file (4.0) |

### Modified Files
| File | Changes |
|------|---------|
| `core/orchestration/SKILL.md` | Phase sequence 1-9, named checkpoints, handoff contracts |
| `pipeline/worker/SKILL.md` | Phase dispatch, checkpoint schema, named phases |
| `pipeline/planner/SKILL.md` | Add architect step (step 5), mode detection |
| `pipeline/plan-reviewer/SKILL.md` | Phase references |
| `pipeline/coder/SKILL.md` | Phase references |
| `pipeline/code-reviewer/SKILL.md` | Phase references |
| `pipeline/ui-reviewer/SKILL.md` | Phase references |
| `pipeline/impact-analyzer/SKILL.md` | Phase references |
| `facades/*/SKILL.md` | Phase references |
| `commands/*.md` | Phase references |
| `SKILLS_OVERVIEW.md` | Full rewrite |
| `CLAUDE.md` | Version, phase references |

### Deleted
| Path | Reason |
|------|--------|
| `v1/` | Legacy, no longer needed |

---

## 10. Arch-Review — Retrospective Architectural Analysis

### 10.1 Purpose

Post-implementation or existing code review from an architectural perspective. Two use cases:
1. **After task completion** — evaluate the chosen approach: "did we build it right?"
2. **Existing codebase** — propose architectural improvements to code that already works

### 10.2 Triggers

```yaml
command: "/arch-review"
natural_language:
  - "оцени архитектуру", "review architecture"
  - "как улучшить архитектуру", "архитектурный ревью"
  - "предложи улучшения к коду"

flags:
  --stack: "override tech-stack detection"
  --model: "override model (opus|sonnet), default: opus"
  --scope: "path or module to focus on (default: auto-detect from git diff or user input)"

input_variants:
  after_task: "/arch-review ARGO-12345 — review architecture of completed task"
  existing_code: '/arch-review src/features/notifications — review this module'
  bare: "/arch-review — ask user what to review"
```

### 10.3 Flow — Sequential (3 review → 3 alternatives)

```
Phase A: Review (3 agents parallel)
  1. Load role adapter (same as /arch)
  2. Each agent reviews code through their lens
  3. Each produces: findings, severity, impact
  4. Aggregate: consensus findings (2+ agents agree)

Phase B: Alternatives (3 agents parallel)
  1. Receive aggregated review findings as input
  2. Each agent proposes targeted alternatives for found problems
  3. Same freedom gradient: conservative / balanced / challenger
  4. Each produces: alternative approach + migration path

Output: review report + 3 alternative proposals
```

### 10.4 Review Agents (Phase A)

Same 3 lenses from role adapter, but in **review mode**:

```yaml
review_agent_1:
  lens: "from role adapter lens_1"
  mode: review
  instruction: |
    Analyze existing code through your lens.
    Find: over-abstractions, under-abstractions, pattern violations,
    missed reuse opportunities, unnecessary complexity.
    Rate: 1-10 per area.
    Output: structured findings with severity (BLOCKER/MAJOR/MINOR).

review_agent_2:
  lens: "from role adapter lens_2"
  mode: review
  # same structure, different focus

review_agent_3:
  lens: "from role adapter lens_3"
  mode: review
  # same structure, different focus
```

### 10.5 Alternative Agents (Phase B)

Same 3 lenses, **same freedom gradient as /arch**:

```yaml
alternative_agent_1:
  freedom: conservative
  input: "aggregated review findings"
  instruction: |
    For each finding — propose a fix within current patterns.
    No new dependencies, no new abstractions.
    Show: what to change, estimated effort, risk.

alternative_agent_2:
  freedom: balanced
  input: "aggregated review findings"
  instruction: |
    For each finding — propose improvement, may introduce targeted changes.
    Justify cost of each deviation.

alternative_agent_3:
  freedom: challenger
  input: "aggregated review findings"
  instruction: |
    Propose an alternative architecture for the reviewed code.
    May suggest significant refactoring if justified.
    MUST include: migration plan, effort estimate, what breaks during migration.
```

### 10.6 Output Format

```markdown
## Architectural Review: {scope}

### Review Summary
| Area | Score | Key Finding |
|------|-------|-------------|
| {lens_1} | 7/10 | {finding} |
| {lens_2} | 5/10 | {finding} |
| {lens_3} | 8/10 | {finding} |

### Consensus Findings (2+ agents agree)
| # | Finding | Severity | Agents | Impact |
|---|---------|----------|--------|--------|

### Alternative 1: Conservative
{targeted fixes within current patterns}

### Alternative 2: Balanced
{improvements with justified deviations}

### Alternative 3: Challenger
{alternative architecture + migration plan}

### Comparison
| Criteria | Alt 1 | Alt 2 | Alt 3 |
|----------|-------|-------|-------|
| Effort | low | medium | high |
| Risk | none | low | medium |
| Improvement | incremental | moderate | significant |
```

### 10.7 New Files

| File | Purpose |
|------|---------|
| `facades/arch-review/SKILL.md` | Standalone facade |
| `commands/arch-review.md` | `/arch-review` command |

### 10.8 Pipeline Integration (Future)

Currently standalone only. Future option: run as post-Phase 9 optional step for completed tasks. Not in v4.0 scope — evaluate need after standalone usage.

---

## 11. Open Questions

### 11.1 Double Brainstorming

**Status:** Debatable

Architect and planner both invoke `superpowers:brainstorming`. Architect uses it to explore the architectural problem space ("what approach?"), planner uses it for implementation ("how to split into parts?").

**Risk:** Redundant token spend. **Counter:** Different purposes, different outputs. **Decision:** Ship as designed, evaluate after first real usage. If redundant — merge into single brainstorming call.

### 11.2 Loop Target on Architectural Problems

**Status:** Needs decision during implementation

If plan-reviewer finds an architectural flaw, the loop goes back to planner (Phase 5). But should it re-run only the architect step, or the entire planner flow?

**Proposed:** Re-run architect step (step 5) + plan creation (step 6), skip research (step 3) since codebase hasn't changed.

### 11.3 Role Adapter Expansion

Only `angular.yaml` and `generic.yaml` are created now. Other stacks added as needed, not speculatively. This aligns with existing feedback: no speculative adapters.
