# Руководство по созданию скиллов

Как создать новый скилл с нуля за 30 минут.

Перед началом прочитайте [ARCHITECTURE.md](ARCHITECTURE.md) для понимания связей между сущностями.

---

## 1. Четыре типа скиллов

| Тип | Папка | Назначение | Пример |
|-----|-------|-----------|--------|
| Command | `commands/` | Slash-команда, роутер | `/arch`, `/deploy` |
| Facade | `facades/` | NL-триггеры, парсинг ввода, user-facing | worker, architect |
| Pipeline | `pipeline/` | Внутренняя фаза pipeline | planner, coder |
| Adapter | `adapters/` | Сменная интеграция | jira, angular |
| Core | `core/` | Протоколы и паттерны | orchestration, security |

**Как выбрать тип:**

- Пользователь будет вызывать через `/команду`? --> Command + Facade
- Пользователь будет вызывать естественным языком? --> Facade
- Это внутренний этап pipeline? --> Pipeline
- Это внешний сервис, который можно заменить? --> Adapter
- Это набор правил для других скиллов? --> Core

---

## 2. Обязательные поля frontmatter

Каждый `SKILL.md` начинается с YAML frontmatter:

```yaml
---
name: kebab-case-name          # ОБЯЗАТЕЛЬНО. Только буквы, цифры, дефисы
description: "Use when..."     # ОБЯЗАТЕЛЬНО. Начинать с "Use when" — для trigger matching
human_description: "..."       # ОБЯЗАТЕЛЬНО. Что делает — для людей, на русском
model: opus|sonnet|haiku       # Только для pipeline skills. Какую модель использовать
disable-model-invocation: true # Только для core/adapters. Запрещает прямой вызов
---
```

### Правила для каждого поля

**name** — уникальный идентификатор скилла. Только строчные латинские буквы, цифры, дефисы. Без пробелов, подчёркиваний, заглавных букв.

**description** — строка для trigger matching. Всегда начинается с `"Use when"`. Чем точнее описание, тем лучше Claude выбирает нужный скилл. Включайте конкретные фразы-триггеры.

**human_description** — краткое описание на русском для людей. Отображается в каталоге и документации.

**model** — только для pipeline skills. Определяет, какая модель выполняет фазу: `opus` для сложного анализа, `sonnet` для реализации и ревью, `haiku` для дешёвых read-only задач.

**disable-model-invocation** — только для core и adapters. Запрещает Claude вызывать этот скилл напрямую. Скилл загружается только другими скиллами через `Load Skill:`.

---

## 3. Naming conventions

| Тип | Формат name | Пример |
|-----|------------|--------|
| Command | kebab-case (по имени команды) | `arch`, `deploy`, `ship` |
| Facade | kebab-case | `worker`, `architect`, `figma-audit` |
| Pipeline | `pipeline-` + kebab-case | `pipeline-planner`, `pipeline-coder` |
| Adapter | `adapter-` + kebab-case | `adapter-jira`, `adapter-gitlab` |
| Core | `core-` + kebab-case | `core-orchestration`, `core-security` |

**Файловая структура:**

```
commands/my-command.md              # Command — один .md файл
facades/my-facade/SKILL.md         # Facade — папка + SKILL.md
pipeline/my-phase/SKILL.md         # Pipeline — папка + SKILL.md
adapters/my-adapter/SKILL.md       # Adapter — папка + SKILL.md
core/my-protocol/SKILL.md          # Core — папка + SKILL.md
```

---

## 4. Шаблоны

### Command (минимальный)

Файл: `commands/my-command.md`

```markdown
---
name: my-command
description: "Use when user wants to do X. Usage: /my-command [args]"
human_description: "Что делает эта команда."
---

# My Command

Arguments: $ARGUMENTS

1. Load Skill: my-facade
2. Pass arguments
```

Command — это тонкий роутер. Вся логика в facade.

### Facade

Файл: `facades/my-facade/SKILL.md`

```markdown
---
name: my-facade
description: "Use when user wants to... Triggers: 'NL phrase 1', 'NL phrase 2'."
human_description: "Описание для людей."
---

# My Facade — Facade

## Activation
Triggers: ...

## Flags
| Flag | Effect | Default |
|------|--------|---------|
| --flag | Описание | false |

## Delegation
1. Read .claude/project.yaml for adapter config
2. Load adapters as needed
3. Load Skill: pipeline-skill
4. Pass parsed input
```

Facade — user-facing точка входа. Парсит ввод, определяет контекст, делегирует в pipeline.

### Pipeline

Файл: `pipeline/my-phase/SKILL.md`

```markdown
---
name: pipeline-my-phase
description: "Use when [phase context]. Called by worker Phase N."
human_description: "Описание для людей."
model: sonnet
---

# Pipeline My Phase

Phase N: name.

## 1. Input

From worker handoff.

```yaml
input:
  field: type
  another_field: type
```

## 2. Workflow

1. Шаг один
2. Шаг два
3. Шаг три

## 3. Output

```yaml
output:
  result_field: type
```

## 4. Handoff

Pass output to next phase via worker checkpoint.
```

Pipeline skill — одна фаза. Получает input от worker, отдаёт output следующей фазе.

### Adapter

Файл: `adapters/my-adapter/SKILL.md`

```markdown
---
name: adapter-my-adapter
description: "Use when loading [adapter context]."
human_description: "Описание для людей."
disable-model-invocation: true
---

# Adapter: My Adapter (adapter-type)

Implements the `adapter-type` contract. Loaded when `project.yaml` has `type: my-adapter`.

## Contract

```yaml
type: adapter-type
provides:
  - method_one
  - method_two
```

## 1. method_one(args)

```yaml
steps:
  - call: external_tool
    params:
      key: "{args.key}"
  - extract:
      field: "path.to.value"
```

## 2. method_two(args)

...
```

Adapter — набор методов для конкретной интеграции. Загружается worker-ом из project.yaml. Не вызывается напрямую.

### Core

Файл: `core/my-protocol/SKILL.md`

```markdown
---
name: core-my-protocol
description: "Use when loading [protocol context]."
human_description: "Описание для людей."
disable-model-invocation: true
---

# Core: My Protocol

Internal protocol definitions. Not a user-facing skill.

## 1. Rules

...

## 2. Schema

```yaml
schema:
  field: type
```
```

Core — правила и протоколы. Загружаются автоматически или по ссылке из других скиллов.

---

## 5. Trigger evals

Каждый facade **обязан** иметь файл `evals/trigger-eval.json`:

```
facades/my-facade/evals/trigger-eval.json
```

Формат:

```json
[
  {"query": "реалистичный запрос пользователя", "should_trigger": true},
  {"query": "похожий но НЕ для этого скилла", "should_trigger": false}
]
```

### Правила

- Минимум 20 queries: 10 `should_trigger: true` + 10 `should_trigger: false`
- Near-misses ценнее чем очевидные. `false` запросы должны быть *похожи* на ваш скилл, но принадлежать другому
- Включайте запросы на русском и английском
- Включайте slash-команду и NL-варианты

### Пример (из facades/ship)

```json
[
  {"query": "/ship", "should_trigger": true},
  {"query": "закоммить и задеплой на тест", "should_trigger": true},
  {"query": "ship it to prod with MR", "should_trigger": true},

  {"query": "задеплой текущую ветку на тест", "should_trigger": false},
  {"query": "git commit -m 'fix validation'", "should_trigger": false},
  {"query": "ARGO-10700 возьми в работу", "should_trigger": false}
]
```

`false`-кейсы здесь -- запросы, которые *близки* по смыслу (коммит, деплой, пуш), но принадлежат другим скиллам (deploy, worker).

---

## 6. Checklist для нового скилла

Используйте перед каждым коммитом:

- [ ] `SKILL.md` создан в правильной папке с правильным именем файла
- [ ] `name:` -- только строчные буквы, цифры, дефисы
- [ ] `description:` -- начинается с `"Use when..."`
- [ ] `human_description:` -- на русском, для людей
- [ ] `model:` указан (только pipeline skills)
- [ ] `disable-model-invocation: true` (только core/adapters)
- [ ] `trigger-eval.json` создан с 20 queries (только facades)
- [ ] Ссылки на другие скиллы через `Load Skill: name`
- [ ] Обновить [SKILLS_OVERVIEW.md](../SKILLS_OVERVIEW.md) -- добавить строку в таблицу
- [ ] Обновить AGENT.md -- обновить счётчики и таблицу
- [ ] Коммит + push

---

## 7. Как добавить фазу в pipeline

Если ваш скилл -- новая фаза pipeline (между существующими или в конце):

1. **Определить место** в `phase_sequence` (файл `core/orchestration/SKILL.md`). Каждая фаза имеет числовой id -- выберите номер.

2. **Создать скилл** `pipeline/my-phase/SKILL.md` по шаблону Pipeline из раздела 4.

3. **Добавить handoff contract** в `core/orchestration/SKILL.md` -- определить, какие данные фаза принимает и отдаёт.

4. **Обновить dispatch** в `pipeline/worker/SKILL.md` -- добавить вызов новой фазы в нужном месте цепочки.

5. **Обновить complexity routing** если фаза вызывается только для определённых размеров задач (S/M/L/XL).

---

## 8. Частые ошибки

| Ошибка | Почему это проблема | Как исправить |
|--------|-------------------|---------------|
| `description` не начинается с "Use when" | Claude не подберёт скилл по запросу | Всегда `"Use when..."` |
| `name` содержит подчёркивания или пробелы | Не соответствует конвенции, ломает `Load Skill:` | Только kebab-case |
| Нет `trigger-eval.json` для facade | Нет способа проверить trigger accuracy | Создать 20 queries |
| Facade содержит бизнес-логику | Нарушает separation of concerns | Логику в pipeline skill |
| Pipeline skill не описывает Input/Output | Следующая фаза не знает, что ожидать | Добавить YAML-схемы |
| Adapter вызывается напрямую | Обход project.yaml routing | Добавить `disable-model-invocation: true` |

---

## Связанные документы

- [ARCHITECTURE.md](ARCHITECTURE.md) -- сущности и их связи
- [SKILLS_OVERVIEW.md](../SKILLS_OVERVIEW.md) -- полный каталог скиллов
- [CLAUDE.md](../CLAUDE.md) -- entry point репозитория
