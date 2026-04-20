# Agent Skills v4.0 — Overview

> **Source of truth:** This repository is canonical. `~/.claude/skills/` is the install target, not the source. All edits here, then sync to global.

## Architecture

```
User → Command → Facade → Worker → [Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9]
                                      ↓         ↓         ↓        ↓       ↓
                                    Adapters   Core    Consensus  Subagents  MCP

facades/                    pipeline/ (project-agnostic)      core/ (invisible)
├── worker       ──┐        ├── worker (orchestrator)         ├── orchestration
├── figma-audit  ──┤        ├── planner        (opus)         ├── security
├── deploy       ──┤        ├── architect      (opus)         ├── consensus-review
├── community-sync ┤        ├── plan-reviewer  (opus)         └── metrics
├── architect    ──┤        ├── coder          (sonnet)
├── arch-review  ──┤        ├── figma-coding-rules
├── scan-ui-inv  ──┤        ├── code-reviewer  (sonnet)
├── scan-qa-pb   ──┤        ├── ui-reviewer    (sonnet)       adapters/ (swappable)
├── scan-practices ┤        └── code-researcher (haiku)       ├── jira    (task-source)
└── ship         ──┘                                          ├── gitlab  (ci-cd)
                                                              ├── angular (tech-stack)
                                                              ├── figma   (design)
                                                              ├── architect-roles (architect-roles)
                                                              └── slack   (notification)
```

## Skill Catalog

### Core (invisible, auto-loaded)

| Skill | Lines | Purpose |
|-------|-------|---------|
| core/orchestration | 444 | Phases (1-9), handoffs, checkpoints, recovery, loops, routing, consensus activation |
| core/security | 151 | Universal OWASP checks. Framework-specific checks in tech-stack adapters (Section 7) |
| core/consensus-review | 211 | Multi-agent review pattern: 3 agents x different angles → aggregate |
| core/metrics | 235 | Pipeline metrics schema, phase ID normalization, collection, storage |
| core/ship-protocol | 134 | Shared ship steps: MR, merge, deploy, transition, notify. Used by worker Phase 9 and ship facade |

### Pipeline (project-agnostic phases)

| Skill | Lines | Model | Mode | Consensus (M+) | Purpose |
|-------|-------|-------|------|-----------------|---------|
| pipeline/worker | 654 | — | inline | — | Orchestrator: phases, checkpoints, dispatch |
| pipeline/impact-analyzer | 200 | sonnet | inline | — | Impact analysis: consumers, siblings, shared code |
| pipeline/planner | 427 | opus | inline | — | Research codebase, create plan (reads task-analysis.md) |
| pipeline/architect | 222 | opus | subagent | 3 agents + arbiter (M+) | Architectural analysis: 3 lenses → arbiter combines |
| pipeline/plan-reviewer | 235 | opus | subagent | 3x opus: AC + Architecture + Design | Validate plan |
| pipeline/coder | 303 | sonnet | inline | — | Evaluate gate + implement + commit gate |
| pipeline/figma-coding-rules | 380 | — | loaded by coder | — | Figma extract, self-verify, UI quality, icons |
| pipeline/code-reviewer | 319 | sonnet | subagent/worktree | 3x sonnet: Bugs + Compliance + Security | Review diff |
| pipeline/ui-reviewer | 498 | sonnet | subagent | 3x sonnet: Functional + Visual + States/A11y | Browser + Figma testing |
| pipeline/code-researcher | 101 | haiku | Agent tool | — | Cheap read-only search (L/XL only) |
| pipeline/researcher | 120 | opus | subagent | 3 agents: Figma + API + Functional | Deep task research (Phase 3, skip for S) |

### Adapters (swappable per project)

| Skill | Lines | Type | Key Methods |
|-------|-------|------|-------------|
| adapters/jira | 202 | task-source | fetch_task, fetch_attachments, parse_ac, transition, format_mr |
| adapters/gitlab | 304 | ci-cd | create_mr, pipeline, deploy, cherry_pick, CI disable/restore |
| adapters/angular | 361 | tech-stack | commands, quality_checks, security_checks, api_discovery, patterns, module_lookup |
| adapters/figma | 224 | design | get_design, get_screenshot, compare_visual, extract_tokens |
| adapters/architect-roles | 39 | architect-roles | roles (3 lenses), stack_constraints, generated_context |
| adapters/slack | 150 | notification | notify_deploy (env-based config, template with summary) |

### Facades (user-facing entry points)

| Skill | Lines | Triggers |
|-------|-------|----------|
| facades/figma-audit | 667 | `/figma`, "проверь верстку", "figma audit", "сравни с макетом" |
| facades/scan-qa-playbook | 211 | `/scan-qa`, "скан QA", "сгенерируй playbook" |
| facades/community-sync | 186 | `/sync`, "обновить ветки", "sync branches" |
| facades/scan-practices | 149 | `/scan-practices`, "скан практик" |
| facades/scan-ui-inventory | 132 | `/scan-ui`, "скан UI", "обнови инвентарь" |
| facades/worker | 45 | `/worker`, ARGO-XXX, "сделай задачу", "возьми тикет" |
| facades/ship | 227 | `/ship`, "закоммить и задеплой", "ship it" |
| facades/deploy | 34 | `/deploy`, "задеплой", "deploy to test/prod" |
| facades/architect | 61 | `/arch`, "архитектурный совет", "предложи архитектуру" |
| facades/arch-review | 126 | `/arch-review`, "оцени архитектуру", "review architecture" |
| facades/cr | 35 | `/cr`, `/code-review`, "проверь код", "code review" |
| facades/ui-review | 40 | `/ui-review`, "проверь UI", "UI review", "visual review" |

### Commands (19 slash commands)

| Command | Lines | Purpose |
|---------|-------|---------|
| /worker | 13 | Start full pipeline |
| /figma | 25 | Figma audit & implementation |
| /plan | 14 | Run planner only |
| /arch | 13 | Standalone architectural analysis |
| /arch-review | 13 | Retrospective architectural review |
| /cr | 15 | Code review |
| /code-review | 5 | Alias for /cr |
| /ui-review | 13 | UI review |
| /verify-figma | 53 | Figma CSS verification |
| /ship | 15 | Commit + push + deploy [+prod] [+mr] [+slack] |
| /deploy | 14 | Deploy to environment |
| /sync | 11 | Sync community branches |
| /attach | 169 | Attach to existing task |
| /continue | 95 | Resume from checkpoint |
| /progress | 28 | Show pipeline state |
| /cleanup | 26 | Clean up artifacts |
| /scan-ui | 9 | Scan UI inventory |
| /scan-qa | 9 | Generate QA playbook |
| /scan-practices | 9 | Scan project practices |

## Pipeline Phases

| Phase | Name | Model | Consensus (M+) | Skip |
|-------|------|-------|-----------------|------|
| 1 | analyze | sonnet | — | — |
| 2 | setup | sonnet | — | Resume |
| 3 | research | opus+sonnet | Yes (Figma + API + Functional) | S complexity |
| 4 | impact | sonnet | — | — |
| 5 | plan | opus | — (architect: 3 agents + arbiter for M+) | — |
| 6 | plan-review | opus | Yes (AC + Architecture + Design) | S complexity |
| 7 | implement | sonnet | — | — |
| 8 | review | sonnet | Yes (Code: Bugs+Compliance+Security / UI: Functional+Visual+States) | — |
| 9 | ship | sonnet | — | — |

### Phase 3: Research (Deep Task Analysis)

```yaml
agents:
  agent_1_figma (opus):    "All screens, states, flows, screenshots"
  agent_2_api (sonnet):    "Swagger → endpoints → OPTIONS test → classify working/broken/missing"
  agent_3_functional (opus): "Screens × endpoints → user flows + gaps (sequential, after 1+2)"

output: "docs/plans/{task-key}/task-analysis.md"
confirmation_gate: "Show user → y/edit/abort. Offer to create Jira tasks for missing endpoints."
```

### Phase 4: Impact Analysis

```yaml
analysis_types:
  consumers:  "Who imports/uses the files we're changing"
  siblings:   "Same bug pattern in neighboring components"
  shared_code: "Shared utilities/services → all consumers"

dispatch:
  S:   "Single agent, inline"
  M+:  "3 agents in parallel (consumer-scanner, sibling-scanner, shared-code-scanner)"

output: "docs/plans/{task-key}/impact-report.md"
```

### Phase 5: Plan (Architect Step)

```yaml
architect:
  skip: "S complexity"
  agents:
    agent_1: "Lens from architect-roles adapter (e.g., Component)"
    agent_2: "Lens from architect-roles adapter (e.g., State & Data)"
    agent_3: "Lens from architect-roles adapter (e.g., Integration)"
  arbiter: "Combines best elements from 3 proposals"
  output: "docs/plans/{task-key}/architecture.md"
  temporary: ".tmp/arch-agent-*.md"
```

## Model Routing

| Model | Skills | Purpose | Cost |
|-------|--------|---------|------|
| **opus** | planner, architect, plan-reviewer (consensus), Phase 3 agents 1+3 | Deep research, architectural analysis, analytical review | $$$ |
| **sonnet** | coder, code-reviewer (consensus), ui-reviewer (consensus), Phase 3 agent 2 | Implementation, pattern matching | $$ |
| **haiku** | code-researcher | Read-only search, data collection | $ |

## Complexity Routing

| Level | AC | Research | Architect | Plan Review | UI Review | Code Review | Consensus |
|-------|----|----------|-----------|-------------|-----------|-------------|-----------|
| S | 1-2 | skip | skip | skip | if design adapter | 1 agent | No |
| M | 3-4 | 3 agents | 3 agents + arbiter | 3x opus | if design: 3x sonnet | 3x sonnet | Yes |
| L | 5-6 | 3 agents | 3 agents + arbiter | 3x opus | 3x sonnet | 3x sonnet | Yes |
| XL | 7+ | 3 agents | 3 agents + arbiter | 3x opus | 3x sonnet | 3x sonnet | Yes |

## Adapter Contracts

```yaml
task-source:       fetch_task, fetch_attachments, parse_ac, get_complexity_hints, transition, format_mr_description
ci-cd:             create_mr, get_pipeline, wait_for_stage, deploy, retry_job, create_tag
tech-stack:        commands (lint/test/build), quality_checks, security_checks, api_discovery, patterns, module_lookup
design:            parse_urls, get_design, get_screenshot, compare_visual, extract_tokens
architect-roles:   roles (3 lenses), stack_constraints, generated_context
notification:      notify_deploy
```

## Project Configuration

```yaml
# .claude/project.yaml
version: "4.0"
task-source: jira
ci-cd: gitlab
tech-stack: angular
design: figma
notification: slack          # optional — QA deploy notifications
# Slack config lives in env vars (~/.zshrc), NOT in repo:
#   JIRA_BASE_URL, SLACK_QA_CHANNEL_ID, SLACK_QA_MENTION
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
| Atlassian | adapter-jira, Phase 3 | HALT (for Jira tasks) |
| Playwright / Chrome DevTools | ui-reviewer, figma-audit | Fallback: non-browser mode |

## Superpowers Integration

| Superpowers Skill | Used by |
|-------------------|---------|
| brainstorming | pipeline/planner, facades/architect |
| writing-plans | pipeline/planner |
| executing-plans | pipeline/coder (S, <3 parts) |
| subagent-driven-development | pipeline/coder (M+, 3+ parts) |
| dispatching-parallel-agents | pipeline/ui-reviewer, pipeline/impact-analyzer, facades/community-sync, Phase 3, figma-audit |
| figma:implement-design | pipeline/coder via figma-coding-rules |

## Output Files

```
docs/plans/{task-key}/
├── task-analysis.md       ← Phase 3 (Figma screens + API + flows)
├── impact-report.md       ← Phase 4 (consumers, siblings, shared code)
├── screenshots/           ← Phase 3 (Figma screenshots)
├── plan.md                ← Phase 5
├── architecture.md        ← Phase 5 (architect step)
├── .tmp/arch-agent-*.md   ← Phase 5 (temporary)
├── evaluate.md            ← Phase 7
├── figma-verify.md        ← Phase 7 (per-property Figma verification)
├── code-review.md         ← Phase 8
├── ui-review.md           ← Phase 8
├── checkpoint.yaml        ← Recovery
└── metrics.yaml           ← Phase 9

docs/figma-audit/{audit-id}/
├── figma-node-map.md      ← /figma Phase 1
├── figma-comparison.md    ← /figma Phase 2
├── property-diff.yaml     ← /figma Phase 2
├── implementation-summary.md ← /figma Phase 3
└── figma-audit-report.md  ← /figma Phase 4
```
