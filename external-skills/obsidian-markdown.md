---
title: obsidian-markdown
tags:
  - external-skills
  - obsidian
type: skill
status: installed
location: ~/.claude/skills/obsidian-markdown
---

# obsidian-markdown

> [!info] Назначение
> Создание и редактирование заметок в формате Obsidian Flavored Markdown — расширения CommonMark/GFM, специфичные для Obsidian.

## Что покрывает

- **Wikilinks**: `[[Note]]`, `[[Note#Heading]]`, `[[Note#^block-id]]`, `[[Note|Display]]`
- **Embeds**: `![[file]]`, `![[image.png|300]]`, `![[doc.pdf#page=3]]`
- **Callouts**: `> [!note]`, `> [!warning]`, foldable варианты
- **Properties** (frontmatter): tags, aliases, cssclasses, custom
- **Тэги**: inline `#tag`, вложенные `#nested/tag`
- **Math** (LaTeX), **Mermaid**, footnotes, comments `%%hidden%%`, highlights `==text==`

## Зачем нам

Все заметки в этом vault'е (включая [[README|library MOC]] и заметки про скиллы) пишутся в этом синтаксисе. Скилл нужен как справочник, чтобы корректно использовать wikilinks/callouts/properties без галлюцинаций.

## Источник

Файл: `~/.claude/skills/obsidian-markdown/SKILL.md`

Дополнительно: `references/PROPERTIES.md`, `references/EMBEDS.md`, `references/CALLOUTS.md`.

## Связи

- [[README|External Skills index]]
- [[obsidian-bases]] — для динамических представлений vault'а
- [[obsidian-cli]] — для автоматизации работы с заметками
