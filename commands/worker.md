---
description: "Full-cycle task implementation pipeline. Usage: /worker ARGO-12345 or /worker <task-url>"
human_description: "Полный цикл реализации задачи: от анализа до деплоя."
---

# Worker Pipeline

Task key or URL: $ARGUMENTS

1. Load Skill: pipeline-worker
2. Pass task key: "$ARGUMENTS"
3. pipeline-worker runs full pipeline

If no arguments provided, ask user for task key.
