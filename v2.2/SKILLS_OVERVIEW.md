# Agent Skills v2.2 — Overview

## Architecture

```
User triggers                    Pipeline (project-agnostic)           Core (invisible)
─────────────                    ──────────────────────────           ────────────────
facades/jira-worker  ──┐
facades/deploy       ──┤         pipeline/worker (orchestrator)       core/orchestration
facades/community-sync ┤           ├─ pipeline/planner     (opus)     core/security
facades/scan-ui-inv  ──┤           ├─ pipeline/plan-reviewer (sonnet)  core/metrics
facades/scan-qa-pb   ──┤           ├─ pipeline/coder       (sonnet)
facades/scan-practices ┘           ├─ pipeline/code-reviewer (sonnet)
                                   ├─ pipeline/ui-reviewer  (sonnet)
                                   └─ pipeline/code-researcher (haiku)

                                 Adapters (swappable per project)
                                 ───────────────────────────────
                                 adapters/jira      (task-source)
                                 adapters/gitlab    (ci-cd)
                                 adapters/angular   (tech-stack)
                                 adapters/figma     (design)
```

## Skill Catalog

### Core (invisible, auto-loaded)

| Skill | Lines | Purpose |
|-------|-------|---------|
| core/orchestration | 337 | Handoff, checkpoints, recovery, loop limits, evaluate gate, complexity routing, re-routing |
| core/security | ~150 | OWASP security checklist — universal checks only. Framework-specific checks in tech-stack adapters |
| core/consensus-review | 212 | Multi-agent consensus review pattern: 3 sections x 3 agents |
| core/metrics | 119 | Pipeline metrics collection and storage |

### Pipeline (project-agnostic phases)

| Skill | Lines | Model | Run as | Purpose |
|-------|-------|-------|--------|---------|
| pipeline/worker | 408 | — | inline | Orchestrator: config, adapters, phases, checkpoints |
| pipeline/planner | 264 | opus | inline | Research codebase, create plan |
| pipeline/coder | 270 | sonnet | inline | Evaluate gate + implement code |
| pipeline/figma-coding-rules | ~312 | — (disable-model-invocation) | loaded by coder | Figma extraction, self-verify, UI quality, icon rules |
| pipeline/plan-reviewer | 164 | sonnet | subagent | Validate plan against AC and architecture |
| pipeline/code-reviewer | 219 | sonnet | subagent/worktree | Review diff: plan compliance, security, quality |
| pipeline/ui-reviewer | 367 | sonnet | subagent | Functional + visual testing, parallel QA |
| pipeline/code-researcher | 101 | haiku | Agent tool | Cheap read-only codebase search (L/XL only) |

### Adapters (swappable per project)

| Skill | Lines | Type | Purpose |
|-------|-------|------|---------|
| adapters/jira | 178 | task-source | Fetch task, parse AC, transitions, MR description |
| adapters/gitlab | 304 | ci-cd | MR creation, pipeline monitoring, deploy, cherry-pick, CI disable/restore |
| adapters/angular | ~310 | tech-stack | Lint/test/build commands, quality patterns, security checks, module lookup |
| adapters/figma | 206 | design | Design context, screenshots, visual comparison, self-verify extraction |

### Facades (user-facing entry points)

| Skill | Lines | Triggers |
|-------|-------|----------|
| facades/jira-worker | 45 | ARGO-XXX, "сделай задачу", "возьми тикет", "implement" |
| facades/deploy | 34 | "задеплой", "deploy to test/prod", "check pipeline" |
| facades/community-sync | 181 | "обновить ветки", "sync branches", "distribute commit" |
| facades/scan-ui-inventory | 132 | "скан UI", "scan components", "обнови инвентарь" |
| facades/scan-qa-playbook | 211 | "скан QA", "scan QA", "сгенерируй playbook", "generate playbook" |
| facades/scan-practices | 149 | "скан практик", "scan practices", "обнови практики", "собери грабли" |
| facades/figma-audit | ~640 | "проверь верстку", "figma audit", "/figma", "сравни с макетом" |

### Commands (15 slash commands, including /code-review alias)

| Command | Lines | Trigger |
|---------|-------|---------|
| /worker | 13 | Start full pipeline |
| /plan | 14 | Run planner only |
| /cr | 15 | Code review current diff |
| /code-review | 15 | Alias for /cr |
| /ui-review | 13 | UI review current state |
| /deploy | 14 | Deploy to environment |
| /sync | 11 | Sync community branches |
| /scan-ui | 9 | Scan UI inventory |
| /scan-qa | 9 | Generate QA playbook |
| /scan-practices | 9 | Scan project practices |
| /attach | 146 | Attach context (files, URLs, Figma) |
| /verify-figma | 53 | Verify Figma-to-code fidelity |
| /figma | ~25 | Figma audit & implementation pipeline |
| /progress | 24 | Show pipeline progress |
| /continue | 28 | Resume from checkpoint |
| /cleanup | 18 | Clean up worktrees and branches |

## Model Routing

| Model | Skills | Purpose | Cost |
|-------|--------|---------|------|
| **opus** | planner | Deep research, architecture decisions | $$$ |
| **sonnet** | coder, plan-reviewer, code-reviewer, ui-reviewer | Implementation, review | $$ |
| **haiku** | code-researcher | Read-only search, data collection | $ |

## Complexity Routing

| Level | AC | Modules | Plan Review | UI Review | Code Researcher | Sequential Thinking |
|-------|-----|---------|-------------|-----------|-----------------|---------------------|
| S | 1-2 | 1 | skip | skip | no | no |
| M | 3-4 | 2 | standard | if design | no | optional |
| L | 5-6 | 3+ | standard | yes | yes | recommended |
| XL | 7+ | 4+ | standard | yes | yes | required |

## What's New in v2.2

| Feature | v1.0 | v2.2 |
|---------|------|------|
| Skills | 8 monolithic | 22 focused |
| Commands | — | 15 slash commands |
| Max lines/skill | 443 | 408 |
| Model routing | none | opus/sonnet/haiku |
| Security checks | none | OWASP checklist |
| Session recovery | none | checkpoint + heuristic |
| Review loops | 1 attempt | max 3 iterations |
| Evaluate gate | none | PROCEED/REVISE/RETURN |
| Project-agnostic | no | yes (adapter pattern) |
| Complexity levels | 2 | 4 |
| Metrics | none | collected at completion |
| CI on feature branches | always on | disable/restore around work |
| Worktree safety | none | isolated review in worktrees |
| Figma fidelity | manual | self-verify post-write |
| UI rules | none | refactoring-ui enforced |
| QA approach | single pass | parallel QA (visual + functional) |
| QA playbook | none | scan-qa-playbook facade |
| Project practices | none | scan-practices facade |

## External Skill Dependencies

| External Skill | Used by | Purpose |
|---------------|---------|---------|
| visual-qa | pipeline/ui-reviewer | Screenshot-based QA: spacing rhythm, alignment, typography consistency, polish |
| css-styling-expert | pipeline/coder | CSS architecture: Grid/Flex decisions, responsive, performance, accessibility |
| refactoring-ui | pipeline/coder, pipeline/ui-reviewer | UI design rules: spacing, typography, color, layout patterns |
| qa-test-planner | pipeline/ui-reviewer | Test strategy, edge cases, risk analysis |
| ui-ux-pro-max | pipeline/ui-reviewer | Advanced UI/UX review: micro-interactions, accessibility, design system compliance |

## Adapter Contracts

Each adapter type implements a known interface:

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
```

Fallback: autodetect from package.json, .gitlab-ci.yml, task URL.

## Superpowers Integration

| Superpowers Skill | Used by |
|-------------------|---------|
| brainstorming | pipeline/planner |
| writing-plans | pipeline/planner |
| executing-plans | pipeline/coder (S complexity, <3 parts) |
| subagent-driven-development | pipeline/coder (M/L/XL, 3+ parts) |
| dispatching-parallel-agents | pipeline/ui-reviewer, facades/community-sync |
| figma:implement-design | pipeline/coder via figma-coding-rules (when design adapter active) |
