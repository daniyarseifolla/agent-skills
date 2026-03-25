# Agent Skills v2.2 — Overview

## Architecture

```
User → Command → Facade → Worker → [Phase 0 → 0.5 → 0.7 → 1 → 2 → 3 → 4+5 → 6]
                                      ↓         ↓         ↓        ↓       ↓
                                    Adapters   Core    Consensus  Subagents  MCP

facades/                    pipeline/ (project-agnostic)      core/ (invisible)
├── jira-worker  ──┐        ├── worker (orchestrator)         ├── orchestration
├── figma-audit  ──┤        ├── planner        (opus)         ├── security
├── deploy       ──┤        ├── plan-reviewer  (opus)         ├── consensus-review
├── community-sync ┤        ├── coder          (sonnet)       └── metrics
├── scan-ui-inv  ──┤        ├── figma-coding-rules
├── scan-qa-pb   ──┤        ├── code-reviewer  (sonnet)
└── scan-practices ┘        ├── ui-reviewer    (sonnet)       adapters/ (swappable)
                            └── code-researcher (haiku)       ├── jira    (task-source)
                                                              ├── gitlab  (ci-cd)
                                                              ├── angular (tech-stack)
                                                              └── figma   (design)
```

## Skill Catalog

### Core (invisible, auto-loaded)

| Skill | Lines | Purpose |
|-------|-------|---------|
| core/orchestration | 415 | Phases (0-6 + 0.5, 0.7), handoffs, checkpoints, recovery, loops, routing, consensus activation |
| core/security | 151 | Universal OWASP checks. Framework-specific checks in tech-stack adapters (Section 7) |
| core/consensus-review | 211 | Multi-agent review pattern: 3 agents × different angles → aggregate |
| core/metrics | 212 | Pipeline metrics schema, phase ID normalization, collection, storage |

### Pipeline (project-agnostic phases)

| Skill | Lines | Model | Mode | Consensus (M+) | Purpose |
|-------|-------|-------|------|-----------------|---------|
| pipeline/worker | 469 | — | inline | — | Orchestrator: phases, checkpoints, dispatch, Phase 0.7 |
| pipeline/planner | 283 | opus | inline | — | Research codebase, create plan (reads task-analysis.md) |
| pipeline/plan-reviewer | 217 | opus | subagent | 3× opus: AC + Architecture + Design | Validate plan |
| pipeline/coder | 281 | sonnet | inline | — | Evaluate gate + implement + commit gate |
| pipeline/figma-coding-rules | 321 | — | loaded by coder | — | Figma extract, self-verify, UI quality, icons |
| pipeline/code-reviewer | 279 | sonnet | subagent/worktree | 3× sonnet: Bugs + Compliance + Security | Review diff |
| pipeline/ui-reviewer | 460 | sonnet | subagent | 3× sonnet: Functional + Visual + States/A11y | Browser + Figma testing |
| pipeline/code-researcher | 101 | haiku | Agent tool | — | Cheap read-only search (L/XL only) |

### Adapters (swappable per project)

| Skill | Lines | Type | Key Methods |
|-------|-------|------|-------------|
| adapters/jira | 179 | task-source | fetch_task, parse_ac, transition, format_mr |
| adapters/gitlab | 304 | ci-cd | create_mr, pipeline, deploy, cherry_pick, CI disable/restore |
| adapters/angular | 361 | tech-stack | commands, quality_checks, security_checks, api_discovery, patterns, module_lookup |
| adapters/figma | 224 | design | get_design, get_screenshot, compare_visual, extract_tokens |

### Facades (user-facing entry points)

| Skill | Lines | Triggers |
|-------|-------|----------|
| facades/figma-audit | 638 | `/figma`, "проверь верстку", "figma audit", "сравни с макетом" |
| facades/scan-qa-playbook | 211 | `/scan-qa`, "скан QA", "сгенерируй playbook" |
| facades/community-sync | 186 | `/sync`, "обновить ветки", "sync branches" |
| facades/scan-practices | 149 | `/scan-practices`, "скан практик" |
| facades/scan-ui-inventory | 132 | `/scan-ui`, "скан UI", "обнови инвентарь" |
| facades/jira-worker | 45 | `/worker`, ARGO-XXX, "сделай задачу", "возьми тикет" |
| facades/deploy | 34 | `/deploy`, "задеплой", "deploy to test/prod" |

### Commands (16 slash commands)

| Command | Lines | Purpose |
|---------|-------|---------|
| /worker | 13 | Start full pipeline |
| /figma | 25 | Figma audit & implementation |
| /plan | 14 | Run planner only |
| /cr | 15 | Code review |
| /code-review | 15 | Alias for /cr |
| /ui-review | 13 | UI review |
| /verify-figma | 53 | Figma CSS verification |
| /deploy | 14 | Deploy to environment |
| /sync | 11 | Sync community branches |
| /attach | 162 | Attach to existing task |
| /continue | 28 | Resume from checkpoint |
| /progress | 24 | Show pipeline state |
| /cleanup | 18 | Clean up artifacts |
| /scan-ui | 9 | Scan UI inventory |
| /scan-qa | 9 | Generate QA playbook |
| /scan-practices | 9 | Scan project practices |

## Pipeline Phases

| Phase | Name | Model | Consensus (M+) | Skip |
|-------|------|-------|-----------------|------|
| 0 | Task analysis | sonnet | — | — |
| 0.5 | Workspace setup | sonnet | — | Resume |
| 0.7 | Deep analysis | opus+sonnet | Yes (Figma + API + Functional) | S complexity |
| 1 | Planning | opus | — | — |
| 2 | Plan review | opus | Yes (AC + Architecture + Design) | S complexity |
| 3 | Implementation | sonnet | — | — |
| 4 | Code review | sonnet | Yes (Bugs + Compliance + Security) | — |
| 5 | UI review | sonnet | Yes (Functional + Visual + States) | S complexity, no design |
| 6 | Completion | sonnet | — | — |

### Phase 0.7: Deep Task Analysis

```yaml
agents:
  agent_1_figma (opus):    "All screens, states, flows, screenshots"
  agent_2_api (sonnet):    "Swagger → endpoints → OPTIONS test → classify working/broken/missing"
  agent_3_functional (opus): "Screens × endpoints → user flows + gaps (sequential, after 1+2)"

output: "docs/plans/{task-key}/task-analysis.md"
confirmation_gate: "Show user → y/edit/abort. Offer to create Jira tasks for missing endpoints."
```

## Model Routing

| Model | Skills | Purpose | Cost |
|-------|--------|---------|------|
| **opus** | planner, plan-reviewer (consensus), Phase 0.7 agents 1+3 | Deep research, analytical review | $$$ |
| **sonnet** | coder, code-reviewer (consensus), ui-reviewer (consensus), Phase 0.7 agent 2 | Implementation, pattern matching | $$ |
| **haiku** | code-researcher | Read-only search, data collection | $ |

## Complexity Routing

| Level | AC | Deep Analysis | Plan Review | UI Review | Code Review | Consensus |
|-------|----|--------------|-------------|-----------|-------------|-----------|
| S | 1-2 | skip | skip | skip | 1 agent | No |
| M | 3-4 | 3 agents | 3× opus | if design: 3× sonnet | 3× sonnet | Yes |
| L | 5-6 | 3 agents | 3× opus | 3× sonnet | 3× sonnet | Yes |
| XL | 7+ | 3 agents | 3× opus | 3× sonnet | 3× sonnet | Yes |

## Adapter Contracts

```yaml
task-source:     fetch_task, parse_ac, get_complexity_hints, transition, format_mr_description
ci-cd:           create_mr, get_pipeline, wait_for_stage, deploy, retry_job, create_tag
tech-stack:      commands (lint/test/build), quality_checks, security_checks, api_discovery, patterns, module_lookup
design:          parse_urls, get_design, get_screenshot, compare_visual, extract_tokens
```

## Project Configuration

```yaml
# .claude/project.yaml
version: "2.2"
task-source: jira
ci-cd: gitlab
tech-stack: angular
design: figma
api:
  swagger_url: "https://api.dev.project.com/swagger/v1/swagger.json"
  base_url: "https://api.dev.project.com"
```

Fallback: autodetect from package.json, .gitlab-ci.yml, task URL, proxy.conf.json.

## External Skill Dependencies

| External Skill | Used by | On unavailable |
|---------------|---------|----------------|
| visual-qa | ui-reviewer, figma-audit | WARN + Install/Skip/Abort |
| css-styling-expert | coder | WARN + Install/Skip/Abort |
| refactoring-ui | coder, figma-coding-rules | WARN + Install/Skip/Abort |
| qa-test-planner | ui-reviewer | WARN + generate basic cases |
| ui-ux-pro-max | ui-reviewer | WARN + Install/Skip/Abort |
| agent-browser | ui-reviewer | WARN + skip functional testing |

## MCP Dependencies

| MCP Server | Used by | On unavailable |
|-----------|---------|----------------|
| Figma | adapter-figma, figma-audit, coder | HALT (for design tasks) |
| Atlassian | adapter-jira, Phase 0.7 | HALT (for Jira tasks) |
| Playwright / Chrome DevTools | ui-reviewer, figma-audit | Fallback: non-browser mode |

## Superpowers Integration

| Superpowers Skill | Used by |
|-------------------|---------|
| brainstorming | pipeline/planner |
| writing-plans | pipeline/planner |
| executing-plans | pipeline/coder (S, <3 parts) |
| subagent-driven-development | pipeline/coder (M+, 3+ parts) |
| dispatching-parallel-agents | pipeline/ui-reviewer, facades/community-sync, Phase 0.7, figma-audit |
| figma:implement-design | pipeline/coder via figma-coding-rules |

## Output Files

```
docs/plans/{task-key}/
├── task-analysis.md       ← Phase 0.7 (Figma screens + API + flows)
├── screenshots/           ← Phase 0.7 (Figma screenshots)
├── plan.md                ← Phase 1
├── evaluate.md            ← Phase 3
├── figma-verify.md        ← Phase 3 (per-property Figma verification)
├── code-review.md         ← Phase 4
├── ui-review.md           ← Phase 5
├── checkpoint.yaml        ← Recovery
└── metrics.yaml           ← Phase 6

docs/figma-audit/{audit-id}/
├── figma-node-map.md      ← /figma Phase 1
├── figma-comparison.md    ← /figma Phase 2
├── property-diff.yaml     ← /figma Phase 2
├── implementation-summary.md ← /figma Phase 3
└── figma-audit-report.md  ← /figma Phase 4
```
