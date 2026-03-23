---
description: "Show current pipeline progress. Usage: /progress [ARGO-12345]"
---

# Pipeline Progress

Task key: $ARGUMENTS

1. If task key provided → read docs/plans/{task-key}/checkpoint.yaml
2. If no task key → find most recent checkpoint in docs/plans/*/checkpoint.yaml
3. If no checkpoint found → "No active pipeline found"

Display:
```
Task: {task_key}
Phase: {phase_completed}/{total} — {phase_name}
Complexity: {complexity} → Route: {route}
Iterations: plan_review {N}/3, code_review {N}/3
CI: {disabled/enabled}
Worktree: {path or "main repo"}
Last update: {timestamp}
```

If phase < 6 → suggest: "Resume with /continue {task_key}"
