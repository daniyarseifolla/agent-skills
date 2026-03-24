# Consensus Review v2.2 — 9 Agent Results

**Date:** 2026-03-24
**Agents:** 9 (3 sections x 3 agents)
**Scope:** All 22 skills + 15 commands

## Section Scores

| Section | Agent | Angle | Score |
|---------|-------|-------|-------|
| S1: Architecture | S1A | Layer separation | 6/10 |
| | S1B | Handoff contracts | 6/10 |
| | S1C | Adapter swappability | 4/10 |
| **S1 avg** | | | **5.3/10** |
| S2: Quality | S2A | Core + Adapters | 7.3/10 |
| | S2B | Pipeline skills | 7.9/10 |
| | S2C | Facades + Commands | 6.8/10 |
| **S2 avg** | | | **7.3/10** |
| S3: Usability | S3A | End-to-end flow | 7.5/10 |
| | S3B | Error recovery | 6/10 |
| | S3C | External integration | 5/10 |
| **S3 avg** | | | **6.2/10** |
| **Overall** | | | **6.3/10** |

## Per-Skill Consensus Scores

Averaged across all agents that reviewed each skill.

| Skill | Consensus | AGENT.md predicted | Delta |
|-------|-----------|-------------------|-------|
| core/orchestration | **7.5** | 9 | -1.5 |
| core/security | **4.3** | 8 | **-3.7** |
| core/metrics | **7.2** | 7.5→9 | -0.3 |
| core/consensus-review | **6.8** | 8 | -1.2 |
| pipeline/worker | **6.5** | 8 | -1.5 |
| pipeline/planner | **6.4** | 8 | -1.6 |
| pipeline/coder | **6.3** | 7→9 | **-2.7** |
| pipeline/figma-coding-rules | **7.1** | 8 | -0.9 |
| pipeline/plan-reviewer | **8.1** | 8.5 | -0.4 |
| pipeline/code-reviewer | **6.9** | 8.5 | -1.6 |
| pipeline/ui-reviewer | **6.1** | 7→9 | **-2.9** |
| pipeline/code-researcher | **8.9** | 9 | -0.1 |
| adapters/jira | **8.1** | 8.5 | -0.4 |
| adapters/gitlab | **7.8** | 8.5 | -0.7 |
| adapters/angular | **8.3** | 8.5 | -0.2 |
| adapters/figma | **8.1** | 8 | +0.1 |
| facades/jira-worker | **7.0** | — | — |
| facades/deploy | **6.3** | — | — |
| facades/community-sync | **4.5** | — | — |
| facades/scan-ui-inventory | **5.8** | — | — |
| facades/scan-practices | **6.0** | — | — |
| facades/scan-qa-playbook | **6.5** | — | — |

**Top 3:** code-researcher (8.9), angular adapter (8.3), plan-reviewer (8.1)
**Bottom 3:** core/security (4.3), community-sync (4.5), scan-ui-inventory (5.8)

## Consensus Findings (2+ agents agree)

### BLOCKER — 3 confirmed

| # | Finding | Severity | Agents | Impact |
|---|---------|----------|--------|--------|
| C1 | **core/security is 60%+ Angular-specific** — loaded unconditionally by code-reviewer regardless of tech-stack | BLOCKER | S1A, S1C, S2A (3) | React/Go projects get false positives, miss framework-specific vectors |
| C2 | **community-sync hardcodes Angular + GitLab** — build fix strategy, error codes (TS2559, NG8002), glab CLI directly in facade | BLOCKER | S1A, S1C, S2C (3) | Facade unusable for non-Angular/GitLab projects |
| C3 | **Phase numbering inconsistency** — worker uses 0/0.5/1-6, metrics uses 0-7, orchestration uses 0-6, consensus-review off-by-one | BLOCKER | S1B, S2A, S2B, S3A, S3B (5) | Checkpoint recovery, metrics normalization, and consensus integration all produce wrong phase IDs |

### MAJOR — 7 confirmed

| # | Finding | Severity | Agents | Impact |
|---|---------|----------|--------|--------|
| C4 | **Angular-specific code leaked into pipeline layer** — planner fallback globs, ui-reviewer nativeInputValueSetter, code-reviewer .spec.ts pattern, figma-coding-rules Angular CDK | MAJOR | S1A, S1C, S2B, S2C (4) | Pipeline skills claim project-agnostic but contain Angular patterns |
| C5 | **Handoff contracts incomplete** — task object untyped, coder_evaluate_return contradicts itself, REJECTED verdict missing from coder input | MAJOR | S1B, S3A (2) | Agent receiving malformed handoff has no validation |
| C6 | **Self-Verify not enforced** — MANDATORY label exists but no commit gate requiring figma-verify.md before commit | MAJOR | S2B, S3B (2) | Known production issue: agents skip Self-Verify |
| C7 | **Figma MCP failure has no fallback in coder** — ui-reviewer has degraded mode, coder has zero recovery path | MAJOR | S3B, S3C (2) | Coder stalls mid-implementation with no error message |
| C8 | **PASS_WITH_ISSUES absent from verdict_mapping.allows_progress** — ui-reviewer emits it, worker can't parse it | MAJOR | S1B, S2A (2) | Pipeline stalls on non-trivial UI reviews |
| C9 | **Scan facades are Angular-only** — scan-ui-inventory, scan-practices hardcode Angular/Nx paths and patterns | MAJOR | S1A, S1C (2) | Scans produce empty results for non-Angular projects |
| C10 | **SKILLS_OVERVIEW.md is stale** — brainstorming listed for ui-reviewer (removed), subagent-driven-development attributed to worker (actually coder) | MAJOR | S3C, S2B (2) | New team members get wrong dependency picture |

### MINOR — 5 confirmed

| # | Finding | Severity | Agents |
|---|---------|----------|--------|
| C11 | /attach (146 lines) violates command/skill boundary | MINOR | S2C |
| C12 | /cr and /code-review are identical duplicates with circular alias references | MINOR | S2C |
| C13 | No model override mechanism for opus-only planner phase | MINOR | S3C |
| C14 | Credentials stored plaintext in checkpoint.yaml | MINOR | S3B |
| C15 | grep -rn patterns with negative lookaheads silently fail (need grep -P) | MINOR | S3B |

## Conflicts (agents disagree)

| # | Finding | Agent A | Agent B |
|---|---------|---------|---------|
| D1 | core/consensus-review upward dependency | S1A: 5/10 (violation — core knows pipeline names) | S1C: 9/10 (nearly clean) |
| D2 | Adapter angular quality | S1C: 9/10 (correctly scoped) | S2A: 7/10 (grep patterns unusable, dead skill references) |
| D3 | Facade-to-pipeline delegation | S2C: "all correct" | S1A: "community-sync has adapter logic in facade" |

## Unique Findings (1 agent only, notable)

| # | Finding | Agent | Confidence |
|---|---------|-------|------------|
| U1 | GitLab CI disable stub `rules: when: never` may cause validation error in strict mode | S2A | Medium |
| U2 | Jira adapter `parse_ac` missing Russian AC heading patterns (Критерии приемки) | S2A | High |
| U3 | community-sync worktree cleanup is unconditional — no safety checks | S3B | High |
| U4 | No startup health-check for external dependencies at Phase 0 | S3B | High |
| U5 | adapter-angular Section 6 references nonexistent external skills | S2A | High |
| U6 | Figma rate limits not propagated to consuming skills (coder, planner) | S3C | Medium |

## Prediction vs Reality

AGENT.md predicted **8.5-9.0** post-refactor. Actual consensus: **6.3/10**.

The gap is explained by:
1. **Layer violations not counted in original assessment** — the original review focused on individual skill quality, not cross-cutting concerns (Angular leakage, phase numbering)
2. **Adapter swappability never tested** — the original scores assumed the adapter pattern works; this review actually traced it
3. **Error paths not exercised** — the original review scored happy-path quality; this review scored failure recovery

## Priority Fix List (by impact)

### P1 — Split core/security (fixes C1)
Move Angular checks → `adapters/angular/security-checks` section. Core keeps only universal patterns. Impact: +3 on core/security score.

### P2 — Unify phase numbering (fixes C3)
Single canonical table in core/orchestration. Add Phase 0.5 to complexity matrix. Metrics references orchestration IDs. Impact: fixes 5-agent consensus issue.

### P3 — Move Angular content out of pipeline (fixes C4)
Add `component_scan_globs`, `test_file_pattern`, `security_checks` to tech-stack adapter contract. Planner/code-reviewer/ui-reviewer call adapter instead of hardcoding. Impact: +2 on 4 pipeline skills.

### P4 — Add commit gate for Self-Verify (fixes C6)
Coder step_7: "if figma-verify.md missing or has MISMATCH → BLOCK commit." Also add flex-direction to explicit Self-Verify checklist. Impact: closes known production bug.

### P5 — Add PASS_WITH_ISSUES to verdict_mapping (fixes C8)
One-line fix in core/orchestration. Impact: prevents pipeline stalls.

### P6 — Type the task object schema (fixes C5)
Add `task_schema` to core/orchestration with all fields. Reference in all handoff contracts. Impact: closes 3 blocker-level contract gaps.

### P7 — Refactor community-sync (fixes C2)
Move cherry-pick workflow to ci-cd adapter contract. Move build-fix to tech-stack adapter. Facade becomes thin dispatcher. Impact: +4 on community-sync score.

### P8 — Add Figma MCP fallback to coder (fixes C7)
`on_figma_unavailable` handler: use last-known values / skip / abort part. Impact: closes worst error-recovery gap (3/10 scenario).

### P9 — Add WARN pattern to coder external skills (fixes S3C finding)
css-styling-expert and refactoring-ui need `on_unavailable` blocks matching ui-reviewer pattern. Impact: consistent error handling.

### P10 — Update SKILLS_OVERVIEW.md (fixes C10)
Remove brainstorming from ui-reviewer, move subagent-driven-development to coder. Impact: documentation accuracy.
