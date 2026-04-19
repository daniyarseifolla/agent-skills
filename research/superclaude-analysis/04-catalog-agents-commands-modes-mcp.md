# SuperClaude — Каталог: Агенты, Команды, Режимы, MCP, Ролевые персоны

> Дата: 2026-04-10
> Версия SuperClaude: v4.3.0

---

## 1. Агенты (20 штук)

Все агенты — markdown-файлы в `plugins/superclaude/agents/`. Формат: YAML frontmatter (name, description, category) + секции Triggers, Behavioral Mindset, Focus Areas, Key Actions, Outputs, Boundaries (Will/Will Not).

### Meta-слой (управляют другими)

| Агент | Файл | Строк | Суть |
|-------|------|-------|------|
| PM Agent | pm-agent.md | 692 | "Supreme Commander" — PDCA-цикл, кросс-сессионная память, запускается при КАЖДОЙ сессии. Единственный с интеграцией Serena MCP memory. Треть всего объёма агентов |
| Self-Review | self-review.md | 33 | Авто-вызов после каждой реализации. 4 обязательных вопроса: тесты? требования? допущения? доказательства? |
| Repo Index | repo-index.md | 30 | Генерирует PROJECT_INDEX.md при устаревании >7 дней. Заявлена экономия 58K→3K токенов (94%) |

### Engineering (строители)

| Агент | Файл | Строк | Триггеры | Behavioral Mindset |
|-------|------|-------|----------|-------------------|
| System Architect | system-architect.md | 48 | Архитектура, масштабирование, паттерны, выбор технологий | "Think in systems, not components" |
| Backend Architect | backend-architect.md | 48 | API, БД, безопасность, надёжность | "Prioritize reliability and data integrity above all else" |
| Frontend Architect | frontend-architect.md | 48 | UI, WCAG, Core Web Vitals, responsive | "Think user-first. Accessibility as fundamental requirement, not afterthought" |
| DevOps Architect | devops-architect.md | 48 | CI/CD, IaC, мониторинг, Kubernetes | "Automate everything, monitor everything" |
| Python Expert | python-expert.md | 48 | Python-разработка, ревью, тулинг | "Pythonic is not just a style, it's a philosophy" |
| Refactoring Expert | refactoring-expert.md | 48 | Техдолг, сложность, SOLID, метрики | "Every refactoring change must be small, safe, and measurable" |

### Analysis (аналитики)

| Агент | Файл | Строк | Триггеры | Behavioral Mindset |
|-------|------|-------|----------|-------------------|
| Performance Engineer | performance-engineer.md | 48 | Оптимизация, нагрузка, Core Web Vitals, профилирование | "Measure first, optimize second. Never assume where problems lie" |
| Root Cause Analyst | root-cause-analyst.md | 48 | Сложный дебаг, мультикомпонентные сбои, рекурентные проблемы | "Follow evidence, not assumptions. Look beyond symptoms" |
| Requirements Analyst | requirements-analyst.md | 48 | Размытые требования, PRD, стейкхолдер-анализ, скоуп | "Clarity prevents rework" |
| Security Engineer | security-engineer.md | 50 | Аудит, compliance, threat modeling, `@agent-security` | "Zero-trust principles. Think like an attacker" |
| Quality Engineer | quality-engineer.md | 48 | Тестовые стратегии, edge cases, автотесты, CI/CD | "Quality is built in, not tested in" |

### Communication (коммуникаторы)

| Агент | Файл | Строк | Триггеры | Behavioral Mindset |
|-------|------|-------|----------|-------------------|
| Technical Writer | technical-writer.md | 48 | API-документация, гайды, туториалы | "Write for your audience, not for yourself" |
| Learning Guide | learning-guide.md | 48 | Объяснение кода, алгоритмы, обучение | "Meet the learner where they are" |
| Socratic Mentor | socratic-mentor.md | 291 | `/sc:socratic-*`, "help me understand", "teach me" | "Guide discovery through strategic questioning rather than direct instruction" |

Socratic Mentor — третий по объёму. Трёхуровневая адаптация вопросов (beginner/intermediate/advanced). Встроены домены: Clean Code и GoF Patterns.

### Specialized

| Агент | Файл | Строк | Триггеры | Суть |
|-------|------|-------|----------|------|
| Deep Research Agent | deep-research-agent.md | 184 | `/sc:research`, сложные исследования, академический контекст | Полноценный ресёрч с multi-hop reasoning, self-reflective mechanisms, credibility scoring |
| Deep Research (фасад) | deep-research.md | 31 | Вызывается другими агентами (нет пользовательских триггеров) | Лёгкий фасад для поиска через Tavily/WebFetch/Context7 |
| Business Panel Experts | business-panel-experts.md | 247 | Бизнес-стратегия, контекстная активация | 9 персон (Porter, Drucker, Taleb...) в режимах Discussion/Debate/Socratic |

### Паттерны поведения (цитаты из агентов)

**Measurement-first (performance-engineer, refactoring-expert):**
> "Measure first, optimize second. Never assume where performance problems lie"
> "Every refactoring change must be small, safe, and measurable"

**Security-by-default (security-engineer, backend-architect):**
> "Approach every system with zero-trust principles and a security-first mindset. Think like an attacker"
> "Prioritize reliability and data integrity above all else"

**Evidence-based (root-cause-analyst, deep-research-agent):**
> "Follow evidence, not assumptions. Look beyond symptoms to find underlying causes"
> "Think like a research scientist crossed with an investigative journalist"

**Anti-scope-creep (все агенты через RULES.md):**
> "Build ONLY What's Asked"

### Boundaries (Will / Will Not)

Каждый агент имеет чёткие границы. Примеры:

**Frontend Architect:**
- Will: UI-компоненты, WCAG, responsive, design systems
- Will Not: трогать БД, серверный код, DevOps

**Backend Architect:**
- Will: API, БД, авторизация, кэширование
- Will Not: UI, стилизация, фронтенд

**Security Engineer:**
- Will: аудит, threat modeling, compliance, vulnerability analysis
- Will Not: имплементировать фичи, писать бизнес-логику

---

## 2. Команды (30 штук)

Все команды — markdown-файлы в `plugins/superclaude/commands/`. Формат: YAML frontmatter (name, description, category, complexity, mcp-servers[], personas[]) + инструкции.

### Orchestration (5 команд)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:agent` | agent.md | heavy | all | Сессионный контроллер. Стартует при начале сессии, оркестрирует исследование и реализацию. **Confidence ≥ 0.90 gate перед имплементацией** |
| `/sc:pm` | pm.md | heavy | serena, sequential | Project Manager (~590 строк). PDCA-цикл, автоделегирование суб-агентам. Zero-Token Baseline: "Start with no MCP tools loaded" |
| `/sc:brainstorm` | brainstorm.md | medium | all | Интерактивное обнаружение требований через сократический диалог. Все 7 персон + все 6 MCP |
| `/sc:workflow` | workflow.md | heavy | all | Генерация имплементационных workflow из PRD. Dependency mapping |
| `/sc:spawn` | spawn.md | heavy | sequential | Мета-оркестрация: разбиение задач по иерархии Epic→Story→Task→Subtask |

### Workflow (4 команды)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:implement` | implement.md | heavy | serena, context7, sequential | Имплементация фич с автоактивацией персон (architect, frontend, backend, security, qa) |
| `/sc:improve` | improve.md | medium | serena, sequential | Систематическое улучшение: quality, performance, maintainability, security |
| `/sc:cleanup` | cleanup.md | light | serena | Удаление мёртвого кода, оптимизация импортов. Режимы `--safe` и `--aggressive` |
| `/sc:explain` | explain.md | light | context7 | Объяснение кода/концепций с адаптацией под уровень аудитории |

### Utility (7 команд)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:analyze` | analyze.md | medium | serena, sequential | Анализ кода по 4 доменам: quality, security, performance, architecture |
| `/sc:document` | document.md | medium | context7 | Генерация документации: inline, external, api, guide |
| `/sc:design` | design.md | heavy | sequential | Проектирование архитектуры, API, компонентов, БД-схем. **Только спецификации, НЕ код** |
| `/sc:git` | git.md | light | — | Git-операции с генерацией conventional commits |
| `/sc:troubleshoot` | troubleshoot.md | medium | sequential, tavily | Диагностика: bug/build/performance/deployment. 8 шагов: STOP→Observe→Hypothesize→Fix→Learn |
| `/sc:build` | build.md | medium | — | Сборка проектов с обработкой ошибок. dev/prod/test окружения |
| `/sc:test` | test.md | medium | playwright | Запуск тестов, покрытие, watch-mode. Playwright для E2E |

### Special (4 команды)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:task` | task.md | medium | serena | Расширенное управление задачами с multi-agent координацией и cross-session persistence |
| `/sc:estimate` | estimate.md | medium | sequential | Оценка трудозатрат с confidence intervals и risk assessment |
| `/sc:reflect` | reflect.md | light | serena | Рефлексия: валидация выполненной задачи |
| `/sc:select-tool` | select-tool.md | light | — | Интеллектуальный выбор между Serena и Morphllm по complexity scoring |

### Session (2 команды)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:load` | load.md | light | serena | Загрузка контекста сессии, восстановление состояния |
| `/sc:save` | save.md | light | serena | Сохранение состояния + checkpoint creation, cross-session persistence |

### Meta (8 команд)

| Команда | Файл | Complexity | MCP | Суть |
|---------|------|-----------|-----|------|
| `/sc:sc` | sc.md | light | — | Корневой диспатчер: показывает доступные команды |
| `/sc:help` | help.md | light | — | Справка по всем командам и флагам |
| `/sc:recommend` | recommend.md | medium | — | Рекомендательный движок (~1000 строк! Самый длинный файл). Анализ запроса → подбор команд + флагов + MCP |
| `/sc:research` | research.md | heavy | tavily, context7, sequential | Глубокий веб-ресёрч. Адаптивная глубина: quick/standard/deep/exhaustive. Multi-hop reasoning |
| `/sc:index-repo` | index-repo.md | medium | serena | Индексация репозитория. "58K→3K tokens (94% reduction)" |
| `/sc:index` | index.md | medium | — | Генерация документации проекта с cross-referencing |
| `/sc:spec-panel` | spec-panel.md | heavy | sequential | Мульти-экспертная ревью спецификаций. 10 реальных экспертов. 3 режима |
| `/sc:business-panel` | business-panel.md | heavy | sequential | Бизнес-анализ панелью из 9 экспертов. 3 режима + автоподбор |

---

## 3. Режимы (7 штук)

Режимы — markdown-файлы в `plugins/superclaude/modes/`. При активации перенастраивают поведение агента: стиль мышления, формат вывода, приоритеты, набор инструментов.

### Brainstorming (2.1 KB)

**Триггеры:** Размытые запросы ("I want to build something..."), ключевые слова (brainstorm, explore, not sure), индикаторы неопределённости (maybe, possibly), флаги `--brainstorm`, `--bs`.

**Поведение:** Сократический партнёр по исследованию. Принципиально неассертивен:
> "Non-Presumptive: Avoid assumptions, let user guide discovery direction"

Результат — структурированный бриф требований. Поддерживает кросс-сессионную персистентность контекста.

### Deep Research (1.6 KB)

**Триггеры:** `/sc:research`, ключевые слова (investigate, explore, discover), вопросы требующие актуальных данных, флаг `--research`.

**Поведение:** Приоритеты полностью перестраиваются:
> "Completeness over speed, Accuracy over speculation, Evidence over speculation, Verification over assumption"

Агент обязан вести уровни уверенности, давать inline-цитаты, явно признавать неопределённость. Автоматически подключает deep-research-agent + Tavily.

### Token Efficiency (3 KB)

**Триггеры:** context usage >75%, крупные операции, флаги `--uc`, `--ultracompressed`.

**Поведение:** Символьная коммуникация для 30-50% экономии токенов. Три системы символов:
- Логические: → (следовательно), ← (потому что), ↔ (взаимосвязь)
- Статусы: ✓ (OK), ✗ (FAIL), ⏳ (pending), ⚠ (warning)
- Домены: ⚡ (перформанс), 🛡 (безопасность), 🔧 (инфраструктура)

**Пример сжатия:**
```
До:  "The authentication system has a security vulnerability in the user validation function"
После: auth.js:45 → 🛡 sec risk in user val()
```

### Orchestration (2.7 KB)

**Триггеры:** Координация нескольких инструментов, загрузка ресурсов >75%, >3 файлов, сложные решения маршрутизации.

**Поведение:** Матрица выбора инструментов + три ресурсные зоны:
- 🟢 <75% — полные возможности
- 🟡 75-85% — "Activate efficiency mode, Reduce verbosity"
- 🔴 >85% — "Essential operations only, Minimal output, Fail fast"

Жёсткое правило:
> "Infrastructure and technical configuration changes MUST consult official documentation before making recommendations"

### Task Management (3.5 KB)

**Триггеры:** Операции с >3 шагами, скоуп >2 директорий или >3 файлов, флаги `--task-manage`, `--delegate`.

**Поведение:** 4-уровневая иерархия: Plan → Phase → Task → Todo. Каждый уровень записывается в persistent memory. Единственный режим с явным протоколом кросс-сессионной персистентности.

**Протокол:**
```
Start:  list_memories() → read_memory("current_plan") → think_about_collected_information()
Work:   checkpoint каждые 30 минут
End:    think_about_whether_you_are_done() → cleanup временных ключей
```

### Introspection (1.8 KB — самый компактный)

**Триггеры:** Запросы на самоанализ, восстановление после ошибок, сложные задачи, флаг `--introspect`.

**Поведение:** Мета-когнитивный режим. Агент показывает процесс своих решений:
> Вместо "I'll analyze this code" →
> "Why did I choose structural analysis over functional? Alternative: Could have started with data flow patterns. Learning: Structure-first approach works for OOP, not functional"

### Business Panel (11.7 KB — самый крупный)

**Триггеры:** `/sc:business-panel`, анализ бизнес-документов, стратегическое планирование.

**Поведение:** 9 экспертов в трёх фазах:
- Discussion — эксперты строят на выводах друг друга
- Debate — structured disagreement, спор с цитированием
- Socratic Inquiry — каждый эксперт формулирует вопросы из своего фреймворка

### Композиция режимов

Режимы не изолированы — они композируются:
```
Orchestration → может активировать Token Efficiency (при нехватке контекста)
Business Panel → использует символы Token Efficiency
Task Management → обеспечивает персистентность для любого долгого режима
Introspection → накладывается поверх любого как мета-слой рефлексии
Deep Research + Brainstorming → антиподы: строгость vs свобода
```

---

## 4. MCP-серверы (8 штук)

Каждый описан в трёх местах: `mcp/MCP_*.md` (документация), `mcp/configs/*.json` (конфиг подключения), `.mcp.json` (центральная активация).

### Каталог

| MCP | Назначение | Триггеры | Fallback без MCP |
|-----|-----------|----------|-----------------|
| **Context7** | Документация библиотек (React, Vue, Next.js, Django...) | Новая библиотека, pre-implementation, `--c7` | WebSearch (3x медленнее, менее курированно) |
| **Sequential Thinking** | Пошаговое рассуждение с контролируемой глубиной | 3+ взаимосвязанных компонента, `--think`/`--think-hard`/`--ultrathink` | Native reasoning (2x токенов) |
| **Serena** | LSP: rename, extract, find references, dependency tracking | Рефакторинг 10+ файлов, символьные операции, `--serena` | Grep+Read (3x медленнее, то же качество) |
| **Morphllm (Fast Apply)** | Паттерновые bulk-правки, style guide enforcement | Массовые замены, обновление фреймворка | Обычное редактирование (больше токенов) |
| **Magic (21st.dev)** | UI-компоненты из дизайн-паттернов 21st.dev | Кнопки, формы, модалки, таблицы | Ручная верстка |
| **Playwright** | E2E-тестирование, браузерная автоматизация | Визуальное тестирование, WCAG, user journeys | Manual testing |
| **Chrome DevTools** | Перформанс-анализ, live-дебаг | CLS, LCP, network, console, DOM/CSS | Playwright (менее детально) |
| **Tavily** | Веб-поиск с фильтрацией и credibility scoring | Deep research, multi-hop, `--tavily` | WebSearch (менее курированно) |

### Глубина анализа (Sequential Thinking)

```
--think       → ~4K токенов   (стандартный анализ)
--think-hard  → ~10K токенов  (глубокий анализ)
--ultrathink  → ~32K токенов  (максимум, все MCP активны)
```

### Selection Matrix

| Сложность задачи | Рекомендуемые MCP |
|------------------|-------------------|
| Simple (1-2 файла) | Нативные инструменты, MCP не нужны |
| Medium (3-10 файлов) | Context7 при новой библиотеке |
| Complex (10+ файлов) | Serena + Sequential |
| Research | Tavily + Context7 |

### Ключевой принцип: Optional Design

> "MCPs enhance, but never required"

Каждый MCP имеет нативный fallback. Деградация количественная, не качественная:
- Рефакторинг 15 файлов без Serena: 3x медленнее, то же качество
- Архитектурный дизайн без Sequential: те же секунды, 2x токенов
- Документация без Context7: 3x медленнее, менее курированный результат

Три режима fallback:
- `graceful` — попробовать MCP, тихо откатиться при ошибке
- `aggressive` — предпочитать нативные инструменты
- `disabled` — ошибка при недоступности MCP

### Синергии

```
Context7 (docs) → Sequential (анализ стратегии)
Serena (найти символы) → Morphllm (отредактировать паттерном)
Tavily (найти URL) → Playwright (извлечь контент)
Playwright (автоматизация) ↔ Chrome DevTools (анализ)
```

### Антипаттерны (документированы)

- НЕ использовать Serena для таск-менеджмента
- НЕ вызывать Sequential для простых задач
- НЕ путать Context7 с проектной документацией
- НЕ использовать Morphllm для символьных операций (это Serena)

---

## 5. Ролевые агенты (экспертные панели)

Самая необычная фича — симуляция конкретных реальных экспертов с характерными фразами, фреймворками и стилем анализа.

### Spec Panel — 10 экспертов по требованиям

Активация: `/sc:spec-panel`. Три режима: Discussion, Critique, Socratic.

| Эксперт | Домен | Характерная фраза |
|---------|-------|-------------------|
| **Karl Wiegers** | Requirements Engineering | "This requirement lacks measurable acceptance criteria. How would you validate compliance in production?" |
| **Gojko Adzic** | Specification by Example | "Can you provide concrete examples demonstrating this requirement in real-world scenarios?" |
| **Martin Fowler** | Software Architecture | "How does this design support evolutionary architecture?" |
| **Sam Newman** | Microservices | "What are the deployment boundaries?" |
| **Michael Nygard** | Production Stability | "How does this handle the failure modes?" |
| + 5 других | Various | Domain-specific probing questions |

### Business Panel — 9 бизнес-экспертов

Активация: `/sc:business-panel`. Три режима: Discussion, Debate, Socratic. Автоподбор экспертов по теме.

| Эксперт | Домен | Фреймворк | Voice Characteristics |
|---------|-------|-----------|----------------------|
| **Michael Porter** | Конкурентная стратегия | Five Forces, Value Chain | Аналитический, структурированный |
| **Clayton Christensen** | Инновации | Disruption Theory, Jobs-to-be-Done | Академический, нарративный |
| **Peter Drucker** | Менеджмент | MBO, Knowledge Worker | Прямой, практичный |
| **Seth Godin** | Маркетинг | Purple Cow, Permission Marketing | Провокационный, метафоричный |
| **Nassim Taleb** | Риски | Antifragility, Black Swan, Skin in the Game | Контрарианский, философский |
| **Jim Collins** | Организации | Good to Great, Flywheel, Level 5 Leadership | Исследовательский, data-driven |
| **Kim & Mauborgne** | Стратегия | Blue Ocean, Value Innovation, ERRC Grid | Визуальный, frameworks-heavy |
| **Donella Meadows** | Системы | Systems Thinking, Leverage Points | Целостный, экологический |
| **Jean-luc Doumont** | Коммуникация | Structured Communication, Tree Principle | Точный, минималистичный |

### YAML-спецификация эксперта (пример)

```yaml
porter:
  domain: "competitive_strategy"
  methodology: "five_forces_value_chain"
  voice_characteristics: "analytical, structured, industry-focused"
  key_questions:
    - "What are the five forces shaping this industry?"
    - "Where in the value chain does this create advantage?"
    - "How sustainable is this competitive position?"
  analysis_framework: "Industry Analysis → Competitive Position → Strategic Choice"
  critique_focus: "competitive_dynamics"

taleb:
  domain: "risk_uncertainty"
  methodology: "antifragility_black_swan"
  voice_characteristics: "contrarian, philosophical, probability-focused"
  key_questions:
    - "What's the downside exposure? Is it bounded or unbounded?"
    - "Does this gain from disorder or break under stress?"
    - "Where are the hidden fragilities in this model?"
  analysis_framework: "Fragility Assessment → Optionality → Skin in the Game"
  critique_focus: "hidden_risks"
```

### Три режима работы панели

**Discussion (по умолчанию):**
> Эксперты строят на выводах друг друга. Cross-Pollination: "Experts build upon and reference each other's insights"

**Debate:**
> Стресс-тест идей. "Structured disagreement and challenge." Эксперты спорят с цитированием доказательств

**Socratic Inquiry:**
> Вопросо-ориентированное исследование. "Each expert formulates probing questions from their framework"

### Автоподбор экспертов

Система автоматически выбирает 3-5 релевантных экспертов на основе:
- Ключевых слов в запросе
- Домена задачи (innovation → Christensen, risk → Taleb, strategy → Porter)
- Порога уверенности (если низкий → добавить Taleb для стресс-теста)

---

## 6. Скиллы (6 штук)

| Скилл | Файл | Строк | Суть |
|-------|------|-------|------|
| Confidence Check | SKILL.md + confidence.ts | ~170 + 333 | 5 проверок с весами, три порога (90/70/<70) |
| PM | SKILL.md | ~100 | PDCA-цикл, Confidence Check как обязательный шаг |
| Troubleshoot | SKILL.md | ~80 | 8 шагов: STOP→Observe→Hypothesize→Fix→Learn |
| Brainstorm | SKILL.md | ~60 | Сократический диалог, Options с Pros/Cons/Effort/Risk |
| Deep Research | SKILL.md | ~50 | Scope→Sources→Evidence→Synthesis→Citation |
| Token Efficiency | SKILL.md | 17 | Буллеты, аббревиатуры, символы, без преамбул |

---

## 7. Поведенческие флаги

| Флаг | Триггер | Эффект |
|------|---------|--------|
| `--think` | Ручной | ~4K токенов анализа |
| `--think-hard` | Ручной | ~10K токенов анализа |
| `--ultrathink` | Ручной | ~32K токенов, все MCP активны |
| `--brainstorm` / `--bs` | "maybe", "not sure" | Режим Brainstorming |
| `--research` | "investigate", "explore" | Режим Deep Research |
| `--uc` / `--ultracompressed` | context >75% | Режим Token Efficiency (30-50% экономия) |
| `--safe-mode` | Ручной | Максимальная валидация, консервативное выполнение |
| `--delegate` | >7 dirs / >50 files / complexity >0.8 | Делегирование суб-агентам |
| `--introspect` | Ошибки, сложные задачи | Режим Introspection с transparency markers |
| `--frontend-verify` | Ручной | Playwright + Chrome DevTools + Serena одновременно |

**Priority при конфликте:** Safety > Explicit > Depth > MCP Control
