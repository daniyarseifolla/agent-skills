# 3×3 Consensus Review #1 — Architecture & Portability

**Date:** 2026-04-18
**Scope:** Portability to OpenClaw/Telegram/Web, adapter pattern, plugin system
**Overall Score:** 4.2/10

## Scores

| Section | A1 | A2 | A3 | Avg |
|---------|----|----|-----|-----|
| Architecture & Portability | 6 | 4 | 3 | 4.3 |
| Pipeline Design & Robustness | 6 | 5 | 5 | 5.3 |
| DX & Extensibility | 3 | 3 | 3 | 3.0 |

## Consensus Findings

1. **Runtime coupling to Claude Code** (3 agents) — Agent tool, MCP, Bash, superpowers hardwired
2. **No formal adapter contracts** (4 agents) — prose one-liners, not typed schemas
3. **No plugin/composition system** (3 agents) — 3 hardcoded routes, no registry
4. **No skill authoring docs** (2 agents) — zero documentation for creating skills
5. **Double research** (2 agents) — Phase 3 + planner step_3 overlap
6. **Phases 1-2 inline in worker** (2 agents) — not extractable
7. **Plan-review 9× opus for M** (2 agents) — disproportionate cost
8. **No cost controls** (2 agents) — no budgets, no fallbacks
9. **Handoff contracts unenforceable** (3 agents) — no JSON Schema, no CI
10. **No testing infrastructure** (2 agents) — 1/25 skills has evals

## Recommendations (prioritized)

### Tier 1: Foundation
1. RuntimeAdapter interface
2. Formal adapter contract schemas
3. SKILL_AUTHORING.md

### Tier 2: Cost & Robustness
4. Tier consensus by complexity (M: 3×1, XL: 3×3)
5. Eliminate double research
6. Pre-compaction checkpoint protocol

### Tier 3: Extensibility
7. User-configurable pipelines in project.yaml
8. Skill manifest + registry
9. Lifecycle hooks
