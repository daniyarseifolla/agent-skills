---
description: "Full-cycle task implementation pipeline. Usage: /worker ARGO-12345 or /worker <jira-url>"
human_description: "Полный цикл реализации Jira-задачи: от анализа до деплоя."
---

# Worker Pipeline

Task key or URL: $ARGUMENTS

1. Load Skill: jira-worker
2. Pass task key: "$ARGUMENTS"
3. jira-worker delegates to pipeline-worker with full pipeline

If no arguments provided, ask user for task key.
