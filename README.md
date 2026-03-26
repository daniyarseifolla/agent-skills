# Agent Skills

Reusable development pipeline skills for Claude Code. Automates the full cycle: task analysis, planning, implementation, review, and deployment.

## Quick Start

```bash
# Full task pipeline (Jira + Figma + Angular + GitLab)
/worker ARGO-12345

# Figma audit: compare implementation vs design, fix mismatches
/figma https://figma.com/design/XXX/YYY?node-id=123:456 http://localhost:4200

# Deploy
/deploy test

# Sync commit to community branches
/sync
```

## What It Does

`/worker ARGO-12345` runs a multi-phase pipeline:

```
Phase 0   — Fetch task from Jira, classify complexity (S/M/L/XL)
Phase 0.5 — Create branch, optional worktree, disable CI
Phase 0.7 — Deep analysis: explore ALL Figma screens, test Swagger endpoints, build functional map
Phase 1   — Plan implementation (opus model)
Phase 2   — Review plan with 3 consensus agents (AC, architecture, design coverage)
Phase 3   — Implement code with Figma self-verify and commit gate
Phase 4+5 — Code review + UI review in parallel (3 consensus agents each)
Phase 6   — Create MR, deploy, collect metrics
```

For simple tasks (S complexity), heavy phases are skipped automatically.

## Architecture

```
facades/         — entry points (jira-worker, deploy, sync, figma-audit, scans)
  pipeline/      — phases (worker, planner, coder, reviewers)
    core/        — protocols (orchestration, security, metrics, consensus)
      adapters/  — swappable (jira, gitlab, angular, figma)
```

23 skills | 16 commands | 5,863 lines

## Skills

### Core (invisible, auto-loaded)
| Skill | Purpose |
|-------|---------|
| orchestration | Phases, handoffs, checkpoints, recovery, routing |
| security | OWASP checks (universal). Framework-specific in adapters |
| consensus-review | Multi-agent review pattern: 3 agents, different angles |
| metrics | Pipeline metrics collection |

### Pipeline
| Skill | Model | Purpose |
|-------|-------|---------|
| worker | — | Orchestrates all phases |
| planner | opus | Research codebase, create plan |
| plan-reviewer | opus | Validate plan (3x consensus for M+) |
| coder | sonnet | Implement with Figma self-verify |
| figma-coding-rules | — | CSS extraction, verification, UI rules |
| code-reviewer | sonnet | Review diff (3x consensus for M+) |
| ui-reviewer | sonnet | Browser testing + visual comparison (3x consensus for M+) |
| code-researcher | haiku | Cheap read-only search for L/XL |

### Adapters
| Skill | Type | Stack |
|-------|------|-------|
| jira | task-source | Atlassian Jira |
| gitlab | ci-cd | GitLab CI/CD |
| angular | tech-stack | Angular/Nx |
| figma | design | Figma MCP |

### Facades
| Skill | Trigger |
|-------|---------|
| jira-worker | `/worker`, ARGO-XXX |
| figma-audit | `/figma`, "проверь верстку" |
| deploy | `/deploy` |
| community-sync | `/sync` |
| scan-ui-inventory | `/scan-ui` |
| scan-practices | `/scan-practices` |
| scan-qa-playbook | `/scan-qa` |

## Commands

| Command | Purpose |
|---------|---------|
| `/worker ARGO-XXX` | Full pipeline |
| `/figma URL [app-url]` | Figma audit + fix/build |
| `/plan ARGO-XXX` | Plan only (no code) |
| `/cr` | Code review current branch |
| `/ui-review [app-url]` | UI review |
| `/verify-figma [url]` | CSS property comparison |
| `/deploy test\|prod` | Deploy |
| `/sync [hash]` | Sync community branches |
| `/attach [ARGO-XXX]` | Attach to existing task |
| `/continue ARGO-XXX` | Resume from checkpoint |
| `/progress [ARGO-XXX]` | Show pipeline state |
| `/cleanup ARGO-XXX` | Remove artifacts |
| `/scan-ui` | Scan UI components |
| `/scan-qa` | Generate QA playbook |
| `/scan-practices` | Scan project conventions |

## Installation

Skills are installed globally in `~/.claude/skills/`, commands in `~/.claude/commands/`.

```bash
# From this repo — sync all skills to global
cd ~/Desktop/pet/agent-skills

# Ensure directories exist
mkdir -p ~/.claude/skills ~/.claude/commands ~/.claude/scripts

# Skills
for dir in v2.2/core/*/; do mkdir -p ~/.claude/skills/$(basename $dir) && cp "$dir/SKILL.md" ~/.claude/skills/$(basename $dir)/SKILL.md; done
for dir in v2.2/pipeline/*/; do
  name=$(basename $dir)
  [ "$name" = "figma-coding-rules" ] && target=$name || target="pipeline-$name"
  cp "$dir/SKILL.md" ~/.claude/skills/$target/SKILL.md
done
for dir in v2.2/adapters/*/; do cp "$dir/SKILL.md" ~/.claude/skills/adapter-$(basename $dir)/SKILL.md; done
for dir in v2.2/facades/*/; do cp "$dir/SKILL.md" ~/.claude/skills/$(basename $dir)/SKILL.md; done

# Commands
cp v2.2/commands/*.md ~/.claude/commands/
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
```

Fallback: autodetect from `package.json`, `.gitlab-ci.yml`, task URL, `proxy.conf.json`.

## Requirements

- Claude Code with opus/sonnet/haiku access
- Figma MCP server (for design tasks)
- Atlassian MCP (for Jira tasks)
- Playwright or Chrome DevTools MCP (for UI review)
- `glab` CLI (for GitLab operations)

## Documentation

- `AGENT.md` — context transfer between sessions
- `v2.2/REPORT.md` — full system report
- `v2.2/SKILLS_OVERVIEW.md` — architecture and catalog
- `v2.2/CONSENSUS-REVIEW-v2.2.md` — 9-agent review results
- `docs/superpowers/specs/` — design specs
