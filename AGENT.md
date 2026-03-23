# Agent Skills v2.2 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ (github.com/daniyarseifolla/agent-skills)
**Версия:** v2.2 (активная), v1.0 (бэкап)
**Глобальные скиллы:** ~/.claude/skills/ (22 скилла)
**Глобальные команды:** ~/.claude/commands/ (15 команд)
**Последний коммит:** 877fbcb — REFACTOR-v2 complete

## Архитектура

```
facades (точки входа, триггеры)
  → pipeline (фазы, project-agnostic)
    → core (невидимые протоколы)
      → adapters (сменные: jira, gitlab, angular, figma)
```

### Скиллы (22)

| Layer | Скиллы |
|-------|--------|
| core (4) | orchestration, security, metrics, consensus-review |
| pipeline (8) | worker, planner, coder, figma-coding-rules, plan-reviewer, code-reviewer, ui-reviewer, code-researcher |
| adapters (4) | jira, gitlab, angular, figma |
| facades (6) | jira-worker, deploy, community-sync, scan-ui-inventory, scan-practices, scan-qa-playbook |

### Команды (15)

Pipeline: `/worker`, `/plan`, `/continue`, `/progress`, `/attach`, `/cleanup`
Review: `/cr`, `/code-review` (alias), `/ui-review`, `/verify-figma`
Scan: `/scan-ui`, `/scan-practices`, `/scan-qa`
Ops: `/deploy`, `/sync`

### Внешние зависимости (скиллы)

visual-qa, css-styling-expert, refactoring-ui, qa-test-planner, ui-ux-pro-max, agent-browser, brainstorming (superpowers)

## Ключевые паттерны

### 1. Consensus Review (3 секции × 3 агента)
- Для review, анализа, статистики — НИКОГДА не доверять одному агенту
- Каждая секция: 3 агента с разных углов → consensus + conflicts + unique
- Intermediate files: агенты пишут в `.tmp/`, orchestrator мержит, cleanup после
- Активация: complexity >= M в pipeline, или `--thorough` в командах

### 2. WARN вместо fallback
- Если внешний скилл не загрузился — сообщить юзеру, НЕ пытаться заменить
- Формат: WARN + 3 опции (Install / Skip / Abort)

### 3. Figma Self-Verify
- Coder: extract CSS из Figma → write → verify КАЖДОЕ свойство → fix → next
- Tolerance: coder ±0px (author), ui-reviewer ±2px (render)
- Icon rule: НИКОГДА не рисовать SVG вручную

## Оценки скиллов (post-refactor v2)

| Score | Скиллы |
|-------|--------|
| 9/10 | core-orchestration, code-researcher |
| 8-8.5 | adapter-gitlab, adapter-figma, plan-reviewer, code-reviewer, planner, core-security, adapter-jira, adapter-angular, worker, figma-coding-rules, consensus-review |
| 7-7.5 → ожидается 9 | pipeline-coder, ui-reviewer, core-metrics |

## Что было сделано (REFACTOR v1 + v2)

### REFACTOR v1 (33 пункта → 28 выполнено, 4 dropped)
- `/review` → `/cr` (конфликт с built-in Claude Code)
- Split coder 549→270 строк + figma-coding-rules 312 строк
- Verdict vocabulary mapping в orchestration
- Tolerance documented (author vs render)
- Commit per part в Phase 3
- Phase 4+5 параллельно
- Iron Laws, task classification, verdict parsing
- CI disable/restore, worktree safety
- Файл: v2.2/REFACTOR.md (все [x])

### REFACTOR v2 (41 пункт → все выполнены)
- 4 новых handoff контракта (worker→planner, worker→ui-reviewer, evaluate_return, ui_reviewer→completion)
- credentials + app_url в checkpoint и Phase 0.5
- evaluate_return counter (max 2) + REJECTED → halt
- WARN pattern для всех external skills
- Detached HEAD fallback
- Figma MCP preflight check
- /attach: checkpoint как SET + blocking verdicts
- Coder: inline все "Per X see Y", failure triage decision trees
- figma-coding-rules: renumbered 1-5, severity tiers
- UI-reviewer: agent budgets 40 calls/8min, structured verdict 0-100, templates extracted
- Core-metrics: validation, phase ID mapping 0-7, duration HOW, error handling, consumers
- Severity unified: BLOCKER/MAJOR/MINOR/NIT everywhere
- Intermediate files protocol в consensus-review
- Файл: v2.2/REFACTOR-v2.md (все [x])

## Что НЕ сделано (следующий этап)

### Нужно проверить (финальный review)
1. Запустить 9-agent consensus review ПОСЛЕ всех фиксов — сравнить новые оценки с прогнозом 8.5-9.0
2. Проверить sync: v2.2/ файлы ↔ ~/.claude/skills/ (могут рассинхронизироваться)
3. Тест на реальной задаче: `/worker ARGO-XXXXX` от начала до конца

### Нужно реализовать
1. Консолидация команд 15 → 9 (предложение UX агента: `/cr [code|ui|figma|all]`, `/scan [ui|qa|all]`, merge `/progress` в `/continue`)
2. Cross-agent portability (#34-36): адаптеры для Gemini/Codex
3. `--thorough` флаг для `/cr` и `/ui-review` (активирует consensus review)

### Известные проблемы из боевого опыта
- Агент игнорирует LAYOUT_RULE — ставит column вместо row
- Агент пропускает Self-Verify — пишет approximate CSS
- Hook `figma-verify-reminder.sh` существует но не активирован (нужно добавить в project settings.json)
- feature-dev plugin отключён глобально (--scope user)

## Memory файлы

```
~/.claude/projects/-Users-dannywayne/memory/
├── MEMORY.md                         ← индекс
├── user_profile.md                   ← fullstack dev, Angular/Go/React
├── project_agent_skills_v2.md        ← архитектура v2.2
├── feedback_figma_icons.md           ← SVG иконки: never hand-draw
├── feedback_ci_worktree.md           ← CI disable, worktree safety
├── feedback_figma_css_enforcement.md ← agents guess CSS, need verify
├── feedback_research_before_code.md  ← study patterns BEFORE coding
└── feedback_ui_rules.md              ← portal, states, transitions, focus
```

## Как продолжить

```
# 1. Проверить sync
cd ~/Desktop/pet/agent-skills
# Запустить команду из v2.2/SKILLS_OVERVIEW.md для проверки

# 2. Финальный review (9 агентов consensus)
# Скопировать промпт из предыдущей сессии или:
"Запусти consensus review v2.2 скиллов: 3 секции × 3 агента"

# 3. Тест на задаче
/worker ARGO-XXXXX

# 4. Консолидация команд
# Обсудить: /cr [code|ui|figma|all] vs отдельные команды
```
