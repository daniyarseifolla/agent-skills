---
description: "Deploy to test or production. Usage: /deploy [test|prod] or /deploy check"
human_description: "Деплой на test или production."
---

# Deploy

Arguments: $ARGUMENTS

1. Load Skill: deploy
2. Execute deployment based on arguments:
   - No args or "test" → deploy current branch to test
   - "prod" → deploy to production (requires confirmation)
   - "check" → check pipeline status
   - "retry" → retry failed job
