---
description: "Run code review on current branch. Usage: /review"
---

# Code Review (standalone)

1. Load Skill: pipeline-code-reviewer
2. Detect current branch
3. Find plan in docs/plans/ by branch name (if exists)
4. Run full code review: plan compliance, architecture, security (core-security), quality
5. Output: code-review.md

If no plan found → review diff only (skip plan compliance).
