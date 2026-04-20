# Agent Skills v4.1 — Context Transfer

Этот файл передаёт контекст между сессиями Claude Code. Прочитай его ПЕРЕД любой работой со скиллами.

## Текущее состояние

**Repo:** ~/Desktop/pet/agent-skills/ — **canonical source of truth**
**Install target:** ~/.claude/skills/ + ~/.claude/commands/ (NOT the source)
**Версия:** 4.1 (see VERSION file)
**Обзор:** [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md)
**Reviews:** [docs/reviews/](docs/reviews/)

For architecture diagrams, skill catalog, pipeline phases, model routing,
adapter contracts, complexity routing, and command reference —
see [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md).

## Ключевые решения

1. **Source of truth** — repo canonical, ~/.claude/skills/ is install target
2. **Checkpoint** — named phases (`completed: [analyze, setup, plan]`), per-part checkpoint в Phase 7
3. **Model routing** — opus: planner + architect + plan-review; sonnet: coder + reviews; haiku: code-researcher
4. **Ship protocol** — shared между worker Phase 9 и ship facade (single source of truth)
5. **Consensus fallback** — timeout 5 min, 1/3 fail → use 2, 2/3 fail → single agent, 3/3 → HALT
6. **Credentials** — `.credentials` file (gitignored), never inline in checkpoint.yaml

## Trigger Evals

200 queries across 10 facades — 100% accuracy verified.
See: `docs/reviews/2026-04-19-trigger-verification.md`

## Как продолжить

```
# Тест на реальной задаче
/worker ARGO-XXXXX

# Архитектурная консультация
/arch "описание задачи"

# Архитектурный ревью существующего кода
/arch-review src/path/to/module

# Figma audit
/figma https://figma.com/design/... http://localhost:4200
```
