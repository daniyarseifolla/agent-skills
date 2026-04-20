---
name: ui-review
description: "Use when running UI review with browser testing and Figma comparison. Triggered by /ui-review, 'UI review', 'visual review'."
human_description: "UI review: load design adapter, detect branch and Figma URLs, delegate to pipeline-ui-reviewer."
---

# UI Review — Facade

Standalone UI review: functional testing + Figma visual comparison. Delegates to pipeline-ui-reviewer.

## Activation

Triggers on UI review phrases in any language (RU/EN).

## Syntax

```
/ui-review [app-url]
```

Arguments: $ARGUMENTS

## Delegation

1. Read `.claude/project.yaml` for design adapter (Figma URLs) and tech-stack adapter (serve command)
2. Parse optional `app_url` from user arguments; if not provided → detect or ask
3. Detect current branch:
   ```yaml
   branch: "git rev-parse --abbrev-ref HEAD"
   ```
4. Find Figma URLs in `docs/plans/` by branch name (e.g., `feat/ARGO-123` → task context)
5. Resolve credentials from task-source adapter or ask user
6. Load Skill: pipeline-ui-reviewer with context:
   ```yaml
   branch: "{current_branch}"
   app_url: "{from args or detected}"
   figma_urls: "string[] from task context or project.yaml"
   design_adapter: "from project.yaml"
   tech_stack_adapter: "from project.yaml"
   credentials: "from task-source adapter; fallback: ask user"
   ```

## Behavior

- Runs: functional tests (browser) + visual comparison (Figma) + visual QA (screenshots)
- Output: `ui-review.md`
