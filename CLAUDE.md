# Agent Skills Repository

Reusable development pipeline skills for Claude Code with swappable adapters.

## Versions

- **v2.2/** — active version (CI disable/restore, worktree safety, workspace setup prompts)
- **v2.1/** — previous (visual-qa, css-styling-expert, Figma-first enforcement)
- **v2.0/** — archived (initial project-agnostic architecture)
- **v1.0/** — backup of original skills (Jira/Angular/GitLab specific, 8 monolithic skills)

See [v2.2/SKILLS_OVERVIEW.md](v2.2/SKILLS_OVERVIEW.md) for full architecture and catalog.

## Quick Reference

| Trigger | Facade | Pipeline |
|---------|--------|----------|
| ARGO-XXX, "сделай задачу" | jira-worker | worker → planner → review → coder → review → deploy |
| "deploy", "задеплой" | deploy | gitlab adapter direct |
| "sync branches" | community-sync | gitlab adapter + parallel cherry-pick |
| "scan UI" | scan-ui-inventory | standalone scan |

## Testing

Eval sets in `<skill>/evals/trigger-eval.json` test whether Claude correctly triggers each skill.
