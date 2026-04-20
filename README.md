# Agent Skills

Reusable development pipeline skills for Claude Code. Automates the full cycle: task analysis, planning, implementation, review, and deployment.

For architecture, skill catalog, pipeline phases, and command reference see [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md).

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
```

## Installation

Source: this repo → `~/.claude/skills/`.

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
