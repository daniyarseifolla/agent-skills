# Agent Onboarding

Если ты новый агент в этом репо — прочти это первым. Здесь карта: где что лежит, куда смотреть, куда писать.

## Что это

Репозиторий переиспользуемых development-pipeline скиллов для Claude Code со swappable adapters. Версия в `VERSION` (см. также [`CHANGELOG.md`](../CHANGELOG.md)).

## Карта репо

| Путь | Что |
|------|-----|
| [`CLAUDE.md`](../CLAUDE.md) | Правила проекта (грузится автоматически в каждой сессии) |
| [`SKILLS_OVERVIEW.md`](../SKILLS_OVERVIEW.md) | Каталог внутренних скиллов и архитектура |
| `adapters/`, `facades/`, `core/`, `pipeline/` | Реализация **внутренних** скиллов (каждый со своим `SKILL.md`) |
| `commands/` | Slash-команды (`/worker`, `/deploy`, `/ship`, ...) |
| `hooks/` | Shell-команды для событий Claude Code |
| [`external-skills/`](../external-skills/README.md) | **Каталог установленных извне Claude-скиллов** (`~/.claude/skills/...`) с описанием — что и зачем нам нужно |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Сущности репо и flow между ними |
| [`docs/ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md) | Лог архитектурных решений (AD-NNN) — почему сделано так |
| [`docs/glossary.md`](glossary.md) | Термины проекта (skill, facade, adapter, ...) |
| [`docs/SKILL_AUTHORING.md`](SKILL_AUTHORING.md) | Как писать новый скилл |
| `docs/plans/` | Планы по текущим задачам |
| `evals/` | Eval-сеты триггеров скиллов |
| `research/` | Исследования |

## Куда смотреть

- **Что делает скилл X** → `<area>/<skill>/SKILL.md` (например `facades/worker/SKILL.md`)
- **Архитектура и состав** → [`SKILLS_OVERVIEW.md`](../SKILLS_OVERVIEW.md), [`docs/ARCHITECTURE.md`](ARCHITECTURE.md)
- **Какие внешние скиллы установлены и зачем** → [`external-skills/README.md`](../external-skills/README.md)
- **Что значит термин** → [`docs/glossary.md`](glossary.md)
- **Почему сделано так** → [`docs/ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md)
- **Как писать новый скилл** → [`docs/SKILL_AUTHORING.md`](SKILL_AUTHORING.md)
- **Что делать при триггере** (фразе пользователя) → таблица Quick Reference в [`CLAUDE.md`](../CLAUDE.md)

## Куда писать новое

| Что появилось | Куда |
|---------------|------|
| Новый внутренний скилл | папка в `adapters/` / `facades/` / `core/` / `pipeline/` со `SKILL.md` + строка в `SKILLS_OVERVIEW.md` (см. [`SKILL_AUTHORING.md`](SKILL_AUTHORING.md)) |
| Установлен новый внешний скилл | заметка `external-skills/<name>.md` + ссылка в `external-skills/README.md` (правило: только реально установленные, проверяй `~/.claude/skills/`) |
| Архитектурное решение | новая запись AD-NNN в [`docs/ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md) |
| Новый термин | строка в [`docs/glossary.md`](glossary.md) |
| План задачи | файл в `docs/plans/` |

## Vault

Репо открывается как Obsidian vault (`.obsidian/`). Это UI для человека — граф, wikilinks, базы. Для агентов это не обязательно: читай файлы напрямую через Read/Grep. Wikilinks (`[[Note]]`) и markdown-ссылки (`[Note](path)`) внутри `docs/` и `external-skills/` указывают на одни и те же файлы — оба формата работают.
