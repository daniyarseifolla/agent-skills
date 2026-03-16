# Agent Skills v2.0

Reusable, project-agnostic development pipeline skills for Claude Code.

## Quick Start

### 1. Install skills

```bash
# Copy to global skills directory
cp -r v2.0/* ~/.claude/skills/

# Or symlink for development
ln -s $(pwd)/v2.0/* ~/.claude/skills/
```

### 2. Configure project

```bash
# Copy config template to your project
cp v2.0/project.yaml.example /path/to/project/.claude/project.yaml
# Edit: set task-source, ci-cd, tech-stack, design
```

Or skip config — worker will autodetect from project files.

### 3. Use

```
> ARGO-12345                    # triggers jira-worker → full pipeline
> deploy to test                # triggers deploy → gitlab adapter
> sync branches                 # triggers community-sync
> scan UI                       # triggers scan-ui-inventory
```

## Architecture

```
facades/  → user-facing triggers (thin, 34-62 lines)
pipeline/ → project-agnostic phases (worker, planner, coder, reviewers)
adapters/ → swappable integrations (jira, gitlab, angular, figma)
core/     → invisible internals (orchestration, security, metrics)
```

See [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md) for full catalog.

## Adding a New Adapter

1. Create `adapters/{name}/SKILL.md`
2. Implement the adapter contract for its type (task-source, ci-cd, tech-stack, or design)
3. Add autodetect rule to `pipeline/worker` (optional)
4. Users set `{type}: {name}` in `.claude/project.yaml`

Example: adding GitHub Actions support
```yaml
# adapters/github-actions/SKILL.md
---
name: adapter-github-actions
description: "GitHub Actions CI/CD adapter..."
disable-model-invocation: true
---
# Implements ci-cd contract: create_mr (→ gh pr create), deploy, get_pipeline, etc.
```

## Versioning

- **v1.0/** — original skills (Jira/Angular/GitLab hardcoded, 8 monolithic skills)
- **v2.0/** — restructured (project-agnostic, 18 focused skills, model routing)

To rollback: `cp -r v1.0/* ~/.claude/skills/`
