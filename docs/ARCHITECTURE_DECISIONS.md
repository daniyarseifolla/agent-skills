# Architecture Decisions

Лог архитектурных решений. Обновляется при каждом значимом выборе.

## Принятые решения

### AD-001: Фазы 1-9 вместо дробных (v4.0)
**Дата:** 2026-04-18
**Контекст:** Pipeline использовал дробные фазы (0, 0.5, 0.7, 0.8, 1-6). Добавление новых фаз создавало костыли.
**Решение:** Перенумеровать в чистые 1-9 с именованными checkpoints.
**Статус:** Реализовано.

### AD-002: Architect как step внутри planner (не отдельная фаза)
**Дата:** 2026-04-18
**Контекст:** Architect мог быть Phase 0.9 (отдельная фаза) или step внутри planner.
**Решение:** Step внутри planner -- нет конфликта handoff, brainstorming кормит architect напрямую.
**Статус:** Реализовано.

### AD-003: 3 architect агента (не 2)
**Дата:** 2026-04-18
**Контекст:** Review предложил сократить до 2 (minimal + challenger). Balanced может быть redundant.
**Решение:** Оставить 3 -- проверить на практике, LLM convergence гипотеза не подтверждена.
**Статус:** Принято, ждёт проверки.

### AD-004: Double research (Phase 3 + planner step_3)
**Дата:** 2026-04-18
**Контекст:** Phase 3 и planner step_3 оба запускают 3 research агента с частичным пересечением.
**Решение:** Оставить -- Phase 3 = внешние данные (Figma, API), planner = внутренний код. Пересечение в 1 из 3 агентов.
**Статус:** Принято, ждёт проверки.

### AD-005: Command vs Facade разделение
**Дата:** 2026-04-19
**Контекст:** Commands и facades делают похожие вещи -- принимают ввод и запускают pipeline.
**Решение:** Command = ручной вызов (/worker), Facade = NL триггер ("сделай задачу"). Оба вызывают один pipeline skill.
**Статус:** Принято.

### AD-006: pipeline/worker naming (не runner/orchestrator)
**Дата:** 2026-04-20
**Контекст:** pipeline/worker путается с facades/worker. Рассматривались: runner, orchestrator, executor, dispatcher, engine.
**Решение:** Оставить pipeline/worker -- rename 20+ файлов ради naming не оправдан. Рассмотреть при следующем major refactor.
**Статус:** Отложено.

### AD-007: jira-worker -> universal worker facade
**Дата:** 2026-04-20
**Контекст:** jira-worker hardcoded task-source=jira. Worker autodetect уже умеет определять source.
**Решение:** Переименовать в facades/worker, сделать universal с autodetect.
**Статус:** Реализовано.

### AD-008: Repo as Obsidian vault + onboarding canal for agents
**Дата:** 2026-04-26
**Контекст:** Между сессиями агенты теряли контекст: CLAUDE.md грузится автоматически, но детальная структура (термины, внешние зависимости) была разбросана. Нужна общая память, доступная любому агенту.
**Решение:**
- Корень репо открыт как Obsidian vault (`.obsidian/` закоммичен).
- Канал онбординга — [`docs/AGENTS.md`](AGENTS.md), куда CLAUDE.md направляет агентов.
- Канал терминов — [`docs/glossary.md`](glossary.md).
- Канал внешних скиллов (`~/.claude/skills/...`) — [`external-skills/`](../external-skills/README.md) с заметкой на каждый установленный скилл.
- ADR продолжаем писать здесь, в `ARCHITECTURE_DECISIONS.md`, в формате AD-NNN.
**Альтернативы:** только CLAUDE.md (не масштабируется), `~/.claude/projects/.../memory/` (приватно, не в гите), vault в подпапке (теряет связи с CLAUDE.md и SKILLS_OVERVIEW.md).
**Статус:** Реализовано.
