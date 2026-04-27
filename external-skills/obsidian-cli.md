---
title: obsidian-cli
tags:
  - external-skills
  - obsidian
  - cli
type: skill
status: installed
location: ~/.claude/skills/obsidian-cli
requires: running Obsidian instance
---

# obsidian-cli

> [!info] Назначение
> CLI `obsidian` для взаимодействия с **запущенным** Obsidian-инстансом — чтение/создание/поиск заметок, daily notes, properties, tags, backlinks, плюс dev-команды для разработки плагинов.

> [!warning] Требование
> Obsidian должен быть открыт. Команды действуют на последний сфокусированный vault, либо на указанный через `vault=<name>`.

## Что покрывает

### Контент

- `obsidian read file="..."`, `obsidian create name="..." content="..."`, `obsidian append`
- `obsidian search query="..." limit=N`
- `obsidian daily:read`, `obsidian daily:append`
- `obsidian property:set name=X value=Y file=Z`
- `obsidian tasks daily todo`, `obsidian tags counts`, `obsidian backlinks file=...`

### Dev-цикл (плагины/темы)

1. `obsidian plugin:reload id=my-plugin` — перезагрузить плагин
2. `obsidian dev:errors` — собрать ошибки
3. `obsidian dev:screenshot path=...` / `obsidian dev:dom selector=...` — визуальная проверка
4. `obsidian dev:console level=error` — консоль
5. `obsidian eval code="..."` — JS в контексте app
6. `obsidian dev:css selector=... prop=...` — инспекция CSS

## Зачем нам

- **Автоматизация vault'а**: агенты могут писать заметки прямо в работающий Obsidian (а не только через файлы), вызывать поиск, обновлять properties.
- **Память между агентами**: если этот репо открыт как vault, любой агент может через CLI добавить заметку и она сразу появится у пользователя.
- **Разработка плагинов**: цикл reload → check errors → screenshot.

## Источник

Файл: `~/.claude/skills/obsidian-cli/SKILL.md`

Полный список команд: `obsidian help` (CLI всегда актуальнее, чем доки).

Официальные доки: https://help.obsidian.md/cli

## Связи

- [[README|External Skills index]]
- [[obsidian-markdown]] — формат контента, который пишет CLI
- [[obsidian-bases]] — `.base` файлы можно создавать через `obsidian create`
