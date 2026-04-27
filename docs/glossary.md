# Glossary

Термины проекта. Одно предложение на термин — детали в соответствующих `SKILL.md` и [`SKILLS_OVERVIEW.md`](../SKILLS_OVERVIEW.md).

## Архитектура

- **skill** — единица переиспользуемой функциональности с `SKILL.md` (триггеры, инструкции, evals).
- **facade** — пользовательский фасад, реагирующий на естественный триггер (worker, deploy, ship, ...) и оркестрирующий pipeline.
- **adapter** — обёртка над внешним инструментом (gitlab, jira, ...), которую facade использует.
- **core** — общие переиспользуемые скиллы (memory, planner, ...).
- **pipeline** — цепочка скиллов под определённый flow (research → plan → review → code → review → deploy).
- **command** — точка входа slash-команды (`/worker`, `/deploy`, `/ship`).
- **hook** — shell-команда, выполняемая Claude Code в ответ на событие (post-commit, session-start, ...).

## Каталоги скиллов

- **internal skill** — скилл, реализованный в этом репо (`adapters/`, `facades/`, `core/`, `pipeline/`).
- **external skill** — скилл, установленный **извне** в `~/.claude/skills/<name>/`. Сюда они попадают не через этот репо (а, например, через плагины или ручную установку). Описание зачем они нам — в [`external-skills/`](../external-skills/README.md).

## Тестирование и eval

- **trigger eval** — набор тест-кейсов в `<skill>/evals/trigger-eval.json`, проверяющий что Claude корректно триггерит скилл на пользовательских фразах.

## Документация для агентов

- **AD / ADR** (Architecture Decision Record) — запись о принятом архитектурном решении в [`docs/ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md), формат `AD-NNN: Title` с полями Контекст / Решение / Статус.
- **vault** — корень репо открыт как Obsidian-хранилище (`.obsidian/`); это UI для человека, агенты работают с файлами напрямую.
