# Agent Skills

Reusable development pipeline skills for Claude Code. Automates the full cycle: task analysis, planning, implementation, review, and deployment.

## Structure

```
pipeline/        — phases (worker, planner, architect, coder, reviewers)
adapters/        — swappable integrations (jira, gitlab, angular, figma, slack, architect-roles)
core/            — protocols (orchestration, security, metrics, consensus, ship-protocol)
facades/         — entry points (worker, architect, arch-review, deploy, sync, figma-audit, scans)
commands/        — 19 slash commands
docs/            — specs, plans, reviews
research/        — analysis and research notes
```

## Quick Start

```bash
# Full task pipeline (Jira + Figma + Angular + GitLab)
/worker ARGO-12345

# Architectural analysis — 3 approaches with trade-offs
/arch "как лучше спроектировать систему нотификаций"

# Architecture review of existing code
/arch-review src/features/notifications

# Figma audit: compare implementation vs design
/figma https://figma.com/design/XXX/YYY?node-id=123:456 http://localhost:4200

# Deploy
/deploy test

# Commit + push + deploy
/ship

# Sync commit to community branches
/sync
```

## How It Works

`/worker ARGO-12345` runs a multi-phase pipeline:

```
Phase 1: analyze     Fetch task from Jira, classify complexity (S/M/L/XL)
Phase 2: setup       Create branch, optional worktree, disable CI
Phase 3: research    Deep analysis: Figma screens, Swagger endpoints, functional map
Phase 4: impact      Impact analysis: consumers, siblings, shared code
Phase 5: plan        Architect (3 agents M+) + plan implementation (opus model)
Phase 6: plan-review Review plan with consensus agents
Phase 7: implement   Implement code with Figma self-verify, per-part checkpoint
Phase 8: review      Code review + UI review in parallel
Phase 9: ship        Create MR, deploy, collect metrics
```

Simple tasks (S complexity) skip heavy phases automatically.

## Commands

| Command | Purpose |
|---------|---------|
| `/worker ARGO-XXX` | Full pipeline |
| `/arch [task\|description]` | Architectural analysis (3 approaches) |
| `/arch-review [task\|path]` | Architecture review of existing code |
| `/plan ARGO-XXX` | Plan only |
| `/cr` | Code review current branch |
| `/ui-review [url]` | UI review |
| `/figma URL [app-url]` | Figma audit + fix |
| `/verify-figma [url]` | CSS comparison |
| `/deploy test\|prod` | Deploy |
| `/ship` | Commit + push + deploy |
| `/sync [hash]` | Sync community branches |
| `/attach [ARGO-XXX]` | Attach to existing task |
| `/continue ARGO-XXX` | Resume from checkpoint |
| `/progress` | Show pipeline state |
| `/cleanup ARGO-XXX` | Remove artifacts |
| `/scan-ui` | Scan UI components |
| `/scan-qa` | Generate QA playbook |
| `/scan-practices` | Scan project conventions |

## Installation

Source: this repo → `~/.claude/skills/`.

Copy skills to your Claude Code skills directory:
```bash
cp -r pipeline/ adapters/ core/ facades/ ~/.claude/skills/
cp commands/*.md ~/.claude/commands/
```

## Requirements

- Claude Code with opus/sonnet/haiku access
- Figma MCP server (for design tasks)
- Atlassian MCP (for Jira tasks)
- Playwright or Chrome DevTools MCP (for UI review)
- `glab` CLI (for GitLab operations)
