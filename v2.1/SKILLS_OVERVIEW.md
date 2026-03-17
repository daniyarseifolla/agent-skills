# Agent Skills v2.0 — Overview

## Architecture

```
User triggers                    Pipeline (project-agnostic)           Core (invisible)
─────────────                    ──────────────────────────           ────────────────
facades/jira-worker  ──┐
facades/deploy       ──┤         pipeline/worker (orchestrator)       core/orchestration
facades/community-sync ┤           ├─ pipeline/planner     (opus)     core/security
facades/scan-ui-inv  ──┘           ├─ pipeline/plan-reviewer (sonnet)  core/metrics
                                   ├─ pipeline/coder       (sonnet)
                                   ├─ pipeline/code-reviewer (sonnet)
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
| core/orchestration | 219 | Handoff, checkpoints, recovery, loop limits, evaluate gate, complexity routing, re-routing |
| core/security | 187 | OWASP security checklist with grep patterns (XSS, injection, auth, secrets, CSRF) |
| core/metrics | 113 | Pipeline metrics collection and storage |

### Pipeline (project-agnostic phases)

| Skill | Lines | Model | Run as | Purpose |
|-------|-------|-------|--------|---------|
| pipeline/worker | 237 | — | inline | Orchestrator: config, adapters, phases, checkpoints |
| pipeline/planner | 194 | opus | inline | Research codebase, create plan |
| pipeline/coder | 153 | sonnet | inline | Evaluate gate + implement code |
| pipeline/plan-reviewer | 164 | sonnet | subagent | Validate plan against AC and architecture |
| pipeline/code-reviewer | 194 | sonnet | subagent/worktree | Review diff: plan compliance, security, quality |
| pipeline/ui-reviewer | 155 | sonnet | subagent | Functional + visual testing |
| pipeline/code-researcher | 101 | haiku | Task tool | Cheap read-only codebase search (L/XL only) |

### Adapters (swappable per project)

| Skill | Lines | Type | Purpose |
|-------|-------|------|---------|
| adapters/jira | 149 | task-source | Fetch task, parse AC, transitions, MR description |
| adapters/gitlab | 171 | ci-cd | MR creation, pipeline monitoring, deploy, cherry-pick |
| adapters/angular | 162 | tech-stack | Lint/test/build commands, quality patterns, module lookup |
| adapters/figma | 145 | design | Design context, screenshots, visual comparison |

### Facades (user-facing entry points)

| Skill | Lines | Triggers |
|-------|-------|----------|
| facades/jira-worker | 45 | ARGO-XXX, "сделай задачу", "возьми тикет", "implement" |
| facades/deploy | 34 | "задеплой", "deploy to test/prod", "check pipeline" |
| facades/community-sync | 51 | "обновить ветки", "sync branches", "distribute commit" |
| facades/scan-ui-inventory | 62 | "скан UI", "scan components", "обнови инвентарь" |

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

## What's New in v2.0

| Feature | v1.0 | v2.0 |
|---------|------|------|
| Skills | 8 monolithic | 18 focused |
| Max lines/skill | 443 | 237 |
| Model routing | none | opus/sonnet/haiku |
| Security checks | none | OWASP checklist |
| Session recovery | none | checkpoint + heuristic |
| Review loops | 1 attempt | max 3 iterations |
| Evaluate gate | none | PROCEED/REVISE/RETURN |
| Project-agnostic | no | yes (adapter pattern) |
| Complexity levels | 2 | 4 |
| Metrics | none | collected at completion |

## External Skill Integration (v2.1)

| External Skill | Used by | Purpose |
|---------------|---------|---------|
| visual-qa | pipeline/ui-reviewer | Screenshot-based QA: spacing rhythm, alignment, typography consistency, polish |
| css-styling-expert | pipeline/coder | CSS architecture: Grid/Flex decisions, responsive, performance, accessibility |
| figma:implement-design | pipeline/coder | 1:1 Figma-to-code for UI components |

## Adapter Contracts

Each adapter type implements a known interface:

```yaml
task-source:     fetch_task, parse_ac, get_complexity_hints, transition, format_mr_description
ci-cd:           create_mr, get_pipeline, wait_for_stage, deploy, retry_job, create_tag
tech-stack:      commands (lint/test/build), quality_checks, patterns, module_lookup
design:          parse_urls, get_design, get_screenshot, compare_visual, extract_tokens
```

## Project Configuration

```yaml
# .claude/project.yaml
version: "2.0"
task-source: jira
ci-cd: gitlab
tech-stack: angular
design: figma
```

Fallback: autodetect from package.json, .gitlab-ci.yml, task URL.

## Superpowers Integration

| Superpowers Skill | Used by |
|-------------------|---------|
| brainstorming | pipeline/planner, pipeline/ui-reviewer |
| writing-plans | pipeline/planner |
| executing-plans | pipeline/worker (SIMPLE mode) |
| subagent-driven-development | pipeline/worker (FULL mode) |
| dispatching-parallel-agents | pipeline/ui-reviewer, facades/community-sync |
| figma:implement-design | pipeline/coder (when design adapter active) |
