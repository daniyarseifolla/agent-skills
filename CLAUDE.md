# Agent Skills Repository

Reusable development pipeline skills for Claude Code with swappable adapters.

## Versions

- **v3/** — active version
- **v1/** — archived (original Jira/Angular/GitLab-specific skills)

See [v3/SKILLS_OVERVIEW.md](v3/SKILLS_OVERVIEW.md) for full architecture and catalog.

## Quick Reference

| Trigger | Facade | Pipeline |
|---------|--------|----------|
| ARGO-XXX, "сделай задачу" | jira-worker | worker → planner → review → coder → review → deploy |
| "deploy", "задеплой" | deploy | gitlab adapter direct |
| `/ship`, "закоммить и задеплой" | ship | commit → push → deploy [+prod] [+mr] [+slack] |
| "sync branches" | community-sync | gitlab adapter + parallel cherry-pick |
| "scan UI" | scan-ui-inventory | standalone scan |

## Testing

Eval sets in `<skill>/evals/trigger-eval.json` test whether Claude correctly triggers each skill.
