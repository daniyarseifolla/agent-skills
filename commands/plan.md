---
description: "Create implementation plan only (no coding). Usage: /plan ARGO-12345"
human_description: "Создать план реализации без кодирования."
---

# Plan Only

Task key: $ARGUMENTS

1. Load Skill: worker with override: "только план"
2. Run Phase 1: analyze + Phase 5: plan only
3. Output: docs/plans/{task-key}/plan.md + checklist.md
4. STOP after planning — do not proceed to implementation

If no arguments provided, ask user for task key.
