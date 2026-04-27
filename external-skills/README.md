---
title: External Skills
tags:
  - moc
  - external-skills
type: index
---

# External Skills

Карта установленных извне Claude-скиллов. Каждая заметка фиксирует **что установлено** и **зачем оно нам**, чтобы любой агент в будущей сессии мог быстро понять контекст.

> [!info] Где живут скиллы
> Файлы скиллов лежат в `~/.claude/skills/` и подгружаются Claude Code автоматически. Этот каталог — только описание и навигация, не сами скиллы.

> [!warning] Правило
> Сюда попадают **только реально установленные** скиллы. Не выдумываем — проверяем `~/.claude/skills/` перед добавлением заметки.

## Установленные

- [[obsidian-markdown]] — синтаксис Obsidian Flavored Markdown (wikilinks, embeds, callouts)
- [[obsidian-bases]] — `.base` файлы: фильтры, формулы, views
- [[obsidian-cli]] — CLI для запущенного Obsidian + dev-цикл плагинов

## Как добавить новый скилл

1. Установить скилл (он появится в `~/.claude/skills/<name>/`)
2. Создать заметку `external-skills/<name>.md` со структурой как у соседей: frontmatter (`type: skill`, `location`), разделы **Назначение**, **Что покрывает**, **Зачем нам**, **Источник**, **Связи**
3. Добавить wikilink в раздел [[#Установленные]] выше
4. Закоммитить — vault лежит в репо, конфиг `.obsidian/` тоже

## Связи

- [[../README|Repo README]]
- [[../SKILLS_OVERVIEW|Skills Overview]] — внутренние скиллы этого репо
- [[../CLAUDE|CLAUDE.md]]
