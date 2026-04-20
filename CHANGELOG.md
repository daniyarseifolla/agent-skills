# Changelog

## 4.1 (2026-04-20)

### Architecture
- Canonical checkpoint format: named phases only, atomic write-then-rename
- Ship unification: core-ship-protocol is single source of truth
- Worker merge: facade→pipeline hop eliminated, entry point inlined
- Facades for /cr, /ui-review, /continue — all commands route through facades
- Layer ownership documented: facades can load adapters for context
- Brainstorming ownership: pipeline/planner is the single owner

### Safety
- disable-model-invocation on all 6 adapters
- Dispatch budget: S=5, M=20, L=35, XL=45 with confirmation gate
- Preflight check for 6 external skills at startup
- Context budget tracking with lazy adapter loading

### Quality
- Phase 3 research extracted to pipeline/researcher
- Doc consolidation: AGENT.md 106→45, README 100→44 lines
- Contract validation evals (27 adapter methods + 9 checkpoint fields)
- scripts/check-drift.sh (7 inventory checks + line count tolerance)
- scripts/check-contracts.sh (36 contract compliance checks)
- Pre-commit hook for drift + contract checks

### Fixes
- Checkpoint: numbered phases → named, unified fallback rule
- UI-review handoff: added missing app_url + credentials
- /attach: autodetect instead of hardcoded adapter-jira
- arch-review: adapter-based base branch instead of hardcoded develop
- Ship --sync removed (was promised but never implemented)
- Stale files: command counts, deleted ports/ reference, worker.md

## 4.0 (2026-04-19)

Initial v4 architecture: 5-layer model, adapter contracts, consensus review,
checkpoint/recovery, model routing, complexity routing.
