# Consensus Review v2.2 Round 2 — 9 Agent Results

**Date:** 2026-03-26
**Scope:** All 23 skills + 16 commands (post Phase 0.7, consensus 3x3, figma-audit)

## Section Scores

| Section | Agent | Score |
|---------|-------|-------|
| S1A Phase flow + layers | 8.3 avg |
| S1B Contracts + handoffs | 8.0 avg |
| S1C Consistency + enforcement | 8.2 avg |
| S2A Core + Adapters | 8.5 avg |
| S2B Pipeline skills | 8.7 avg |
| S2C Facades + Commands | 7.8 avg |
| S3A E2E flow trace | 8.0/10 |
| S3B Error recovery | 6.5 avg |
| S3C Cost analysis | — |
| **Overall** | **~8.0/10** |

**Previous round:** 6.3/10 → **Current: ~8.0/10** (+1.7 improvement)

## Consensus BLOCKERS (2+ agents confirm)

| # | Finding | Agents | Impact |
|---|---------|--------|--------|
| B1 | **Plan-reviewer model: opus vs orchestration sonnet** — canonical table says sonnet, skill says opus | S1A, S1C, S2B, S3A (4) | Wrong model dispatched for plan review |
| B2 | **Phase 0.7 missing from metrics normalization** — duration never recorded | S1A, S1B, S2A (3) | Cost/time data lost for expensive phase |
| B3 | **UI-reviewer score 0-100 (Section 5) vs 1-10 (Section 6 consensus)** — incompatible handoff | S1C, S2B (2) | Consumer can't interpret score |
| B4 | **Credentials plaintext in checkpoint.yaml** committed to git | S3B (1, but critical) | Passwords from Jira in version control |

## Consensus MAJORS (2+ agents confirm)

| # | Finding | Agents |
|---|---------|--------|
| M1 | **checkpoint.phase_completed scalar vs completed_phases array** — recovery arithmetic breaks on 0→0.5→0.7→1 | S1A, S3A, S3B (3) |
| M2 | **Phase 0.7 / Phase 1 research overlap** — ux-flow-analyst re-does Phase 0.7 work | S1A, S2B (2) |
| M3 | **figma-audit bypasses core** — no checkpoint, no metrics, no /continue support | S1A, S1B (2) |
| M4 | **Missing Do-NOT guards** in plan-reviewer + code-reviewer consensus sections | S1C, S3A (2) |
| M5 | **Missing subagent_type: general-purpose** in plan-reviewer, code-reviewer, ui-reviewer | S1C, S2C (2) |
| M6 | **consensus-review integration table missing Phase 2** | S1A (1) |
| M7 | **No cost gate before consensus loop re-fires** (up to 78 agents in max-loop) | S3C (1) |
| M8 | **Jira adapter: zero error handling** vs GitLab (exemplary) | S2A (1) |
| M9 | **Phase 4+5 loop-back: app_url/credentials not re-passed** to ui-reviewer | S3A (1) |
| M10 | **Code-reviewer pre-checks not ordered before consensus dispatch** (9 agents launched on lint-failing branch) | S3A (1) |

## Key Unique Findings

| # | Finding | Agent |
|---|---------|-------|
| U1 | 6 of 9 plan-reviewer opus agents are pattern-matching → downgrade to sonnet saves 60% Phase 2 cost | S3C |
| U2 | phase_completed + 1 arithmetic fails on non-uniform float sequence | S3B |
| U3 | /attach uses completed_phases array, /continue reads phase_completed scalar | S3B |
| U4 | Planner Section 5 (L/XL research) is legacy, conflicts with step_3 consensus | S2B |
| U5 | figma-audit Phase 4 .tmp/ filenames not defined | S1B, S2C |
| U6 | community-sync report template has hardcoded TS2559 Angular error | S1A |

## Priority Fix List

### P1 — Fix plan-reviewer model in orchestration (B1)
One-line: Phase 2 `model: sonnet` → `model: opus`. 4 agents found this.

### P2 — Add Phase 0.7 to metrics (B2)
Add `deep-analysis` to normalization table + duration.per_phase. 3 agents found this.

### P3 — Normalize ui-reviewer score to 1-10 (B3)
Section 5 output: `{score}/100` → `{score}/10`. Update thresholds.

### P4 — Credential isolation (B4)
Move credentials to .gitignored file or env var. Never commit to git.

### P5 — Unify checkpoint schema (M1)
Replace `phase_completed + 1` with next_phase lookup table. Align /attach and /continue on same field name.

### P6 — Add dedup guard to planner Agent 3 (M2)
Skip Figma re-extraction if task-analysis.md has User Flows section.

### P7 — Add Do-NOT + subagent_type to reviewers (M4+M5)
plan-reviewer, code-reviewer, ui-reviewer consensus sections need MANDATORY + general-purpose.

### P8 — Add cost gate before consensus loops (M7)
Show "Loop iteration {N}/3. Dispatching {K} agents. Proceed?" before re-firing.

## Cost Analysis Summary (from S3C)

| Phase | Opus | Sonnet | Total |
|-------|------|--------|-------|
| 0.7 Deep Analysis | 2 | 1 | 3 |
| 1 Planning Research | 2 | 1 | 3 |
| 2 Plan Review (3x3) | 9 | 0 | 9 |
| 4 Code Review (3x3) | 0 | 9 | 9 |
| 5 UI Review (3x3) | 0 | 9 | 9 |
| **Total** | **13** | **20** | **33** |

Cost index: 13×5 + 20×1 = 85 sonnet-equivalent units per M+ run.
Max-loop scenario: up to 78 agents (~48 opus).

**S3C recommendation:** Downgrade 6 plan-reviewer agents from opus to sonnet (pattern-matching tasks). Keeps 3 opus for deep reasoning. Saves 60% on Phase 2.
