---
description: "Create implementation plan only (no coding). Usage: /plan ARGO-12345"
---

# Plan Only

Task key: $ARGUMENTS

1. Load Skill: jira-worker with override: "только план"
2. Run Phase 0 (task analysis) + Phase 1 (planning) only
3. Output: docs/plans/{task-key}/plan.md + checklist.md
4. STOP after planning — do not proceed to implementation

If no arguments provided, ask user for task key.
