---
name: cr
description: "Use when running code review on current branch. Triggered by /cr, /code-review, 'review my code', 'code review'."
human_description: "Code review: detect branch context, load project config, delegate to pipeline-code-reviewer."
---

# CR — Facade

Standalone code review of current branch. Delegates to pipeline-code-reviewer.

## Activation

Triggers on code review phrases in any language (RU/EN).

## Delegation

1. Read `.claude/project.yaml` for tech-stack adapter (lint/test commands used in review)
2. Detect current branch and base branch:
   ```yaml
   branch: "git rev-parse --abbrev-ref HEAD"
   base_branch: "project.yaml → project.branches.main (fallback: develop)"
   ```
3. Check for plan in `docs/plans/` by branch name (e.g., `feat/ARGO-123` → `docs/plans/ARGO-123/plan.md`)
4. Load Skill: pipeline-code-reviewer with context:
   ```yaml
   branch: "{current_branch}"
   base_branch: "{base_branch}"
   tech_stack_adapter: "from project.yaml"
   plan_path: "docs/plans/{task-key}/plan.md (if exists)"
   ```

## Behavior

- If plan found → full review: plan compliance + architecture + security + quality
- If no plan found → review diff only (skip plan compliance)
- Output: `code-review.md`
