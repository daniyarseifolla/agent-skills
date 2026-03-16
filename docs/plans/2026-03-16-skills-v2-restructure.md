# Skills v2.0 — Restructure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure agent-skills into project-agnostic, model-routed, recoverable pipeline with swappable adapters and versioning.

**Architecture:** Thin facades (user-facing triggers) → project-agnostic pipeline (phases) → core (invisible: handoff, recovery, security, metrics) → adapters (jira, gitlab, angular, figma). Core skills have `disable-model-invocation: true` — loaded by pipeline skills, never by user directly.

**Tech Stack:** Claude Code skills (SKILL.md), YAML frontmatter, MCP tools (Atlassian, Figma)

---

## File Structure

```
~/Desktop/pet/agent-skills/
├── v1.0/                              ← current skills, untouched backup
│   ├── jira-worker/SKILL.md
│   ├── jira-planner/SKILL.md
│   ├── jira-plan-reviewer/SKILL.md
│   ├── jira-code-reviewer/SKILL.md
│   ├── jira-ui-reviewer/SKILL.md
│   ├── scan-ui-inventory/SKILL.md
│   ├── deploy/SKILL.md
│   ├── community-sync/SKILL.md
│   └── SKILLS_OVERVIEW.md
│
├── v2.0/
│   ├── README.md
│   ├── project.yaml.example           ← project config template
│   │
│   ├── core/                          ← invisible, auto-loaded by pipeline
│   │   ├── orchestration/SKILL.md     ← handoff, checkpoints, recovery, loop limits, re-routing
│   │   ├── security/SKILL.md          ← OWASP security checklist (Angular-adapted)
│   │   └── metrics/SKILL.md           ← pipeline metrics collection
│   │
│   ├── pipeline/                      ← project-agnostic phases
│   │   ├── worker/SKILL.md            ← thin orchestrator, reads project.yaml, delegates
│   │   ├── planner/SKILL.md           ← planning phase (opus)
│   │   ├── coder/SKILL.md             ← implementation phase (sonnet)
│   │   ├── plan-reviewer/SKILL.md     ← plan review (sonnet, subagent)
│   │   ├── code-reviewer/SKILL.md     ← code review (sonnet, subagent/worktree)
│   │   ├── ui-reviewer/SKILL.md       ← UI review (sonnet, subagent)
│   │   └── code-researcher/SKILL.md   ← read-only search (haiku, Task tool)
│   │
│   ├── adapters/                      ← swappable per project
│   │   ├── jira/SKILL.md              ← fetch task, parse AC, transitions, MR description
│   │   ├── gitlab/SKILL.md            ← MR creation, CI/CD, deploy, pipeline monitoring
│   │   ├── angular/SKILL.md           ← patterns, lint/test/build commands, quality checks
│   │   └── figma/SKILL.md             ← design context, screenshots, visual comparison
│   │
│   ├── facades/                       ← user-facing entry points (thin, 50-80 lines)
│   │   ├── jira-worker/SKILL.md       ← triggers: ARGO-XXX, "сделай задачу"
│   │   ├── deploy/SKILL.md            ← triggers: "deploy", "задеплой"
│   │   ├── community-sync/SKILL.md    ← triggers: "sync branches", "обновить ветки"
│   │   └── scan-ui-inventory/SKILL.md ← triggers: "scan UI", "скан компонентов"
│   │
│   └── SKILLS_OVERVIEW.md
│
└── docs/plans/
    └── 2026-03-16-skills-v2-restructure.md  ← this plan
```

## Key Design Decisions

### Model Routing

| Skill | Model | Why |
|-------|-------|-----|
| facades/* | inherited | Just delegates, no own work |
| pipeline/worker | opus | Orchestration, routing decisions |
| pipeline/planner | opus | Deep research, architecture |
| pipeline/coder | sonnet | Code writing — sonnet is sufficient |
| pipeline/plan-reviewer | sonnet | Checklist-based validation |
| pipeline/code-reviewer | sonnet | Checklist-based validation |
| pipeline/ui-reviewer | sonnet | Functional + visual checks |
| pipeline/code-researcher | haiku | Read-only grep/glob, cheap |
| adapters/* | inherited | Loaded as context, not invoked |
| core/* | inherited | Loaded as context, not invoked |

Model is set via `model:` frontmatter in agent definitions or via Agent tool's `model` parameter.

### Skill Loading

```
User says "ARGO-123"
  → Claude matches facades/jira-worker (by description trigger)
    → jira-worker loads:
        1. Read .claude/project.yaml (or autodetect)
        2. Skill: pipeline/worker (orchestrator)
           ↳ worker loads core/orchestration (handoff, recovery, checkpoints)
           ↳ worker delegates to phases:
              - Skill: pipeline/planner → loads adapters/jira (for AC), adapters/angular (for patterns)
              - Agent(sonnet): pipeline/plan-reviewer → loads core/orchestration (handoff contract)
              - Skill: pipeline/coder → loads adapters/angular (lint/test commands)
              - Agent(sonnet, worktree): pipeline/code-reviewer → loads core/security
              - Agent(sonnet): pipeline/ui-reviewer → loads adapters/figma
```

### Facade Pattern

Facades keep user-facing triggers stable while internals change freely:

```yaml
# facades/jira-worker/SKILL.md (thin — ~60 lines)
---
name: jira-worker
description: "Use PROACTIVELY when user provides Jira issue key (ARGO-XXXXX)..."
---
# Jira Worker Facade
1. Load pipeline/worker skill
2. Set task-source: jira
3. Delegate everything to worker
```

### Adapter Contract

Each adapter implements a known interface so pipeline skills can use them without knowing the specifics:

```yaml
# Every task-source adapter must provide:
adapter:
  type: task-source
  provides:
    - fetch_task(key) → { title, description, ac[], figma_urls[], assignee }
    - parse_ac(description) → acceptance_criteria[]
    - transition(key, status) → void
    - create_mr(branch, title, description) → mr_url

# Every ci-cd adapter must provide:
adapter:
  type: ci-cd
  provides:
    - deploy(branch, env) → pipeline_url
    - check_pipeline(id) → { status, jobs[] }
    - retry_job(id) → void

# Every tech-stack adapter must provide:
adapter:
  type: tech-stack
  provides:
    - lint_command → string
    - test_command → string
    - build_command → string
    - quality_checks → checklist[]
    - patterns → { components, state, routing, http }

# Every design adapter must provide:
adapter:
  type: design
  provides:
    - get_design(url) → { screenshot, code_hint, tokens }
    - compare_screenshot(actual, figma_url) → diff_report
```

### Core: Orchestration (loaded by pipeline/worker)

Contains everything that was scattered across skills in v1:

**Handoff protocol** — typed contracts between phases:
```yaml
planner_to_reviewer: { artifact_path, key_decisions[], known_risks[], complexity }
reviewer_to_coder:   { verdict, approved_notes[], iteration }
coder_to_reviewer:   { branch, parts_implemented[], deviations[], risks_mitigated[] }
reviewer_to_done:    { verdict, comments[], iteration }
```

**Checkpoint protocol** — YAML state after each phase:
```yaml
# .claude/workflow-state/{task-key}-checkpoint.yaml
task_key: "ARGO-12345"
phase_completed: 3
phase_name: "implementation"
iteration: { plan_review: "1/3", code_review: "0/3" }
verdict: "APPROVED"
complexity: "M"
route: "STANDARD"
timestamp: "2026-03-16T14:30:00Z"
```

**Session recovery** — checkpoint-first, heuristic fallback:
| Plan? | Code changes? | Tests pass? | Resume from |
|-------|--------------|-------------|-------------|
| No | — | — | Phase 1: Planning |
| Yes | No | — | Phase 3: Implementation |
| Yes | Yes | No | Phase 3: Fix tests |
| Yes | Yes | Yes | Phase 4: Code Review |

**Loop limits** — max 3 iterations per review cycle, then STOP + summary table.

**Re-routing** — self-correction when complexity misclassified (SIMPLE→FULL or FULL→SIMPLE).

**Evaluate gate** — coder evaluates plan before implementation (PROCEED/REVISE/RETURN).

### Core: Security (loaded by pipeline/code-reviewer)

OWASP-adapted for Angular:

| Category | What to grep | Severity |
|----------|-------------|----------|
| XSS | `innerHTML`, `bypassSecurityTrust*`, `[href]` binding | BLOCKER |
| Injection | String concatenation in queries, `eval()`, `Function()` | BLOCKER |
| Auth bypass | Routes without guards, missing `canActivate` | BLOCKER |
| Secrets | `password`, `secret`, `token`, `apiKey` in literals | BLOCKER |
| CSRF | Forms without CSRF tokens, missing `HttpXsrfInterceptor` | MAJOR |
| Error leak | Stack traces in HTTP responses, verbose error messages | MAJOR |

### Core: Metrics (loaded by pipeline/worker at completion)

Collected at end of pipeline:
```yaml
metrics:
  task_key: "ARGO-12345"
  complexity: "M"
  route: "STANDARD"
  phases_completed: 5
  iterations: { plan_review: 1, code_review: 2 }
  re_routed: false
  evaluate_result: "PROCEED"
  duration_estimate: "medium"
  issues_found: { blocker: 0, major: 1, minor: 3 }
```

### Complexity Routing (4 levels)

| | S (Simple) | M (Medium) | L (Large) | XL (Extra Large) |
|---|---|---|---|---|
| AC count | 1-2 | 3-4 | 5-6 | 7+ |
| Modules | 1 | 2 | 3+ | 4+ |
| Plan review | skip | standard | standard | standard |
| UI review | skip | if Figma | yes | yes |
| Code researcher | no | no | yes | yes |
| Sequential Thinking | no | optional | recommended | required |

v1 mapping: SIMPLE ≈ S, FULL ≈ M+L+XL.

### Project Configuration

```yaml
# .claude/project.yaml
version: "2.0"

task-source: jira          # adapter name
ci-cd: gitlab              # adapter name
tech-stack: angular        # adapter name
design: figma              # adapter name (optional)

# Project-specific overrides
project:
  name: passport
  repo: gitlab.com/team/passport
  branches:
    main: develop
    release: release/*
  deploy:
    test: deploy-test
    prod: production
```

Autodetect fallback: no config → detect from `package.json` (angular), `.gitlab-ci.yml` (gitlab), Jira URL in task (jira).

---

## Chunk 1: Backup v1.0 + Scaffold v2.0

### Task 1: Backup current skills to v1.0

**Files:**
- Create: `v1.0/` directory with copies of all current skills

- [ ] **Step 1: Create v1.0 directory and copy all current skills**

```bash
cd ~/Desktop/pet/agent-skills
mkdir -p v1.0
cp -r jira-worker v1.0/
cp -r jira-planner v1.0/
cp -r jira-plan-reviewer v1.0/
cp -r jira-code-reviewer v1.0/
cp -r jira-ui-reviewer v1.0/
cp -r scan-ui-inventory v1.0/
cp -r deploy v1.0/
cp -r community-sync v1.0/
cp SKILLS_OVERVIEW.md v1.0/
cp CLAUDE.md v1.0/
```

- [ ] **Step 2: Verify backup**

```bash
ls v1.0/
# Expected: all 8 skill dirs + SKILLS_OVERVIEW.md + CLAUDE.md
diff <(ls jira-worker/) <(ls v1.0/jira-worker/)
# Expected: no diff
```

- [ ] **Step 3: Commit backup**

```bash
git add v1.0/
git commit -m "chore: backup v1.0 skills before v2.0 restructure"
```

### Task 2: Scaffold v2.0 directory structure

**Files:**
- Create: `v2.0/` with all subdirectories

- [ ] **Step 1: Create directory tree**

```bash
cd ~/Desktop/pet/agent-skills
mkdir -p v2.0/{core/{orchestration,security,metrics},pipeline/{worker,planner,coder,plan-reviewer,code-reviewer,ui-reviewer,code-researcher},adapters/{jira,gitlab,angular,figma},facades/{jira-worker,deploy,community-sync,scan-ui-inventory}}
```

- [ ] **Step 2: Create project.yaml.example**

Write `v2.0/project.yaml.example` — template for project configuration.

- [ ] **Step 3: Commit scaffold**

```bash
git add v2.0/
git commit -m "chore: scaffold v2.0 directory structure"
```

---

## Chunk 2: Core Skills (invisible, auto-loaded)

### Task 3: core/orchestration

**Files:**
- Create: `v2.0/core/orchestration/SKILL.md`

This is the heart of v2.0. Contains: handoff protocol, checkpoint protocol, session recovery, loop limits, re-routing, evaluate gate, complexity routing. ~200 lines.

Source material:
- claude-kit: `workflow-protocols/handoff-protocol.md`, `checkpoint-protocol.md`, `re-routing.md`, `orchestration-core.md`
- v1 jira-worker: pipeline steps, SIMPLE/FULL routing
- New: evaluate gate (PROCEED/REVISE/RETURN)

Key differences from claude-kit:
- Project-agnostic (no Go/make references)
- Uses adapter contract instead of hardcoded commands
- 4-level complexity (S/M/L/XL) adapted from v1's SIMPLE/FULL
- Checkpoint path uses task key from adapter, not feature name

- [ ] **Step 1: Write core/orchestration/SKILL.md**

Frontmatter: `disable-model-invocation: true` (never called by user).
Sections: Pipeline Phases, Handoff Contracts, Checkpoint Protocol, Session Recovery, Loop Limits, Evaluate Gate, Complexity Routing, Re-routing.

- [ ] **Step 2: Verify skill loads** — read file, check YAML frontmatter is valid.

- [ ] **Step 3: Commit**

```bash
git add v2.0/core/orchestration/
git commit -m "feat(v2): add core/orchestration — handoff, recovery, checkpoints"
```

### Task 4: core/security

**Files:**
- Create: `v2.0/core/security/SKILL.md`

OWASP security checklist adapted for frontend (Angular primary, but framework-agnostic where possible). ~80 lines.

Source: claude-kit `code-review-rules/security-checklist.md`, adapted from Go to Angular/TS.

- [ ] **Step 1: Write core/security/SKILL.md**

Sections: Severity Classification, XSS Checks, Injection Checks, Auth/AuthZ Checks, Secrets Detection, Error Info Leak, CSRF. Each with grep patterns.

- [ ] **Step 2: Commit**

```bash
git add v2.0/core/security/
git commit -m "feat(v2): add core/security — OWASP checklist for Angular/TS"
```

### Task 5: core/metrics

**Files:**
- Create: `v2.0/core/metrics/SKILL.md`

Pipeline metrics collection at completion. ~50 lines.

Source: claude-kit `workflow-protocols/pipeline-metrics.md`.

- [ ] **Step 1: Write core/metrics/SKILL.md**

Fields: task_key, complexity, route, phases_completed, iterations, re_routed, issues_found, evaluate_result.

- [ ] **Step 2: Commit**

```bash
git add v2.0/core/metrics/
git commit -m "feat(v2): add core/metrics — pipeline metrics collection"
```

---

## Chunk 3: Adapters (swappable per project)

### Task 6: adapters/jira

**Files:**
- Create: `v2.0/adapters/jira/SKILL.md`

Extracted from v1 jira-worker: Jira-specific logic. ~100 lines.

Contains: how to fetch task, parse AC, extract Figma URLs, determine complexity from AC count, Jira transitions, MR description template.

- [ ] **Step 1: Write adapters/jira/SKILL.md**

Implements task-source adapter contract. MCP tools: `getJiraIssue`, `getTransitionsForJiraIssue`, `transitionJiraIssue`, `searchJiraIssuesUsingJql`.

- [ ] **Step 2: Commit**

```bash
git add v2.0/adapters/jira/
git commit -m "feat(v2): add adapters/jira — task source adapter"
```

### Task 7: adapters/gitlab

**Files:**
- Create: `v2.0/adapters/gitlab/SKILL.md`

Extracted from v1 deploy + community-sync: GitLab-specific logic. ~120 lines.

Contains: MR creation via `glab`, pipeline monitoring, job trigger/retry, deploy commands, tag creation for production.

- [ ] **Step 1: Write adapters/gitlab/SKILL.md**

Implements ci-cd adapter contract. Commands: `glab mr create`, `glab api`, pipeline monitoring loop.

- [ ] **Step 2: Commit**

```bash
git add v2.0/adapters/gitlab/
git commit -m "feat(v2): add adapters/gitlab — CI/CD adapter"
```

### Task 8: adapters/angular

**Files:**
- Create: `v2.0/adapters/angular/SKILL.md`

Extracted from v1 jira-code-reviewer Angular quality section + v1 jira-worker Module Lookup. ~100 lines.

Contains: lint/test/build commands per project type (Nx vs standalone), Angular quality patterns (signals, OnPush, inject(), standalone components), Module Lookup table, component patterns.

- [ ] **Step 1: Write adapters/angular/SKILL.md**

Implements tech-stack adapter contract. References Angular skills: `angular-component`, `angular-signals`, `angular-di`, `angular-http`, `angular-routing`.

- [ ] **Step 2: Commit**

```bash
git add v2.0/adapters/angular/
git commit -m "feat(v2): add adapters/angular — tech stack adapter"
```

### Task 9: adapters/figma

**Files:**
- Create: `v2.0/adapters/figma/SKILL.md`

Extracted from v1 jira-planner (Figma-first mode) + jira-ui-reviewer (visual comparison). ~80 lines.

Contains: Figma URL parsing, `get_design_context` / `get_screenshot` usage, visual comparison workflow, design token extraction.

- [ ] **Step 1: Write adapters/figma/SKILL.md**

Implements design adapter contract. MCP tools: `get_design_context`, `get_screenshot`, `get_metadata`.

- [ ] **Step 2: Commit**

```bash
git add v2.0/adapters/figma/
git commit -m "feat(v2): add adapters/figma — design adapter"
```

---

## Chunk 4: Pipeline Skills (project-agnostic phases)

### Task 10: pipeline/worker

**Files:**
- Create: `v2.0/pipeline/worker/SKILL.md`

The project-agnostic orchestrator. ~150 lines. Replaces the 443-line jira-worker.

Reads project config → loads adapters → runs phases in order → handles checkpoints/recovery.

Source: v1 jira-worker pipeline steps, stripped of Jira/Angular/GitLab specifics + claude-kit orchestration-core.

- [ ] **Step 1: Write pipeline/worker/SKILL.md**

Sections: Config Loading, Complexity Assessment, Pipeline Phases (with gates), Adapter Delegation, Error Handling.

Loads: `core/orchestration` for handoff/recovery, `core/metrics` at completion.

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/worker/
git commit -m "feat(v2): add pipeline/worker — project-agnostic orchestrator"
```

### Task 11: pipeline/planner

**Files:**
- Create: `v2.0/pipeline/planner/SKILL.md`

Planning phase. ~120 lines.

Source: v1 jira-planner, stripped of Jira-specific parts (AC parsing delegated to adapter).

Wraps brainstorming + writing-plans superpowers. Loads tech-stack adapter for patterns, design adapter for Figma-first mode.

- [ ] **Step 1: Write pipeline/planner/SKILL.md**

Model: opus. Loads: adapters (task-source for AC, design for Figma, tech-stack for patterns), core/orchestration (handoff contract).

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/planner/
git commit -m "feat(v2): add pipeline/planner — planning phase"
```

### Task 12: pipeline/coder

**Files:**
- Create: `v2.0/pipeline/coder/SKILL.md`

Implementation phase. ~100 lines.

Source: claude-kit coder-rules (evaluate protocol, rules) + v1 jira-worker Step 6.

New: evaluate gate (PROCEED/REVISE/RETURN) before implementation.

- [ ] **Step 1: Write pipeline/coder/SKILL.md**

Model: sonnet. Sections: Evaluate Gate, Implementation Rules, Verification (uses tech-stack adapter for lint/test commands).

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/coder/
git commit -m "feat(v2): add pipeline/coder — implementation with evaluate gate"
```

### Task 13: pipeline/plan-reviewer

**Files:**
- Create: `v2.0/pipeline/plan-reviewer/SKILL.md`

Plan review phase. ~100 lines. Runs as subagent (sonnet) for objectivity.

Source: v1 jira-plan-reviewer + claude-kit plan-review-rules (required sections, architecture checks).

New: required sections validation, severity-based verdicts (APPROVED / NEEDS_CHANGES / REJECTED).

- [ ] **Step 1: Write pipeline/plan-reviewer/SKILL.md**

Model: sonnet. Runs as: Agent(subagent). Loads: core/orchestration (handoff contract), tech-stack adapter (for architecture patterns).

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/plan-reviewer/
git commit -m "feat(v2): add pipeline/plan-reviewer — plan validation"
```

### Task 14: pipeline/code-reviewer

**Files:**
- Create: `v2.0/pipeline/code-reviewer/SKILL.md`

Code review phase. ~120 lines. Runs as subagent (sonnet, worktree for isolation).

Source: v1 jira-code-reviewer + claude-kit code-review-rules (severity classification, decision matrix).

New: loads core/security for OWASP checks, severity: BLOCKER/MAJOR/MINOR/NIT, decision matrix.

- [ ] **Step 1: Write pipeline/code-reviewer/SKILL.md**

Model: sonnet. Runs as: Agent(subagent, worktree). Loads: core/security, core/orchestration (handoff), tech-stack adapter (quality checks).

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/code-reviewer/
git commit -m "feat(v2): add pipeline/code-reviewer — code review with security"
```

### Task 15: pipeline/ui-reviewer

**Files:**
- Create: `v2.0/pipeline/ui-reviewer/SKILL.md`

UI review phase. ~120 lines. Runs as subagent (sonnet).

Source: v1 jira-ui-reviewer (functional + visual testing).

Dispatches parallel subagents: functional-tester (agent-browser) + visual-comparator (design adapter).

- [ ] **Step 1: Write pipeline/ui-reviewer/SKILL.md**

Model: sonnet. Loads: design adapter (for Figma comparison), tech-stack adapter (for component inventory check).

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/ui-reviewer/
git commit -m "feat(v2): add pipeline/ui-reviewer — functional + visual testing"
```

### Task 16: pipeline/code-researcher

**Files:**
- Create: `v2.0/pipeline/code-researcher/SKILL.md`

New skill (from claude-kit). Read-only haiku agent for cheap codebase search. ~60 lines.

Invoked via Task tool by planner/coder for L/XL tasks. Returns structured summary ≤2000 tokens.

- [ ] **Step 1: Write pipeline/code-researcher/SKILL.md**

Model: haiku. Tools: Read, Glob, Grep, Bash(read-only). Output format: `{ patterns[], files[], imports[], snippets[] }`.

- [ ] **Step 2: Commit**

```bash
git add v2.0/pipeline/code-researcher/
git commit -m "feat(v2): add pipeline/code-researcher — haiku search agent"
```

---

## Chunk 5: Facades (user-facing entry points)

### Task 17: facades/jira-worker

**Files:**
- Create: `v2.0/facades/jira-worker/SKILL.md`

Thin facade (~60 lines). Same triggers as v1 jira-worker. Delegates to pipeline/worker with `task-source: jira`.

- [ ] **Step 1: Write facades/jira-worker/SKILL.md**

Keeps: name, description, triggers (ARGO-XXX, "сделай задачу", etc.), allowed-tools.
Delegates: everything to `Skill: pipeline/worker`.

- [ ] **Step 2: Commit**

```bash
git add v2.0/facades/jira-worker/
git commit -m "feat(v2): add facades/jira-worker — entry point"
```

### Task 18: facades/deploy

**Files:**
- Create: `v2.0/facades/deploy/SKILL.md`

Thin facade (~40 lines). Same triggers as v1 deploy. Delegates to adapters/gitlab deploy workflow.

- [ ] **Step 1: Write facades/deploy/SKILL.md**

- [ ] **Step 2: Commit**

```bash
git add v2.0/facades/deploy/
git commit -m "feat(v2): add facades/deploy — entry point"
```

### Task 19: facades/community-sync

**Files:**
- Create: `v2.0/facades/community-sync/SKILL.md`

Thin facade (~40 lines). Delegates to adapters/gitlab + community-specific sync logic.

- [ ] **Step 1: Write facades/community-sync/SKILL.md**

- [ ] **Step 2: Commit**

```bash
git add v2.0/facades/community-sync/
git commit -m "feat(v2): add facades/community-sync — entry point"
```

### Task 20: facades/scan-ui-inventory

**Files:**
- Create: `v2.0/facades/scan-ui-inventory/SKILL.md`

Thin facade (~40 lines). Standalone, no pipeline dependency.

- [ ] **Step 1: Write facades/scan-ui-inventory/SKILL.md**

- [ ] **Step 2: Commit**

```bash
git add v2.0/facades/scan-ui-inventory/
git commit -m "feat(v2): add facades/scan-ui-inventory — entry point"
```

---

## Chunk 6: Documentation + Review

### Task 21: v2.0 README and SKILLS_OVERVIEW

**Files:**
- Create: `v2.0/README.md`
- Create: `v2.0/SKILLS_OVERVIEW.md`

- [ ] **Step 1: Write README.md** — installation, project config, adapter overview, version history.

- [ ] **Step 2: Write SKILLS_OVERVIEW.md** — architecture diagram, skill catalog, model routing table, adapter contracts.

- [ ] **Step 3: Update root CLAUDE.md** — point to v2.0 as active version.

- [ ] **Step 4: Commit**

```bash
git add v2.0/README.md v2.0/SKILLS_OVERVIEW.md CLAUDE.md
git commit -m "docs(v2): add README, SKILLS_OVERVIEW, update root CLAUDE.md"
```

### Task 22: Final review

- [ ] **Step 1: Verify all files exist**

```bash
find v2.0 -name "SKILL.md" | sort
# Expected: 15 SKILL.md files (3 core + 4 adapters + 7 pipeline + 4 facades... wait)
# Actually: 3 core + 7 pipeline + 4 adapters + 4 facades = 18 SKILL.md files
```

- [ ] **Step 2: Verify no v1 logic leaks** — grep for "ARGO", "passport", "community" in core/ and pipeline/ (should be zero matches — these belong in adapters only).

- [ ] **Step 3: Verify adapter contracts** — each adapter has all required `provides:` methods documented.

- [ ] **Step 4: Line count comparison**

```bash
echo "v1.0 total:"
find v1.0 -name "SKILL.md" -exec wc -l {} + | tail -1
echo "v2.0 total:"
find v2.0 -name "SKILL.md" -exec wc -l {} + | tail -1
# v2.0 should be larger (more skills) but each individual file should be smaller
```

- [ ] **Step 5: Commit final state**

```bash
git add -A
git commit -m "chore(v2): skills v2.0 restructure complete"
```

---

## Summary

| Metric | v1.0 | v2.0 |
|--------|------|------|
| Skills | 8 monolithic | 18 focused |
| Max lines per skill | 443 (jira-worker) | ~150 (worker) |
| Model routing | none | opus/sonnet/haiku |
| Security checks | none | OWASP checklist |
| Session recovery | none | checkpoint + heuristic |
| Loop limits | none (1 attempt) | 3 iterations + summary |
| Evaluate gate | none | PROCEED/REVISE/RETURN |
| Project-agnostic | no (Angular/Jira hardcoded) | yes (adapter pattern) |
| Complexity levels | 2 (SIMPLE/FULL) | 4 (S/M/L/XL) |
| Metrics | none | collected at completion |

## What's preserved from v1

- All trigger phrases (ARGO-XXX, "сделай задачу", "deploy", "sync branches", etc.)
- User-facing workflow (plan → review → implement → review → MR → deploy)
- MR/deploy only with user confirmation
- Superpowers integration (brainstorming, writing-plans, executing-plans, subagent-driven-development)
- Figma-first mode for empty descriptions
- Component inventory (.claude/ui-inventory.md)
- Community-sync batch logic with conflict resolution

## What's new from claude-kit

- Handoff protocol (typed contracts between phases)
- Checkpoint protocol (YAML state for session recovery)
- Evaluate gate (coder reviews plan before implementing)
- Security checklist (OWASP adapted for Angular)
- Code researcher (haiku agent for cheap search)
- Loop limits (3 iterations per review cycle)
- Re-routing (complexity self-correction)
- Pipeline metrics
- Model routing (opus/sonnet/haiku)
