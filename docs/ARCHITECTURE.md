# Architecture Guide

Руководство по архитектуре agent-skills: какие сущности существуют и как они связаны.

## Сущности

### 1. Commands (`commands/*.md`)

Slash-команды (`/worker`, `/arch`, `/deploy`). Точка входа при ручном вызове. Загружают facade или pipeline skill.

### 2. Facades (`facades/*/SKILL.md`)

NL-триггеры ("сделай задачу", "архитектурный совет"). Точка входа при распознавании намерения. Парсят ввод, определяют контекст, делегируют в pipeline.

### 3. Pipeline Skills (`pipeline/*/SKILL.md`)

Внутренние фазы pipeline. Не вызываются пользователем напрямую. Worker загружает их по очереди.

### 4. Adapters (`adapters/*/SKILL.md`)

Сменные интеграции. Подставляются по типу проекта (Jira/GitLab/Angular/Figma/Slack). Загружаются worker-ом из `project.yaml`.

### 5. Core (`core/*/SKILL.md`)

Протоколы и паттерны. Не выполняют работу сами, определяют правила для других.

### 6. Evals (`*/evals/trigger-eval.json`)

Тесты trigger accuracy для facades.

## Связи (flow diagram)

```
User types "/worker ARGO-123"
  -> commands/worker.md (router)
    -> facades/worker/SKILL.md (parse, autodetect, overrides)
      -> pipeline/worker/SKILL.md (load adapters, run phases 1-9)
        -> pipeline/planner/ (Phase 5, includes architect step)
          -> pipeline/architect/ (3 agents + arbiter)
        -> pipeline/coder/ (Phase 7)
        -> pipeline/code-reviewer/ (Phase 8, parallel)
        -> core/ship-protocol/ (Phase 9, shared steps)

User types "архитектурный совет"
  -> facades/architect/SKILL.md (NL trigger matched)
    -> pipeline/planner/ in architect-only mode
      -> pipeline/architect/ (3 approaches, no arbiter)
```

## Правила

- **Commands** -> загружают facades или pipeline skills
- **Facades** -> загружают pipeline skills и adapters (для routing/контекста проекта)
- **Pipeline skills** -> загружают core skills и adapters
- **Core skills** -> не загружают ничего (protocols only)
- **Adapters** -> не загружают ничего (config only)

## Naming

| Тип | Naming convention | Пример |
|-----|-------------------|--------|
| command | `/kebab-case` | `/arch-review`, `/scan-qa` |
| facade | `kebab-case` (name field) | `worker`, `architect`, `arch-review` |
| pipeline | `pipeline-kebab-case` (name field) | `pipeline-worker`, `pipeline-architect` |
| adapter | `adapter-kebab-case` (name field) | `adapter-jira`, `adapter-architect-roles` |
| core | `core-kebab-case` (name field) | `core-orchestration`, `core-ship-protocol` |

## Frontmatter поля

| Поле | Назначение | Кто читает |
|------|-----------|------------|
| `name` | Уникальный идентификатор | Claude skill system |
| `description` | "Use when..." -- trigger matching | Claude skill selection |
| `human_description` | Что делает -- для людей | Разработчики |
| `model` | Какую модель использовать | Worker при dispatch |
| `disable-model-invocation` | Не вызывать как agent | Claude -- предотвращает прямой вызов core/adapters |
