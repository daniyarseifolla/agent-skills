# Agent Skills Repository

Reusable development pipeline skills for Claude Code with swappable adapters.

## Versions

- **v2.0/** — active version (project-agnostic, 18 focused skills, model routing, security, recovery)
- **v1.0/** — backup of original skills (Jira/Angular/GitLab specific, 8 monolithic skills)

See [v2.0/SKILLS_OVERVIEW.md](v2.0/SKILLS_OVERVIEW.md) for full architecture and catalog.

## Quick Reference

| Trigger | Facade | Pipeline |
|---------|--------|----------|
| ARGO-XXX, "сделай задачу" | jira-worker | worker → planner → review → coder → review → deploy |
| "deploy", "задеплой" | deploy | gitlab adapter direct |
| "sync branches" | community-sync | gitlab adapter + parallel cherry-pick |
| "scan UI" | scan-ui-inventory | standalone scan |

## Testing

Eval sets in `<skill>/evals/trigger-eval.json` test whether Claude correctly triggers each skill.
