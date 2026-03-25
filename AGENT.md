# Agent Skills v2.2 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ (github.com/daniyarseifolla/agent-skills)
**Версия:** v2.2 (активная), v1.0 (бэкап)
**Глобальные скиллы:** ~/.claude/skills/ (23 скилла)
**Глобальные команды:** ~/.claude/commands/ (16 команд)
**Последний коммит:** e5112f0 — plan-reviewer → opus, consensus in worker phases

## Архитектура

```
facades (точки входа, триггеры)
  → pipeline (фазы, project-agnostic)
    → core (невидимые протоколы)
      → adapters (сменные: jira, gitlab, angular, figma)
```

### Скиллы (23)

| Layer | Скиллы |
|-------|--------|
| core (4) | orchestration, security, metrics, consensus-review |
| pipeline (8) | worker, planner, coder, figma-coding-rules, plan-reviewer, code-reviewer, ui-reviewer, code-researcher |
| adapters (4) | jira, gitlab, angular, figma |
| facades (7) | jira-worker, deploy, community-sync, scan-ui-inventory, scan-practices, scan-qa-playbook, figma-audit |

### Команды (15)

Pipeline: `/worker`, `/plan`, `/continue`, `/progress`, `/attach`, `/cleanup`
Review: `/cr`, `/code-review` (alias), `/ui-review`, `/verify-figma`, `/figma`
Scan: `/scan-ui`, `/scan-practices`, `/scan-qa`
Ops: `/deploy`, `/sync`

### Внешние зависимости (скиллы)

visual-qa, css-styling-expert, refactoring-ui, qa-test-planner, ui-ux-pro-max, agent-browser, brainstorming (superpowers)

## Как использовать pipeline

### Полный цикл через Jira
```
/worker ARGO-12345
```

### Задача по макету (Figma → код)
```
# Вариант 1: Jira-задача с Figma-ссылками в описании
/worker ARGO-12345
# Pipeline сам найдёт Figma URLs в описании, извлечёт дизайн, реализует

# Вариант 2: Только Figma, без Jira
# Описать задачу словами + дать Figma ссылку:
"Реализуй компонент карточки по этому макету: https://figma.com/design/XXX/YYY?node-id=123:456"
# Coder загрузит figma-coding-rules, extract → write → self-verify → commit

# Вариант 3: Проверить существующий код против Figma
/verify-figma https://figma.com/design/XXX/YYY?node-id=123:456
```

## Ключевые паттерны

### 1. Consensus Review (3 секции x 3 агента)
- Для review, анализа, статистики — НИКОГДА не доверять одному агенту
- Каждая секция: 3 агента с разных углов → consensus + conflicts + unique
- Intermediate files: агенты пишут в `.tmp/`, orchestrator мержит, cleanup после
- Активация: complexity >= M в pipeline, или `--thorough` в командах

### 2. WARN вместо fallback
- Если внешний скилл не загрузился — сообщить юзеру, НЕ пытаться заменить
- Формат: WARN + 3 опции (Install / Skip / Abort)
- Применяется к: css-styling-expert, refactoring-ui, visual-qa, qa-test-planner, ui-ux-pro-max, agent-browser

### 3. Figma Self-Verify + Commit Gate
- Coder: extract CSS из Figma → write → verify КАЖДОЕ свойство → fix → next
- **Commit gate:** figma-verify.md обязателен до коммита (flex-direction проверяется явно)
- Tolerance: coder ±0px (author), ui-reviewer ±2px (render)
- Icon rule: НИКОГДА не рисовать SVG вручную
- **Hook активирован:** PostToolUse на Write|Edit для .scss/.css/.component.html файлов
- **Figma MCP fallback:** если MCP недоступен → skip/use-cached/abort (не стопорить pipeline)

### 4. Layer Separation
- **core/security** — только universal checks (secrets, eval, SSRF, prototype pollution)
- **Angular security** (XSS, CSRF, route guards) — в adapter-angular Section 7
- **Phase numbering** — единая таблица в orchestration, нормализация в metrics
- **task_schema** — типизирован в orchestration, все handoff contracts ссылаются

## Оценки скиллов (post-consensus review)

9-agent consensus review дал **6.3/10** (вместо предсказанных 8.5-9.0).
После 10 фиксов (P1-P10) — ожидается **7.5-8.0**.

| Score | Скиллы |
|-------|--------|
| 8.5-9 | code-researcher, plan-reviewer, adapter-angular, adapter-figma, adapter-jira |
| 7.5-8 | orchestration, adapter-gitlab, figma-coding-rules, worker |
| 7-7.5 | planner, coder, code-reviewer, metrics, consensus-review |
| 6-6.5 | ui-reviewer, scan-qa-playbook, scan-practices, deploy, jira-worker facade |
| 4-5.5 | community-sync, scan-ui-inventory, core-security (до фикса — после ~7) |

Полный отчёт: `v2.2/CONSENSUS-REVIEW-v2.2.md`

## Что было сделано

### REFACTOR v1 + v2 (74 пункта — все выполнены)
Файлы: v2.2/REFACTOR.md, v2.2/REFACTOR-v2.md

### Session 2026-03-24/25 (большая)
- Sync проверка: 22/22 скилла OK
- Hook figma-verify-reminder.sh: активирован + баг-фикс ($CLAUDE_FILE_PATH → stdin JSON)
- 9-agent consensus review → CONSENSUS-REVIEW-v2.2.md (6.3/10)
- 10 фиксов P1-P10 (layer separation, contracts, safety)
- `/figma` command + figma-audit facade (638 строк, 4 фазы consensus)
- Consensus mode добавлен в Phase 2 (opus), Phase 4, Phase 5
- Plan-reviewer → opus model
- Deep Task Analysis spec утверждён (Phase 0.7: Figma + Swagger + Functional Map)
- 23 скилла + 16 команд, все в sync

## Что НЕ сделано (следующий этап)

### Приоритет 1 — Реализация Phase 0.7 (Deep Task Analysis)
Spec утверждён: `docs/superpowers/specs/2026-03-25-deep-task-analysis-design.md`
Нужно:
1. Расширить worker SKILL.md — добавить Phase 0.7
2. Обновить core/orchestration — phase_sequence, checkpoint, recovery heuristic, handoff
3. Добавить api_discovery в adapter-angular
4. Обновить planner — skip step_2 когда task-analysis.md есть
5. Использовать skill-creator для eval-тестов

### Приоритет 2 — Валидация
1. Тест `/worker ARGO-XXXXX` на реальной задаче end-to-end
2. Тест `/figma` на реальном макете

### Приоритет 3 — Доработки из consensus review
- Русские AC headings в Jira adapter (`Критерии приемки`)
- `grep -P` для lookahead паттернов в core-security
- Atomic checkpoint write (tmp + rename)
- Post-STOP recovery instructions в loop-exceeded messages
- /attach: вынести 146 строк логики в facade/skill

### Известные проблемы
- LAYOUT_RULE: commit gate добавлен (P4), но нужен реальный тест
- feature-dev plugin отключён глобально (--scope user)

## Memory файлы

```
~/.claude/projects/-Users-dannywayne-Desktop-pet-agent-skills/memory/
├── MEMORY.md
├── user_profile.md
├── project_agent_skills_v2.md
├── feedback_figma_icons.md
├── feedback_ci_worktree.md
├── feedback_figma_css_enforcement.md
├── feedback_research_before_code.md
└── feedback_ui_rules.md
```

## Как продолжить

```
# 1. Тест на реальной задаче
/worker ARGO-XXXXX

# 2. Задача по макету
"Реализуй по макету: https://figma.com/design/..."

# 3. Проверить Figma-fidelity текущего кода
/verify-figma https://figma.com/design/...

# 4. Повторный consensus review
"Запусти consensus review v2.2 скиллов: 3 секции x 3 агента"
```
