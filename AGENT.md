# Agent Skills v2.2 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ (github.com/daniyarseifolla/agent-skills)
**Версия:** v2.2 (активная), v1.0 (бэкап)
**Глобальные скиллы:** ~/.claude/skills/ (23 скилла, 5863 строки)
**Глобальные команды:** ~/.claude/commands/ (16 команд, 432 строки)
**Последний коммит:** 84fcad5
**Полный отчёт:** `v2.2/REPORT.md`

## Архитектура

```
User → Command → Facade → Worker → [Phase 0 → 0.5 → 0.7 → 1 → 2 → 3 → 4+5 → 6]
                                      ↓         ↓         ↓        ↓       ↓
                                    Adapters   Core    Consensus  Subagents  MCP
```

| Layer | Count | Скиллы |
|-------|-------|--------|
| core (4) | 989 lines | orchestration, security, metrics, consensus-review |
| pipeline (8) | 3089 lines | worker, planner, coder, figma-coding-rules, plan-reviewer, code-reviewer, ui-reviewer, code-researcher |
| adapters (4) | 1068 lines | jira, gitlab, angular, figma |
| facades (7) | 717 lines | jira-worker, deploy, community-sync, scan-ui-inventory, scan-practices, scan-qa-playbook, figma-audit |

## Основные команды

| Команда | Что делает |
|---------|------------|
| `/worker ARGO-XXX` | Полный цикл: deep analysis → plan → review → code → review → MR → deploy |
| `/figma URL [app-url]` | Consensus node map → visual/property/UX сравнение → fix/build → verify |
| `/sync` | Cherry-pick на community ветки |
| `/deploy test\|prod` | Deploy через GitLab CI |

Дополнительные: `/plan`, `/cr`, `/ui-review`, `/verify-figma`, `/attach`, `/continue`, `/progress`, `/cleanup`, `/scan-ui`, `/scan-qa`, `/scan-practices`

## Pipeline `/worker` (M+ задачи)

```
Phase 0   → classify (S/M/L/XL)
Phase 0.5 → workspace (branch, worktree, CI)
Phase 0.7 → deep analysis: 3 agents (Figma explorer opus + API discovery sonnet + Functional mapper opus)
            → task-analysis.md + confirmation gate
Phase 1   → planner (opus, reads task-analysis.md)
Phase 2   → plan review (3x opus consensus: AC + Architecture + Design)
Phase 3   → coder (sonnet, commit gate: figma-verify.md required)
Phase 4   → code review (3x sonnet consensus: Bugs + Compliance + Security)
Phase 5   → UI review (3x sonnet consensus: Functional + Visual + States/A11y)
Phase 6   → MR + deploy + metrics
```

S задачи: Phases 0.7, 2, 5 skip. Single agent на 4.

## Ключевые паттерны

### Consensus Review
- 3 агента с разных углов → consensus + conflicts
- Активация: M+ в pipeline
- Где: Phase 0.7, Phase 2, Phase 4, Phase 5, `/figma` (все 4 фазы)

### Deep Task Analysis (Phase 0.7)
- Figma Explorer: все экраны, states, flows, screenshots
- API Discovery: Swagger → endpoints → OPTIONS test → working/broken/missing
- Functional Mapper: screens × endpoints → user flows + gaps
- Confirmation gate: показать юзеру, предложить создать Jira на бэк
- api_discovery в adapter-angular (proxy.conf → environment.ts → swagger)

### Figma Self-Verify + Commit Gate
- Extract CSS → write → verify КАЖДОЕ свойство → fix → commit
- Commit blocked if figma-verify.md has MISMATCH
- Hook: PostToolUse на .scss/.css/.component.html
- Figma MCP fallback: skip/use-cached/abort

### WARN вместо fallback
- Если внешний скилл не загрузился → WARN + Install/Skip/Abort
- Applies to: css-styling-expert, refactoring-ui, visual-qa, qa-test-planner, ui-ux-pro-max, agent-browser

## Model Routing

| Model | Skills | Purpose |
|-------|--------|---------|
| opus | planner, plan-reviewer (consensus) | Deep research, analytical review |
| sonnet | coder, code-reviewer, ui-reviewer, figma-audit | Implementation, pattern matching |
| haiku | code-researcher | Cheap read-only search |

## Что НЕ сделано

### Приоритет 1 — Тестирование
1. `/worker ARGO-XXXXX` на реальной задаче end-to-end
2. `/figma` на реальном макете
3. Skill-creator eval-тесты trigger accuracy

### Приоритет 2 — Мелкие фиксы
- Русские AC headings в Jira adapter (`Критерии приемки`)
- `grep -P` для lookahead паттернов в core-security
- Atomic checkpoint write (tmp → rename)
- `/attach` вынести 162 строки в facade/skill
- `/code-review` → 1-line redirect на `/cr`

## Как продолжить

```
# Тест на реальной задаче
/worker ARGO-XXXXX

# Figma audit
/figma https://figma.com/design/... http://localhost:4200

# Проверить верстку против Figma
/verify-figma https://figma.com/design/...
```
