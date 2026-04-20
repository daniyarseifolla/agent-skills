---
description: "Run code review on current branch. Usage: /cr"
human_description: "Code review текущей ветки."
---

# Code Review (standalone)

Alias: /code-review also works

1. Load Skill: cr
2. Detect current branch
3. Find plan in docs/plans/ by branch name (if exists)
4. Run full code review: plan compliance, architecture, security (core-security), quality
5. Output: code-review.md

If no plan found → review diff only (skip plan compliance).
