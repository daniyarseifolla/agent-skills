# Trigger Verification Report

**Date:** 2026-04-19
**Skills tested:** architect, arch-review
**Method:** 4 sonnet subagents, each with 10 queries against full skill list
**Result:** 40/40 (100%)

## Results

| Test | Score |
|------|-------|
| architect should-trigger (10 queries) | 10/10 |
| architect should-NOT-trigger (10 queries) | 10/10 |
| arch-review should-trigger (10 queries) | 10/10 |
| arch-review should-NOT-trigger (10 queries) | 10/10 |

## Key Boundary Cases

- "оцени архитектуру" → arch-review (retrospective) ✅
- "предложи архитектуру" → architect (new design) ✅
- "/arch ARGO-11200" → architect (command prefix wins over jira-worker) ✅
- "предложи улучшения к коду" → arch-review (context "к коду" = existing code) ✅ ⚠️ high-risk

## Trigger Eval Coverage

| Facade | Eval file | Queries |
|--------|-----------|---------|
| architect | facades/architect/evals/trigger-eval.json | 20 |
| arch-review | facades/arch-review/evals/trigger-eval.json | 20 |
| jira-worker | facades/jira-worker/evals/trigger-eval.json | 20 |
| ship | facades/ship/evals/trigger-eval.json | 20 |
| deploy | facades/deploy/evals/trigger-eval.json | 20 |
| community-sync | facades/community-sync/evals/trigger-eval.json | 20 |
| figma-audit | facades/figma-audit/evals/trigger-eval.json | 20 |
| scan-ui-inventory | facades/scan-ui-inventory/evals/trigger-eval.json | 20 |
| scan-qa-playbook | facades/scan-qa-playbook/evals/trigger-eval.json | 20 |
| scan-practices | facades/scan-practices/evals/trigger-eval.json | 20 |
| **Total** | **10 facades** | **200 queries** |
