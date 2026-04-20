---
name: architect
description: "Standalone architectural analysis. Proposes 3 approaches from different lenses with trade-off comparison. Use when user says /arch, \"архитектурный совет\", \"предложи архитектуру\", \"как лучше спроектировать\", \"какой подход выбрать\"."
human_description: "Standalone архитектурная консультация: показывает 3 подхода с trade-off сравнением, пользователь выбирает."
---

# Architect — Facade

Standalone architectural consultation. Launches 3 architect agents with stack-specific lenses, shows comparison.

## Activation

Triggers:
- `/arch` command
- "архитектурный совет", "предложи архитектуру"
- "как лучше спроектировать", "какой подход выбрать"
- "architect advice", "architectural perspective"

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| --stack | Override tech-stack detection | autodetect |
| --model | Override agent model | opus |

## Input Variants

| Variant | Example |
|---------|---------|
| With task key | `/arch ARGO-12345` — fetch from Jira |
| With description | `/arch "notification system with websocket"` |
| Bare | `/arch` — ask user what to architect |

## Delegation

1. Determine tech stack:
   - If `--stack` flag → use it
   - Else: read `.claude/project.yaml`
   - Else: autodetect from package.json etc.

2. Load adapters:
   - tech-stack adapter (for codebase research)
   - architect-roles adapter (for lenses)

3. If task key provided:
   - Load task-source adapter
   - Fetch task (title, AC, description, Figma URLs)

4. Invoke planner in architect-only mode (brainstorming is owned by pipeline/planner):
   ```yaml
   Skill: pipeline-planner
   mode: architect-only
   ```
   This runs steps 3-5 only (research + brainstorming + architect).
   Shows 3 approaches + comparison table. No arbiter.

5. User interaction:
   - User selects / discusses / asks questions
   - Optional: save chosen approach to `architecture.md`
