---
title: obsidian-bases
tags:
  - external-skills
  - obsidian
type: skill
status: installed
location: ~/.claude/skills/obsidian-bases
---

# obsidian-bases

> [!info] Назначение
> Создание и редактирование `.base` файлов Obsidian — YAML-описание динамических представлений vault'а с фильтрами, формулами и views.

## Что покрывает

- **Filters**: `and` / `or` / `not`, операторы (`==`, `!=`, `>`, `<`, `&&`, `||`), глобальные и view-specific
- **Formulas**: вычисляемые свойства (`if()`, `date()`, `now()`, `today()`, `duration()`)
- **Properties**: note properties, file properties (`file.name`, `file.mtime`, `file.tags`, ...), formula properties
- **Views**: `table`, `cards`, `list`, `map` — с `groupBy`, `limit`, `summaries`, `order`
- **Summaries**: Average, Sum, Min/Max, Median, Stddev, Earliest/Latest, Unique, Filled, ...
- Тонкости: Duration-арифметика (`(now() - file.ctime).days`), null-guard через `if()`, YAML quoting rules

## Зачем нам

Если будем строить **shared memory для агентов** в этом vault'е — `.base` файлы дают индексы по тегам/папкам/свойствам. Например: дашборд установленных скиллов, индекс заметок по типу, трекер проектов.

> [!example] Возможный кейс
> `external-skills/skills.base` — table view со всеми заметками, у которых `type: skill`, с колонками `location`, `status`, `tags`.

## Источник

Файл: `~/.claude/skills/obsidian-bases/SKILL.md`

Дополнительно: `references/FUNCTIONS_REFERENCE.md` — полный справочник функций.

## Связи

- [[README|External Skills index]]
- [[obsidian-markdown]] — синтаксис заметок, по которым строятся базы
- [[obsidian-cli]] — для генерации/обновления баз из CLI
