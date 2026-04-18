# Agent Skills v3 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ — **canonical source of truth**
**Install target:** ~/.claude/skills/ + ~/.claude/commands/ (NOT the source)
**Версия:** v3 (активная), v1 (архив)
**Полный отчёт:** `v3/REPORT.md`
**Consensus reviews:** `v3/CONSENSUS-REVIEW-v2.2.md` (round 1: 6.3), `v3/CONSENSUS-REVIEW-v2.2-round2.md` (round 2: 8.0)

## Архитектура

```
User → Command → Facade → Worker → [Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9]
                                      ↓       ↓       ↓        ↓       ↓
                                    Adapters  Core  Consensus  Subagents  MCP
```

| Layer | Count | Скиллы |
|-------|-------|--------|
| core (4) | orchestration, security, metrics, consensus-review |
| pipeline (9) | worker, impact-analyzer, planner, coder, figma-coding-rules, plan-reviewer, code-reviewer, ui-reviewer, code-researcher |
| adapters (4) | jira, gitlab, angular, figma |
| facades (7) | jira-worker, deploy, community-sync, scan-ui-inventory, scan-practices, scan-qa-playbook, figma-audit |

24 skills + 16 commands + 1 hook

## Основные команды

| Команда | Что делает |
|---------|------------|
| `/worker ARGO-XXX` | Полный цикл: deep analysis → plan → review → code → review → MR → deploy |
| `/figma URL [app-url]` | Consensus node map → visual/property/UX сравнение → fix/build → verify |
| `/sync` | Cherry-pick на community ветки |
| `/deploy test\|prod` | Deploy через GitLab CI |

## Pipeline `/worker` (M+ задачи, 33 агента)

```
Phase 1: analyze  → classify (S/M/L/XL)
Phase 2: setup    → workspace (branch, worktree, CI)
Phase 3: research → deep analysis (3 agents: Figma + API + Functional) + confirmation gate
Phase 4: impact   → impact analysis (consumers, siblings, shared code → impact-report.md)
Phase 5: plan     → planner (opus) + consensus research (3 agents: Codebase + Deps + UX Flow)
Phase 6: plan-review → plan review (3x3 opus = 9 agents)
Phase 7: implement   → coder (sonnet) + subagents per part + commit gate
Phase 8: review      → code review (3x3 sonnet = 9 agents) + UI review (3x3 sonnet = 9 agents) in parallel
Phase 9: ship        → auto-completion (MR → merge → deploy → notify → metrics)
```

S задачи: Phases 3, 6 skip. Phase 8 UI review skip if no design adapter. Single agent on review. ~0 consensus overhead.

## Ключевые решения (P0 фиксы)

1. **Source of truth** — repo canonical, ~/.claude/skills/ is install target
2. **Checkpoint** — `completed` array + `next_phase_map` lookup (not `phase_completed + 1`)
3. **Model routing** — Phase 6: plan-review = opus (canonical table fixed)
4. **Scoring** — 1-10 everywhere (ui-reviewer fixed from 0-100)
5. **Credentials** — `.credentials` file (gitignored), never inline in checkpoint.yaml

## Codex Feedback Roadmap

### P0 — Done (commit 3a4fe55)
- Source of truth, checkpoint model, model/score drift, credentials isolation

### Done (P0)
- Checkpoint: completed array + next_phase_map everywhere (worker, /continue, /progress, metrics, /cleanup)
- Model drift fixed (orchestration Phase 6: plan-review = opus)
- Score drift fixed (ui-reviewer = 1-10)
- Credentials isolation (.credentials gitignored)
- Root SKILLS_OVERVIEW.md cleaned (was v1.0 trash)
- Install docs consolidated to v2.2/README.md
- /code-review → 1-line redirect

### P1 — Next session
- figma-audit → integrate with core (checkpoint, metrics, /continue)
- Normalize facades (community-sync, figma-audit → thin delegation)
- doctor/preflight command
- Onboarding ladder (install → doctor → scan → worker)
- Weaken author-specific assumptions (ARGO, community/* → project config)

### P2 — When needed
- Behavioral evals: /worker, /figma, /attach, /continue, degraded modes
- Docs split: README (entry) + ARCHITECTURE (internals) + OPERATIONS (recovery)
- Cost optimization: 6 of 9 plan-reviewer agents → sonnet (pattern-matching)

## Model Routing

| Model | Skills |
|-------|--------|
| opus | planner, plan-reviewer (3x3 consensus), Phase 3: research agents 1+3, Phase 5: plan research agents 1+3 |
| sonnet | coder, code-reviewer (3x3), ui-reviewer (3x3), Phase 3: research agent 2, Phase 5: plan agent 2, figma-audit |
| haiku | code-researcher |

## Как продолжить

```
# Тест на реальной задаче (приоритет #1)
/worker ARGO-XXXXX

# Figma audit
/figma https://figma.com/design/... http://localhost:4200

# P1 фиксы
"Сделай P1 из Codex roadmap"
```
