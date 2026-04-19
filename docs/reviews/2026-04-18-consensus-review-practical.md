# 3×3 Consensus Review #2 — Practical Skill Problems

**Date:** 2026-04-18
**Scope:** Prompt quality, pipeline efficiency, output quality
**Overall Score:** 5.3/10

## Scores

| Section | A1 | A2 | A3 | Avg |
|---------|----|----|-----|-----|
| Prompt Engineering Quality | 5 | 5 | 5 | 5.0 |
| Pipeline Efficiency | 6 | 5 | 6 | 5.7 |
| Output Quality | 6 | 6 | 4 | 5.3 |

## Consensus Findings

1. **Double research** (3 agents) — Phase 3 + planner step_3 = 6 agents where 3 suffice
2. **Ship facade diverging fork** (2 agents) — duplicates Phase 9 logic, already drifting
3. **No per-part checkpoint in Phase 7** (2 agents) — context exhaustion crashes lose progress
4. **Enforcement markers far from action** (2 agents) — 40 MANDATORY/CRITICAL, most misplaced
5. **Handoff contracts incomplete** (2 agents) — missing architect_roles_adapter, tech_stack_adapter optional
6. **Plans lack concrete signatures** (2 agents) — no methods/interfaces, coder guesses
7. **Review false positives** (2 agents) — security auto-escalation, 3-MINOR conflict
8. **Subagent failure no fallback** (2 agents) — no timeout, no partial consensus

## Unique High-Value Findings

9. Architect LLM convergence — 3 opus = ~1.3x insight (score 4/10)
10. Phase numbering collision (document sections vs phase numbers)
11. Checkpoint writes numbers not names (inconsistent with core/orchestration)
12. Worktree cleanup can kill active subagent
13. figma-audit: 250 lines inline prompts bloat orchestrator context
14. arch-review Phase B duplicates planner/coder work

## Roadmap

### Tier 1: Fix Real Breakage
1. Per-part checkpoint in Phase 7
2. Fix handoff contracts (missing fields)
3. Ship facade → shared protocol

### Tier 2: Save Resources
4. Eliminate double research
5. Architect: 2 agents + convergence gate
6. Consensus fallback on subagent failure

### Tier 3: Improve Output Quality
7. Concrete signatures in plans
8. Security escalation fix
9. Enforcement markers → point of action

### Tier 4: Cleanup & Optimization
10. Trim figma-audit (−40%), worker (−35%), ui-reviewer (−30%)
11. Deduplicate evaluate gate
12. Remove deprecated blocks, fix numbering collision
