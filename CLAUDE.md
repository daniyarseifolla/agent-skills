# Agent Skills Repository

Reusable development pipeline skills for Claude Code with swappable adapters.

## Version

Version 4.0 — see VERSION file

See [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md) for full architecture and catalog.

## Quick Reference

| Trigger | Facade | Pipeline |
|---------|--------|----------|
| ARGO-XXX, "сделай задачу" | worker | worker → planner → review → coder → review → deploy |
| "deploy", "задеплой" | deploy | gitlab adapter direct |
| `/ship`, "закоммить и задеплой" | ship | commit → push → deploy [+prod] [+mr] [+slack] |
| "sync branches" | community-sync | gitlab adapter + parallel cherry-pick |
| "scan UI" | scan-ui-inventory | standalone scan |
| "архитектурный совет", /arch | architect | planner (architect step) |
| "оцени архитектуру", /arch-review | arch-review | 3 review → 3 alternatives |

## Testing

Eval sets in `<skill>/evals/trigger-eval.json` test whether Claude correctly triggers each skill.
