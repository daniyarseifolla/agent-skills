---
description: "Continue interrupted pipeline from last checkpoint. Usage: /continue [ARGO-12345]"
argument: "task_key (optional — auto-detect from branch or commits)"
human_description: "Продолжить pipeline с последнего checkpoint-а."
---

# Resume Pipeline

Task key: $ARGUMENTS

1. Parse argument if provided
2. Load Skill: continue
3. Pass argument to facade
