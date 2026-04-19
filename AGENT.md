# Agent Skills v4.0 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ — **canonical source of truth**
**Install target:** ~/.claude/skills/ + ~/.claude/commands/ (NOT the source)
**Версия:** 4.0 (see VERSION file)
**Обзор:** [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md)
**Reviews:** [docs/reviews/](docs/reviews/)

## Архитектура

```
User → Command → Facade → Worker → [Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9]
                                      ↓       ↓       ↓        ↓       ↓
                                    Adapters  Core  Consensus  Subagents  MCP
```

| Layer | Count | Скиллы |
|-------|-------|--------|
| core (5) | orchestration, security, metrics, consensus-review, ship-protocol |
| pipeline (10) | worker, planner, architect, coder, figma-coding-rules, plan-reviewer, code-reviewer, ui-reviewer, impact-analyzer, code-researcher |
| adapters (6) | jira, gitlab, angular, figma, slack, architect-roles |
| facades (10) | jira-worker, architect, arch-review, deploy, ship, community-sync, figma-audit, scan-ui-inventory, scan-practices, scan-qa-playbook |

31 skills + 21 commands + 1 hook

## Основные команды

| Команда | Что делает |
|---------|------------|
| `/worker ARGO-XXX` | Полный цикл: analysis → plan → architect → review → code → review → MR → deploy |
| `/arch` | Архитектурная консультация: 3 подхода (conservative/balanced/challenger) |
| `/arch-review` | Ретроспективный архитектурный анализ: 3 review → 3 alternatives |
| `/figma URL [app-url]` | Consensus node map → visual/property/UX сравнение → fix/build → verify |
| `/sync` | Cherry-pick на community ветки |
| `/deploy test\|prod` | Deploy через GitLab CI |
| `/ship` | Commit + push + deploy |

## Pipeline `/worker` (M+ задачи)

```
Phase 1: analyze     → classify (S/M/L/XL)
Phase 2: setup       → workspace (branch, worktree, CI)
Phase 3: research    → deep analysis (3 agents: Figma + API + Functional) + confirmation gate
Phase 4: impact      → impact analysis (consumers, siblings, shared code → impact-report.md)
Phase 5: plan        → architect (3 agents + arbiter) + planner (opus) + consensus research
Phase 6: plan-review → plan review (3×3 opus = 9 agents)
Phase 7: implement   → coder (sonnet) + per-part checkpoint + commit gate
Phase 8: review      → code review (3×3 sonnet) + UI review (3×3 sonnet) in parallel
Phase 9: ship        → ship-protocol (MR → merge → deploy → Jira → Slack → metrics)
```

S задачи: Phases 3, 6 skip. Phase 8 UI review skip if no design adapter. Single agent on review.

## Architect (Phase 5, M+)

3 агента с разными линзами из role adapter (Angular: Component/State/Integration):
- Agent 1: **Conservative** — строго в рамках существующих паттернов
- Agent 2: **Balanced** — точечные улучшения с обоснованием стоимости
- Agent 3: **Challenger** — альтернативный подход с migration plan

Арбитр (4-й opus agent) комбинирует лучшие элементы → architecture.md → planner конкретизирует в план.

Standalone: `/arch` — показывает все 3 подхода пользователю без арбитра.

## Ключевые решения

1. **Source of truth** — repo canonical, ~/.claude/skills/ is install target
2. **Checkpoint** — named phases (`completed: [analyze, setup, plan]`), per-part checkpoint в Phase 7
3. **Model routing** — opus: planner + architect + plan-review; sonnet: coder + reviews; haiku: code-researcher
4. **Ship protocol** — shared между worker Phase 9 и ship facade (single source of truth)
5. **Consensus fallback** — timeout 5 min, 1/3 fail → use 2, 2/3 fail → single agent, 3/3 → HALT
6. **Credentials** — `.credentials` file (gitignored), never inline in checkpoint.yaml

## Trigger Evals

200 queries across 10 facades — 100% accuracy verified.
See: `docs/reviews/2026-04-19-trigger-verification.md`

## Model Routing

| Model | Skills |
|-------|--------|
| opus | planner, architect (3+arbiter), plan-reviewer (3×3 consensus), Phase 3: research agents 1+3 |
| sonnet | coder, code-reviewer (3×3), ui-reviewer (3×3), Phase 3: research agent 2, figma-audit |
| haiku | code-researcher |

## Как продолжить

```
# Тест на реальной задаче
/worker ARGO-XXXXX

# Архитектурная консультация
/arch "описание задачи"

# Архитектурный ревью существующего кода
/arch-review src/path/to/module

# Figma audit
/figma https://figma.com/design/... http://localhost:4200
```
