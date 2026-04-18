# Agent Skills

Reusable development pipeline skills for Claude Code. Automates the full cycle: task analysis, planning, implementation, review, and deployment.

## Structure

```
v3/              — active version
  adapters/      — swappable integrations (jira, gitlab, angular, figma)
  commands/      — slash commands
  core/          — protocols (orchestration, security, metrics, consensus)
  facades/       — entry points (jira-worker, deploy, sync, figma-audit, scans)
  pipeline/      — phases (worker, planner, coder, reviewers)
v1/              — archived (original Jira/Angular/GitLab-specific skills)
docs/            — specs and plans
ports/           — cross-agent portability (Codex, Literal)
research/        — analysis and research notes
```

## Quick Start

```bash
# Full task pipeline (Jira + Figma + Angular + GitLab)
/worker ARGO-12345

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
Phase 5: plan        Plan implementation (opus model)
Phase 6: plan-review Review plan with consensus agents
Phase 7: implement   Implement code with Figma self-verify
Phase 8: review      Code review + UI review in parallel
Phase 9: ship        Create MR, deploy, collect metrics
```

Simple tasks (S complexity) skip heavy phases automatically.

## Commands

| Command | Purpose |
|---------|---------|
| `/worker ARGO-XXX` | Full pipeline |
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

See [v3/README.md](v3/README.md) for install instructions. Source: this repo → `~/.claude/skills/`.

## Requirements

- Claude Code with opus/sonnet/haiku access
- Figma MCP server (for design tasks)
- Atlassian MCP (for Jira tasks)
- Playwright or Chrome DevTools MCP (for UI review)
- `glab` CLI (for GitLab operations)
