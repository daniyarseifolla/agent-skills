# SuperClaude Framework — Полное исследование

> Дата: 2026-04-10
> Источник: https://github.com/SuperClaude-Org/SuperClaude_Framework
> Версия: v4.3.0 (438 файлов, prompt-only framework)
> Метод: 10 параллельных Opus-агентов, чтение всех файлов локально

---

## 1. Обзор проекта

SuperClaude — meta-programming configuration framework для Claude Code. Не содержит runtime-кода — только .md-файлы с инструкциями, которые Claude Code читает и на основе которых адаптирует поведение. MIT лицензия, не аффилирован с Anthropic.

**Состав:**
- 30 slash-команд (все — markdown)
- 20 специализированных агентов (персон)
- 7 поведенческих режимов
- 8 MCP-серверов
- 6 скиллов (с единственным TypeScript-файлом)
- Pytest-плагин с 5 кастомными фикстурами
- Система памяти на JSONL

---

## 2. Структура проекта

```
SuperClaude_Framework/
├── CLAUDE.md                          # 342 строки — корневой конфиг
├── PLANNING.md                        # Архитектурные принципы
├── KNOWLEDGE.md                       # Накопленные знания проекта
├── plugins/superclaude/
│   ├── core/
│   │   ├── PRINCIPLES.md              # 60 строк — философия
│   │   ├── RULES.md                   # 287 строк — правила с примерами
│   │   ├── FLAGS.md                   # 133 строки — поведенческие флаги
│   │   ├── RESEARCH_CONFIG.md
│   │   └── BUSINESS_SYMBOLS.md
│   ├── agents/                        # 20 файлов, 2134 строк суммарно
│   │   ├── pm-agent.md                # 692 строки (треть всего!)
│   │   ├── socratic-mentor.md         # 291 строка
│   │   ├── business-panel-experts.md  # 247 строк
│   │   ├── deep-research-agent.md     # 184 строки
│   │   └── ... (16 компактных по ~48 строк)
│   ├── commands/                      # 30 файлов
│   │   ├── pm.md                      # ~590 строк — самый крупный
│   │   ├── recommend.md               # ~1000 строк — рекомендательный движок
│   │   ├── implement.md, analyze.md, research.md ...
│   │   └── sc.md                      # корневой диспатчер
│   ├── modes/                         # 7 файлов
│   │   ├── MODE_Business_Panel.md     # 11.7 KB
│   │   ├── MODE_Token_Efficiency.md   # 3 KB
│   │   ├── MODE_Task_Management.md    # 3.5 KB
│   │   ├── MODE_Orchestration.md      # 2.7 KB
│   │   ├── MODE_DeepResearch.md       # 1.6 KB
│   │   ├── MODE_Brainstorming.md      # 2.1 KB
│   │   └── MODE_Introspection.md      # 1.8 KB
│   ├── skills/
│   │   ├── confidence-check/SKILL.md + confidence.ts
│   │   ├── pm/SKILL.md
│   │   ├── troubleshoot/SKILL.md
│   │   ├── brainstorm/SKILL.md
│   │   ├── deep-research/SKILL.md
│   │   └── token-efficiency/SKILL.md
│   ├── mcp/                           # 8 серверов + конфиги
│   │   ├── MCP_Context7.md, MCP_Sequential.md
│   │   ├── MCP_Serena.md, MCP_Morphllm.md
│   │   ├── MCP_Magic.md, MCP_Playwright.md
│   │   ├── MCP_Chrome-DevTools.md, MCP_Tavily.md
│   │   └── configs/*.json
│   └── hooks/hooks.json
├── docs/
│   ├── memory/                        # JSONL-файлы памяти
│   ├── mistakes/                      # Логи ошибок (.md)
│   ├── research/                      # Исследовательские документы
│   ├── user-guide/                    # Руководства
│   └── Development/                   # Архитектура, roadmap
├── tests/                             # pytest + плагин
├── src/superclaude/                   # Python-пакет
└── .claude/skills/confidence-check/   # Дублирует plugins/
```

---

## 3. Core: CLAUDE.md (342 строки)

Описывает проект v4.3.0. Ключевые секции:

**Python Environment (CRITICAL):**
> "CRITICAL: This project uses UV for all Python operations. Never use python -m, pip install, or python script.py directly."

**Confidence Check:**
> "Check confidence BEFORE starting: >=90% proceed, 70-89% present alternatives, <70% ask questions."
> "Confidence check ROI: spend 100-200 to save 5,000-50,000" (токенов)

**PM Agent Patterns — три мета-паттерна:**
1. ConfidenceChecker — до выполнения
2. SelfCheckProtocol — после выполнения
3. ReflexionPattern — обучение на ошибках

**Wave → Checkpoint → Wave:**
> Параллельное выполнение независимых задач с промежуточной сборкой результатов. Заявлено ускорение 3.5x.

**Token Budgets:**
- Simple: 200 токенов
- Medium: 1000 токенов
- Complex: 2500 токенов

**Самокритика:**
> "Extension Points We Should Use More" — честное признание, что hooks и skills system используются недостаточно.

---

## 4. Core: RULES.md (287 строк)

Трёхуровневая приоритетная система. Каждое правило: Priority, Triggers, bullet-правила, Right/Wrong примеры.

**Приоритеты:**
- CRITICAL — никогда не нарушать (безопасность, данные, production)
- IMPORTANT — сильно предпочитать (качество, поддерживаемость)
- RECOMMENDED — применять когда практично (оптимизация, стиль)

**Ключевые правила (дословные цитаты):**

```
"No Partial Features: If you start implementing, you MUST complete to working state"
"No TODO Comments: Never leave TODO for core functionality"
"No Mock Objects: No placeholders, fake data, or stub implementations"
"No Marketing Language: Never use 'blazingly fast', '100% secure', 'magnificent'"
"No Sycophantic Behavior: Stop over-praising, provide professional feedback instead"
"Never Assume From Knowledge Cutoff: Don't default to January 2025 or knowledge cutoff dates"
```

**Conflict Resolution Hierarchy:**
> Safety > Scope > Quality > Speed

**Agent Orchestration — два слоя:**
- Task Execution Layer — автоматический подбор агента по контексту
- Self-Improvement Layer — PM Agent как мета-слой

**Temporal Awareness (CRITICAL):**
> Заставляет Claude проверять текущую дату из `<env>` контекста перед любыми временными расчётами. Борьба с галлюцинацией дат.

---

## 5. Core: PRINCIPLES.md (60 строк)

Самый компактный файл. Абстрактная философия.

**Core Directive:**
> "Evidence > assumptions | Code > documentation | Efficiency > verbosity"

**Quality Quadrants:**
- Functional, Structural, Performance, Security

**Trade-off Analysis:**
- Reversible — делай быстро
- Costly — планируй
- Irreversible — валидируй тщательно

(Заимствование из Amazon "one-way door vs two-way door")

---

## 6. Core: FLAGS.md (133 строки)

Каталог поведенческих флагов с автоматическими триггерами.

**Глубина анализа:**
- `--think`: ~4K токенов
- `--think-hard`: ~10K токенов
- `--ultrathink`: ~32K токенов, активирует все MCP-серверы

**Автодетекция:**
- `--brainstorm` — на слова "maybe", "thinking about", "not sure"
- `--token-efficient` — при context usage >75%
- `--delegate` — при >7 директорий ИЛИ >50 файлов ИЛИ complexity >0.8

**Priority Rules:** Safety > Explicit > Depth > MCP Control

---

## 7. Agents (20 файлов, 2134 строк)

### Формат файла агента

```yaml
---
name: agent-name
description: One-line description
category: engineering|analysis|quality|communication|business|meta
---

# Agent Name

## Triggers
- Когда активируется

## Behavioral Mindset
- "Ключевая фраза характера" — главный управляющий промпт

## Focus Areas
- Область 1, Область 2...

## Key Actions
- Действие 1, Действие 2...

## Outputs
- Формат выходных данных

## Boundaries
### Will
- Что делает
### Will Not
- Что НЕ делает (критически важно!)
```

### Каталог агентов

| Агент | Категория | Строк | Триггеры |
|-------|-----------|-------|----------|
| pm-agent | meta | 692 | Старт КАЖДОЙ сессии, `/sc:pm`, после реализации, при ошибках |
| socratic-mentor | communication | 291 | `/sc:socratic-*`, "help me understand", "teach me" |
| business-panel-experts | business | 247 | Бизнес-стратегия, контекстная активация |
| deep-research-agent | specialized | 184 | `/sc:research`, сложные исследования |
| security-engineer | engineering | 50 | Аудит, compliance, threat modeling, `@agent-security` |
| technical-writer | communication | 48 | API-документация, гайды, туториалы |
| backend-architect | engineering | 48 | API, БД, безопасность, надёжность |
| frontend-architect | engineering | 48 | UI, WCAG, Core Web Vitals, responsive |
| devops-architect | engineering | 48 | CI/CD, IaC, мониторинг, Kubernetes |
| system-architect | engineering | 48 | Архитектура, масштабирование, паттерны |
| performance-engineer | analysis | 48 | Оптимизация, нагрузка, Core Web Vitals |
| quality-engineer | quality | 48 | Тесты, edge cases, CI/CD тестирование |
| root-cause-analyst | analysis | 48 | Сложный дебаг, мультикомпонентные сбои |
| requirements-analyst | analysis | 48 | Размытые требования, PRD, скоуп |
| refactoring-expert | engineering | 48 | Техдолг, сложность, SOLID, метрики |
| python-expert | engineering | 48 | Python-разработка, ревью, тулинг |
| learning-guide | communication | 48 | Объяснение кода, алгоритмы, обучение |
| self-review | meta | 33 | Авто-вызов после каждой реализации |
| deep-research | specialized | 31 | Вызывается другими агентами |
| repo-index | discovery | 30 | Начало сессии, значительные изменения кодовой базы |

### Ключевые паттерны поведения (цитаты)

**Measurement-first:**
> "Measure first, optimize second. Never assume where performance problems lie"

**Security-by-default:**
> "Approach every system with zero-trust principles and a security-first mindset. Think like an attacker"

**Evidence-based:**
> "Follow evidence, not assumptions. Look beyond symptoms to find underlying causes"

**Anti-scope-creep:**
> "Build ONLY What's Asked"

### Self-Review Agent (вызывается автоматически)

4 обязательных вопроса после каждой реализации:
1. Are all tests passing? (с реальным выводом)
2. Are all requirements met? (поэлементно)
3. Were assumptions verified? (документировано)
4. Is there concrete evidence? (тест-результаты, diff-ы)

---

## 8. Commands (30 файлов)

### Формат команды

```yaml
---
name: sc:command-name
description: What the command does
category: orchestration|workflow|utility|special|session|meta
complexity: light|medium|heavy
mcp-servers: [context7, sequential, serena, ...]
personas: [architect, frontend, backend, security, qa, ...]
---

# Command content with behavioral instructions
```

### Каталог команд

**Orchestration (5):**
- `agent` — сессионный контроллер, confidence ≥ 0.90 перед имплементацией
- `pm` — Project Manager (~590 строк), PDCA-цикл, автоделегирование
- `brainstorm` — сократический диалог, все 7 персон + все MCP
- `workflow` — генерация workflow из PRD, dependency mapping
- `spawn` — мета-оркестрация Epic→Story→Task→Subtask

**Workflow (4):**
- `implement` — имплементация с автоактивацией персон
- `improve` — систематическое улучшение (quality, performance, security)
- `cleanup` — удаление мёртвого кода, режимы `--safe` и `--aggressive`
- `explain` — объяснение с адаптацией под уровень аудитории

**Utility (7):**
- `analyze` — анализ по 4 доменам (quality, security, performance, architecture)
- `document` — генерация документации (inline/external/api/guide)
- `design` — проектирование (только спецификации, не код)
- `git` — Git-операции с conventional commits
- `troubleshoot` — диагностика (bug/build/performance/deployment)
- `build` — сборка с обработкой ошибок (dev/prod/test)
- `test` — запуск тестов, покрытие, Playwright для E2E

**Special (4):**
- `task` — управление задачами с multi-agent координацией
- `estimate` — оценка трудозатрат с confidence intervals
- `reflect` — рефлексия через Serena MCP
- `select-tool` — выбор между Serena и Morphllm по complexity

**Session (2):**
- `load` — загрузка контекста сессии
- `save` — сохранение состояния + checkpoint

**Meta (8):**
- `sc` — корневой диспатчер
- `help` — справка по командам и флагам
- `recommend` — рекомендательный движок (~1000 строк!)
- `research` — глубокий веб-ресёрч с Tavily, multi-hop reasoning
- `index-repo` — индексация репо (заявлено: 58K→3K токенов, 94% reduction)
- `index` — генерация документации с cross-referencing
- `spec-panel` — мульти-экспертная ревью спецификаций (10 экспертов)
- `business-panel` — бизнес-анализ панелью экспертов

### Интересные промпт-паттерны

**Порог confidence как gate (agent.md):**
> "Track confidence from the skill results; do not implement below 0.90. Escalate to the user if confidence stalls or new context is required."

**Симуляция экспертов с характерными фразами (spec-panel.md):**
> KARL WIEGERS: "This requirement lacks measurable acceptance criteria. How would you validate compliance in production?"
> GOJKO ADZIC: "Can you provide concrete examples demonstrating this requirement in real-world scenarios?"

**Anti-patterns как жёсткие запреты (pm.md):**
> ❌ "Got an error. Let's just try again"
> ❌ "Retry: attempt 1... attempt 2... attempt 3..."
> ✅ "Got an error. Investigating via official documentation"

**ROI-расчёт как мотивация (index-repo.md):**
> "Before: Reading all files → 58,000 tokens every session. After: Read PROJECT_INDEX.md → 3,000 tokens (94% reduction). Break-even: 1 session. 10 sessions savings: 550,000 tokens."

**Memory Key Schema (pm.md):**
> `session/context`, `plan/[feature]/hypothesis`, `execution/[feature]/do`, `learning/patterns/[name]`, `learning/mistakes/[timestamp]`

**Zero-Token Baseline (pm.md):**
> "Start with no MCP tools loaded (gateway URL only). Load on-demand per execution phase. Unload after phase completion."

---

## 9. Modes (7 файлов)

Режимы перенастраивают поведение агента при активации: стиль мышления, формат вывода, приоритеты, набор инструментов.

### Business Panel (11.7 KB — самый крупный)

9 экспертов (Porter, Christensen, Drucker, Meadows, Taleb, Collins, Kim/Mauborgne, Godin, Doumont). Три фазы: Discussion → Debate → Socratic Inquiry.

> "Cross-Pollination: Experts build upon and reference each other's insights"
> Debate: "structured disagreement and challenge"

### Orchestration (2.7 KB)

Матрица выбора инструментов + управление ресурсами:
- 🟢 <75% — полные возможности
- 🟡 75-85% — efficiency mode, reduce verbosity
- 🔴 >85% — essential operations only, fail fast

> "Infrastructure and technical configuration changes MUST consult official documentation before making recommendations"

### Introspection (1.8 KB — самый компактный)

Мета-когнитивный режим с transparency markers:
> Вместо "I'll analyze this code" → "Why did I choose structural analysis over functional? Alternative: Could have started with data flow patterns. Learning: Structure-first approach works for OOP, not functional"

### Task Management (3.5 KB)

4-уровневая иерархия: Plan → Phase → Task → Todo. Кросс-сессионная персистентность через memory keys. Чекпоинты каждые 30 минут.

> Start: `list_memories() → read_memory("current_plan") → think_about_collected_information()`
> End: `think_about_whether_you_are_done()`

### Deep Research (1.6 KB)

> "Completeness over speed, Accuracy over speculation, Evidence over speculation, Verification over assumption"
> "Every claim needs verification"
> Автоматически подключает deep-research-agent + Tavily.

### Brainstorming (2.1 KB)

Сократический партнёр. Неассертивен — "Non-Presumptive: Avoid assumptions, let user guide discovery direction". Результат — структурированный бриф требований.

### Token Efficiency (3 KB)

Символьная коммуникация для 30-50% экономии:
- Логические: стрелки, "поэтому"/"потому что"
- Статусы: галочки, кресты, часы
- Домены: молния=перформанс, щит=безопасность

> Пример сжатия: "The authentication system has a security vulnerability in the user validation function" → `auth.js:45 → 🛡 sec risk in user val()`

### Архитектура режимов

Режимы композируются:
- **Orchestration** → может активировать **Token Efficiency** при нехватке контекста
- **Business Panel** → использует символы Token Efficiency
- **Task Management** → обеспечивает персистентность для долгих режимов
- **Introspection** → накладывается поверх любого как мета-слой

---

## 10. Skills (6 скиллов)

### Confidence Check (основной, с TypeScript)

**SKILL.md** описывает 5 проверок с весами:

| Проверка | Вес |
|----------|-----|
| Нет дубликатов в кодовой базе | 25% |
| Соответствие архитектуре проекта | 25% |
| Проверена официальная документация | 20% |
| Найдены рабочие OSS-реализации | 15% |
| Определена root cause | 15% |

Три порога: ≥90% proceed, 70-89% investigate, <70% STOP.

**confidence.ts (333 строки, полная версия):**
- Класс `ConfidenceChecker` с реальным FS-доступом
- `hasOfficialDocs()` обходит дерево каталогов вверх, ищет README.md, CLAUDE.md, docs/
- `hasExistingPatterns()` ищет test_*.py в той же директории
- `hasClearPath()` проверяет осмысленность имени теста
- Экспортирует legacy-функции `confidenceCheck()` и `getRecommendation()`

**Ключевое наблюдение:** TypeScript — формализация логики подсчёта. Реальная проверка (Grep, WebSearch) выполняется агентом Claude по инструкциям SKILL.md. TypeScript не рантайм.

### PM (Project Management)

Полный PDCA-цикл:
- **Plan** — что, зачем, критерии, риски
- **Do** — трекинг через TodoWrite, запись ошибок, чекпоинты
- **Check** — что сработало, что нет, оценка
- **Act** — успех=документировать паттерн, неудача=документировать ошибку

Встраивает Confidence Check как обязательный шаг.

### Troubleshoot

8 шагов: STOP → Observe → Hypothesize → Investigate → Root Cause → Fix → Verify → Learn.

Антипаттерны:
> "Got an error. Let's just try again"
> "Retry: attempt 1... attempt 2... attempt 3..."
> "It timed out, so let's increase the wait time"
> "There are warnings but it works, so it's fine"

Формат вывода: Error / Expected / Cause / Fix / Prevention.

### Brainstorm

Сократический диалог. 5 принципов: спрашивай, дивергенция, "Yes, and...", визуализация, конвергенция. Результат: Options с Pros/Cons/Effort/Risk.

### Deep Research

Scope → Source Gathering → Evidence Evaluation → Synthesis → Citation. Уровни уверенности (high/medium/low). Обязательные Sources.

### Token Efficiency (17 строк — самый компактный)

Буллеты вместо параграфов, аббревиатуры (fn, impl, cfg), символы статуса (OK/FAIL/WARN/SKIP), без преамбул.

---

## 11. Memory System

### Архитектура: три типа памяти

| Тип | Файл | Назначение |
|-----|------|-----------|
| ReflexionMemory | `reflexion.jsonl` | Ошибки и решения |
| Workflow Metrics | `workflow_metrics.jsonl` | Метрики производительности |
| Pattern Learning | `patterns_learned.jsonl` | Успешные паттерны |

### Формат JSONL

**Reflexion-запись:**
```json
{
  "ts": "2025-10-17T09:23:15+09:00",
  "task": "implement JWT authentication",
  "mistake": "JWT validation failed with undefined secret",
  "evidence": "TypeError: Cannot read property 'verify' of undefined",
  "rule": "Always verify environment variables are set before implementing authentication",
  "fix": "Added JWT_SECRET to .env file",
  "tests": ["Check .env.example for required vars", "Add env validation to app startup"],
  "status": "adopted"
}
```

**Workflow metrics:**
```json
{
  "timestamp": "2025-10-17T03:15:00+09:00",
  "session_id": "test_initialization",
  "task_type": "schema_creation",
  "complexity": "light",
  "tokens_used": 1250,
  "time_ms": 1800,
  "success": true,
  "user_feedback": "satisfied"
}
```

### Progressive Loading (5 уровней)

- Layer 0: Bootstrap — 150 токенов (95% снижение от старых 2300)
- Layer 1-5: по сложности, от 100-500 до 20K+ токенов

### A/B-тестирование workflow

Epsilon-greedy: 80% задач → лучший workflow, 20% → экспериментальный. После 20 испытаний — t-test (p < 0.05).

### Реальность vs заявления

- `solutions_learned.jsonl`: 120 записей = 15 уникальных × 8 дублей
- `workflow_metrics.jsonl`: 1 запись
- `patterns_learned.jsonl`: 1 запись
- Mindbase (векторный поиск): "Never implemented"

---

## 12. Mistakes/Reflexion System

### Формат Mistake Record (.md)

```
docs/mistakes/{test_name}-{YYYY-MM-DD}.md
```

Секции: What Happened, Root Cause, Why Missed, Fix Applied, Prevention Checklist, Lesson Learned.

### Три механизма предотвращения

**A. ReflexionPattern** — запись и поиск ошибок по сигнатуре. Паттерн-матчинг по типу ошибки. Персистентность через `reflexion.jsonl`.

**B. ReflectionEngine** — предисполнительная проверка:
1. Requirement clarity (50% weight) — чёткость формулировки
2. Mistake check (30%) — поиск похожих прошлых ошибок
3. Context readiness (20%) — наличие контекста
Порог: <70% → блокировка.

**C. SelfCorrectionEngine** — полный цикл:
- `detect_failure()` → `analyze_root_cause()` → `learn_and_prevent()` → `check_against_past_mistakes()`
- При повторной ошибке не дублирует, а инкрементирует `recurrence_count`

### SelfCheckProtocol — антигаллюцинация

Детектирует 4 типа:
1. "Тесты прошли" без реального вывода
2. Статус "complete" без evidence
3. "Complete" при упавших тестах
4. Слова неуверенности ("probably", "might")

### Реальность

**Все 9 Mistake Record пусты** — секции Root Cause, Why Missed, Prevention, Lesson содержат "Not analyzed" / "Not documented". Заполнены только What Happened и Fix.

**Дубликаты:** `test_database_connection` записан 3 раза (2025-11-11, 2025-11-14, 2026-03-22) с идентичным содержимым.

**Разрыв:** Исследовательский документ описывает амбициозную архитектуру. Чеклист показывает: Reflexion Pattern integration, Token-Budget Reflection, workflow_metrics — не завершены.

---

## 13. MCP Integration (8 серверов)

### Каталог

| MCP | Назначение | Fallback без MCP |
|-----|-----------|-----------------|
| Context7 | Документация библиотек | WebSearch (3x медленнее) |
| Sequential Thinking | Пошаговое рассуждение | Native reasoning (2x токенов) |
| Serena | LSP, символьные операции | Grep+Read (3x медленнее) |
| Morphllm (Fast Apply) | Паттерновые правки, bulk | Обычное редактирование |
| Magic (21st.dev) | UI-компоненты | Ручная верстка |
| Playwright | E2E, браузерная автоматизация | Manual testing |
| Chrome DevTools | Перформанс, live-дебаг | Playwright (менее детально) |
| Tavily | Веб-поиск с фильтрацией | WebSearch (менее курированно) |

### Ключевой принцип: Optional Design

> "MCPs enhance, but never required"

Каждый MCP имеет нативный fallback. Деградация количественная, не качественная: "Same result, slower execution".

Три режима fallback:
- `graceful` — попробовать MCP, тихо откатиться
- `aggressive` — предпочитать нативные
- `disabled` — ошибка при недоступности

### Selection Matrix

- Simple (1-2 файла) — нативные инструменты
- Medium (3-10) — Context7 при новой библиотеке
- Complex (10+) — Serena + Sequential
- Research — Tavily + Context7

### Lazy Activation

Серверы не предзагружаются. Активация только при необходимости. PM Agent координирует выбор через session lifecycle.

---

## 14. Tests и Pytest Plugin

### Конфигурация

- pytest через `pyproject.toml`: `-v`, `--strict-markers`, `--tb=short`
- 8 кастомных маркеров: `unit`, `integration`, `hallucination`, `performance`, `confidence_check`, `self_check`, `reflexion`, `complexity`
- Coverage: 90%+ для `src/superclaude/`

### 5 Fixtures от плагина

| Фикстура | Назначение |
|-----------|-----------|
| `confidence_checker` | Экземпляр ConfidenceChecker |
| `self_check_protocol` | Протокол самопроверки (validate, format_report) |
| `reflexion_pattern` | Запись/получение ошибок (record_error, get_solution) |
| `token_budget` | Менеджер токен-бюджета, читает маркер complexity |
| `pm_context` | Пути к файлам памяти PM Agent |

### Что тестируется

- **test_confidence.py** (12 тестов): 5 проверок с весами, пороги, рекомендации
- **test_token_budget.py** (8+ тестов): три уровня сложности, маркер-driven
- **test_parallel.py** (14 тестов): DAG-планирование, Wave-Checkpoint-Wave, реальный параллелизм с замером времени
- **test_pytest_plugin.py** (8 тестов): все 5 фикстур + сквозной workflow
- **test_execution_engine.py** (7 тестов): intelligent/quick/safe execute, статусы
- **test_reflexion.py + test_reflection.py**: запись/поиск ошибок
- **test_self_check.py + test_self_correction.py**: детекция галлюцинаций, категоризация ошибок

---

## 15. Architecture & Research

### ROI-анализ (их собственные цифры)

**Confidence Check:** 25-250x экономия токенов (100-200 на проверку → предотвращение 5K-50K).

**Index-repo:** 94% снижение (58K → 3K токенов). Break-even: 1 сессия.

**PM Agent vs встроенные возможности моделей:**
> Claude Sonnet 4.5: 77-82% на SWE-bench, Extended Thinking (аналог Reflexion), 432 шага автономной работы.
> Для 80% пользователей PM Agent не оправдан.
> Self-Improving Coding Agent: +2% для новых моделей (vs +36% для старых).

**Параллельное выполнение:**
> Python GIL → ThreadPoolExecutor: 0.91x (на 9% МЕДЛЕННЕЕ)
> Task Tool (Claude Code API): 4.1x ускорение

**Токенная эффективность:**
> Старая архитектура: 26,000 токенов на старте
> Новая (Python + Skills): 0 на старте, ~2,500 по требованию (97% экономия)

### Главный парадокс

Проект честно признаёт: значительная часть функционала (Reflexion, Confidence Check, Self-Validation) **уже встроена в современные LLM** через Extended Thinking. Уникальная ценность остаётся в межсессионной памяти и систематической документации ошибок.

### Gap-анализ (март 2026)

SuperClaude использует малую часть Claude Code:
- Из 28 hook-событий — задействованы единицы
- Skills system, Plan Mode, Settings Profiles — не используются
- Приоритет: миграция 30 команд → формат skills для авто-триггеринга

---

## 16. Красные флаги

| Проблема | Детали |
|----------|--------|
| Дубликаты данных | 120 записей ошибок = 15 уникальных × 8 дублей |
| Пустые поля | Mistake records: "Not analyzed" во всех аналитических секциях |
| Мёртвые фичи | Mindbase "Never implemented", Serena memory не используется |
| Завышенные метрики | "94% hallucination detection" — симуляция, не реальные замеры |
| Python GIL | ThreadPoolExecutor дал 0.91x — потрачено время на исследование |
| Объём без глубины | 438 файлов для prompt-only framework, много повторений |
| Два deep-research | deep-research-agent.md (184) + deep-research.md (31) — путаница |
| Дублирование скиллов | confidence-check в plugins/ И в .claude/skills/ с разным кодом |
