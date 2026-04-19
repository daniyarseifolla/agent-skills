# Ландшафт инструментов: AI-агенты, оркестрация, скиллы, память

> Дата: 2026-04-10
> Метод: 8 параллельных Opus-агентов на веб-поиск

---

## 1. Экосистема Claude Code — плагины и скиллы

### Официальные ресурсы Anthropic

| Ресурс | Stars | Суть |
|--------|-------|------|
| [anthropics/skills](https://github.com/anthropics/skills) | ~22K | Официальный репо скиллов. Формат: папка с SKILL.md (YAML frontmatter + инструкции) |
| [anthropics/claude-code plugins](https://github.com/anthropics/claude-code/tree/main/plugins) | — | Официальная plugin-система (public beta). Бандлит slash commands, subagents, MCP, hooks |

### Крупнейшие коллекции

| Ресурс | Stars | Суть |
|--------|-------|------|
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | ~37K | Доминирующий хаб сообщества. Skills, hooks, commands, plugins |
| [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) | — | 135 агентов, 35 скиллов, 42 команды, 176+ плагинов, 20 hooks |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | ~5.2K | 220+ скиллов: engineering, marketing, product, compliance. Кросс-совместим с Codex, Gemini, Cursor |
| [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) | — | 340 плагинов + 1,367 скиллов. Есть CCPI package manager |

### Оркестрация-focused

| Ресурс | Суть |
|--------|------|
| [SuperClaude Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) (~20K stars) | 35 агентов, 30 скиллов, 14 команд, 6 режимов. Prompt-only framework |
| [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) | Multi-step workflow: task decomposition, parallel agents, plan mode. **Ближайший аналог нашего pipeline** |
| [athola/claude-night-market](https://github.com/athola/claude-night-market) | 19 production-ready плагинов: git workflows, code review, spec-driven dev |
| [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) (5.2K) | Полный reference: CLAUDE.md, .mcp.json, hooks, agents, GitHub Actions |

### Ключевой инсайт

> Экосистема взорвалась от 0 до 9,000+ плагинов за 5 месяцев. Но только ~50-100 считаются production-ready. Доминирующий паттерн — markdown-injection (.md файлы, формирующие поведение). **Наша адаптерная архитектура (Jira/GitLab/Slack swappable adapters с pipeline) — уникальный дифференциатор, не реплицированный ни в одном публичном фреймворке.**

---

## 2. AI Coding Agent Frameworks

### Лидеры

| Инструмент | Stars | Архитектура | Суть |
|-----------|-------|-------------|------|
| [OpenHands](https://github.com/All-Hands-AI/OpenHands) | ~69.5K | Multi-agent, web UI | Enterprise-ready. Браузерная IDE, sandbox, SWE-bench лидер |
| [Aider](https://github.com/paul-gauthier/aider) | ~30K+ | Single-agent, CLI | Pair programming в терминале. Auto-commits, GPT-4/Claude/Gemini |
| [SWE-agent](https://github.com/SWE-agent/SWE-agent) | ~18.8K | Single-agent, ACI | Princeton/Stanford. GitHub issue → автофикс. NeurIPS 2024 |
| [Devika](https://github.com/stitionai/devika) | ~18K+ | Pipeline (plan→research→code) | Open-source Devin. Встроенный браузер для ресёрча |
| [Sweep](https://docs.sweep.dev/) | ~7K+ | Single-agent, GitHub App | Issues → PRs автоматически |
| [AutoCodeRover](https://github.com/nus-apr/auto-code-rover) | ~5K+ | Single-agent, AST-based | LLM + program analysis на уровне AST |

### Новое

| Инструмент | Суть |
|-----------|------|
| [Composio Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator) | Plans → spawns parallel agents (каждый со своим worktree/branch/PR) → CI fixes → merge |
| MapCoder (research) | 4 агента в цикле: Recall → Plan → Generate → Debug |
| mini-swe-agent | 100 строк кода, 74%+ на SWE-bench verified |

### Тренды

- Multi-agent workflows выросли на **327%** за июнь-октябрь 2025 (Databricks)
- Рынок делится на **research** (SWE-agent, AutoCodeRover) и **production** (OpenHands, Composio)
- **Наш явный pipeline (planner→reviewer→coder→reviewer→deploy) — уникальный дизайн.** Большинство open-source инструментов используют single-agent loop, а не формализованные фазы

---

## 3. Multi-Agent Orchestration Frameworks

### Три парадигмы координации

| Парадигма | Фреймворк | Суть |
|-----------|-----------|------|
| **Graph-based** | LangGraph | Агенты = ноды в DAG с условными ветвлениями и чекпоинтами |
| **Role-based** | CrewAI (45.9K stars) | Каждый агент = роль (Researcher, Developer, Tester) с toolset |
| **Conversational** | AutoGen/Microsoft | Агенты общаются, делегируют, достигают консенсуса через диалог |

### Для software development

| Фреймворк | Суть | Production? |
|-----------|------|-------------|
| [MetaGPT](https://github.com/geekan/MetaGPT) | Waterfall: Product Manager → Architect → Engineer → QA | Experimental |
| [ChatDev](https://github.com/OpenBMB/ChatDev) | 7 ролей: CEO, CPO, CTO, Programmer, Reviewer, Tester, Designer | Research |
| [OpenAI Agents SDK](https://github.com/openai/openai-agents-python) | Handoff-based: агенты передают контроль явно | Production |
| [Google ADK](https://cloud.google.com/adk) | Model-agnostic, multi-language (Python, Java, Go, TS) | Production |
| [AgentScope](https://github.com/agentscope-ai/agentscope) (Alibaba) | MsgHub + pipeline abstractions, "Agent as API" | Growing |

### Swarm-паттерны

| Инструмент | Суть |
|-----------|------|
| Swarms (kyegomez) | Enterprise hierarchical director-worker |
| Agency Swarm (VRSEN) | Расширяет OpenAI Agents SDK для collaborative swarms |
| ClawTeam | Self-organizing с dynamic sub-agent spawning |
| Agent Swarm (desplega-ai) | Lead agent → Docker-containerized workers с DAG |

---

## 4. Prompt Engineering для агентов — Best Practices

### Доказанные техники

| Техника | Источник | Эффект |
|---------|---------|--------|
| **XML-теги** (`<instructions>`, `<context>`, `<thinking>`) | Anthropic docs | Claude обучен на XML — лучше парсинг и adherence |
| **Role-based system prompts** | arXiv 2601.13118 | Роль "security-aware developer" снижает vulnerable code на 47-56% |
| **Confidence Gating** (3 уровня) | Paxrel 2026 | High→auto-proceed, Medium→spot check, Low→human review. Снижает галлюцинации |
| **Chain of Verification** (самокритика) | arXiv 2502.06039 | RCI technique: GPT-4o исправляет 64.7% ошибок за 1 итерацию |
| **Sequential Pipeline** | Anthropic "Building Effective Agents" | Начни с цепочки → single agent + tools → multi-agent только при разных доменах |
| **Template + Policy Variables** | Databricks, OpenAI | Один гибкий промпт с переменными вместо N отдельных |
| **Explicit I/O Format** | arXiv 2601.13118 | 88% участников подтвердили полезность явной спецификации формата |

### Ключевые правила

> **"Named failure modes become detectable."** Назвать антипаттерн ("Confidence Mirage", "Phantom Verification") = сделать его ловимым. Безымянные ошибки повторяются бесконечно.

> **"Start with a deterministic chain, graduate to agents."** (Anthropic) Не начинай с multi-agent — начни с цепочки.

---

## 5. CLAUDE.md — Best Practices из сообщества

### Главные правила

| Правило | Источник |
|---------|---------|
| **< 200 строк** — длиннее = хуже adherence | HumanLayer Blog |
| **Hooks > prose rules** — линтинг/формат через settings.json, не через CLAUDE.md | HumanLayer |
| **Separate docs, not monolith** — task-specific инструкции в `agent_docs/` с one-line описаниями | HumanLayer |
| **`.claude/rules/` директория** — focused .md файлы с glob-frontmatter вместо одного файла | Official docs |
| **Pointers > snippets** — сниппеты устаревают, ссылки на файлы — нет | HumanLayer |
| **Three-layer scoping** — Global (`~/.claude/`), Project (`CLAUDE.md`), Local (`CLAUDE.local.md`) | Community |
| **`/init` для bootstrap** — сгенерировать стартер, потом 2 недели рефайнить | Community |

### Reference-архитектуры

| Ресурс | Суть |
|--------|------|
| [josix/awesome-claude-md](https://github.com/josix/awesome-claude-md) | Реальные CLAUDE.md из production OSS-проектов, фильтр по стеку |
| [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) (5.2K) | Полный конфиг: CLAUDE.md + .mcp.json + hooks + agents + GitHub Actions |
| [abhishekray07/claude-md-templates](https://github.com/abhishekray07/claude-md-templates) | Drop-in шаблоны для разных типов проектов |

---

## 6. AI Code Review — инструменты и архитектура

### Рынок

| Инструмент | Модель | Архитектура | Цена |
|-----------|--------|-------------|------|
| [CodeRabbit](https://www.coderabbit.ai/) | Multi-step pipeline | Sandbox → context map → 35+ linters → LLM line-by-line. LanceDB для past PRs | Free (rate-limited) / $24-30/dev/mo |
| [Qodo Merge / PR-Agent](https://github.com/qodo-ai/pr-agent) | Single LLM call per tool | Open-source. `/review`, `/improve`, `/analyze`, `/compliance`. ~30s | Free OSS / $19-30/user/mo |
| [Sourcery](https://sourcery.ai/) | Summary + line comments | GitHub/GitLab app. Учится из dismiss/accept. 200+ Python rules | Free (public) / $10-24/seat/mo |
| [Kodus AI](https://github.com/kodustech/kodus-ai) | Model-agnostic | Open-source, self-hosted, любой LLM | Free |

### Архитектурные паттерны code review

1. **Diff + Context Enrichment** — все обогащают diff окружающим кодом, AST, историей
2. **Hybrid Deterministic + AI** — linters для детерминированных проверок + LLM для семантических
3. **Single-call vs Multi-agent** — PR-Agent: 1 LLM call (быстро, дёшево). CodeRabbit: multi-step pipeline (глубже)
4. **Learning loops** — CodeRabbit/Sourcery учатся из accepted/dismissed комментариев
5. **85%+ precision target** — индустриальный консенсус перед rollout

### Что забрать для нашего pipeline-code-reviewer

- **Structured output** как у PR-Agent: summary + inline suggestions (не свободный текст)
- **Learning from dismissals** — если пользователь игнорирует замечание, не повторять
- **Hybrid подход** — запускать lint/type-check детерминированно, LLM только для семантики

---

## 7. Конкуренты — системы правил

### Сравнение

| Фича | Cursor | Windsurf | Copilot | Cline | Roo Code | Claude Code |
|------|--------|----------|---------|-------|----------|-------------|
| Формат | `.mdc` | Custom UI + файлы | `.md` + YAML | `.md`/`.txt` | `.md` + YAML modes | SKILL.md + YAML |
| Scoping | Glob в frontmatter | Global / Workspace | Path globs + Org | Path globs | Mode-slug dirs | `allowed-tools` |
| Условная активация | Auto/Manual/Always/Agent | Always/Manual/Model | applyTo globs | paths globs | Per-mode | Триггеры в description |
| Tool permissions | Нет | Нет | excludeAgent | Нет | **Да (per mode)** | `allowed-tools` |
| Enterprise | Нет | MDM policies | **Org instructions (GA)** | Нет | Нет | Нет |

### Уникальные находки

**Cursor .mdc:**
- 4 activation modes: Always, Auto (по glob), Manual (@-mention), Agent Requested
- Рекомендация < 500 строк на правило
- [awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules) — крупнейшая коллекция

**Roo Code Modes — самый интересный:**
- 5 built-in modes: Code, Architect (read-only!), Ask, Debug, Orchestrator
- Каждый mode = набор доступных tools + behavioral instructions + свой LLM model
- **Единственный инструмент, ограничивающий что AI МОЖЕТ ДЕЛАТЬ, а не только как писать**
- Custom modes экспортируются как YAML

**GitHub Copilot Org Instructions:**
- GA с апреля 2026
- Admins задают defaults для всех репо организации
- Работает в VS Code, JetBrains, Neovim, GitHub.com, Mobile, CLI

**Cline Memory Bank:**
- `.clinerules/` с toggle UI для вкл/выкл отдельных правил
- [Memory Bank pattern](https://github.com/nickbaumann98/cline_docs) — структурированное хранение контекста

---

## 8. Agent Memory & Learning

### Академические подходы

| Система | Суть | Результат |
|---------|------|-----------|
| **Reflexion** (arXiv 2303.11366) | Verbal reinforcement learning. Агент рефлексирует после ошибки, хранит в episodic buffer | 91% pass@1 на HumanEval (vs 80% GPT-4) |
| **REMEMBERER (RLEM)** | Tabular memory с Q-value scoring. Фильтрует low-quality experiences | +10% boost. Удаление плохих демонстраций ещё улучшает |
| **AgentRR** | Record full trace → summarize → replay для похожих задач | Предотвращает unrecoverable errors |
| **SICA** (Self-Improving) | Агент редактирует свой source code на основе benchmark | 17-53% gains на SWE-Bench |
| **ReasoningBank** (Google) | Traces → reusable reasoning strategies. Semantic retrieval | Self-evolution at test time |

### Production-фреймворки памяти

| Фреймворк | Суть | Open source |
|-----------|------|-------------|
| [Mem0](https://mem0.ai/) | Long-term memory, PostgreSQL consolidation. Sub-ms retrieval | Да |
| [Letta](https://www.letta.com/) | OS-inspired virtual context (swap in/out). Tiered memory | Да |
| [Zep](https://www.getzep.com/) | Graph-based fact extraction, conversation summarization | Да |

### Markdown-File Memory (CLAUDE.md pattern)

> "Self-generated in-context examples lifted performance from 73% to 89-93%."

Самый простой подход — append к markdown файлам. Используют: Claude Code, Cursor, Windsurf, Cline.

### Ключевой инсайт

> **Memory quality > quantity.** Хранение плохого опыта создаёт propagating error loops. Эффективные системы комбинируют: **curation** (фильтрация), **forgetting** (pruning low-utility), **structured retrieval** (семантический поиск, а не raw dumps).

---

## 9. Сводка: что релевантно для agent-skills

### Инструменты для глубокого изучения

| Приоритет | Инструмент | Почему |
|-----------|-----------|--------|
| **P0** | [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) | Ближайший аналог нашего pipeline |
| **P0** | [athola/claude-night-market](https://github.com/athola/claude-night-market) | 19 production-ready плагинов, quality over quantity |
| **P0** | [Qodo PR-Agent](https://github.com/qodo-ai/pr-agent) | Open-source code review с structured output |
| **P1** | [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) | Reference architecture для Claude Code конфигурации |
| **P1** | Roo Code modes | Уникальная идея: tool permissions per mode |
| **P1** | [Composio Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator) | Parallel agents с worktrees — похоже на наш community-sync |
| **P2** | Reflexion pattern | Формализованное обучение на ошибках |
| **P2** | [josix/awesome-claude-md](https://github.com/josix/awesome-claude-md) | Реальные production CLAUDE.md для изучения |

### Техники для внедрения

| Техника | Источник | Как применить |
|---------|---------|--------------|
| **Named failure modes** | Paxrel 2026 | Назвать антипаттерны в SKILL.md → они станут ловимыми |
| **Hooks > prose** | HumanLayer | Линтинг через settings.json hooks, не через текст в скиллах |
| **Hybrid review** (linters + LLM) | CodeRabbit/PR-Agent | pipeline-code-reviewer: запустить lint, потом LLM на семантику |
| **< 200 строк CLAUDE.md** | HumanLayer | Аудит наших SKILL.md на длину |
| **Conditional XML tags** | HumanLayer | `<important if="bug fix">` в SKILL.md для selective adherence |
| **Policy variables** | Databricks/OpenAI | Один base prompt + переменные (complexity, adapter) вместо N скиллов |
| **Tool permissions per phase** | Roo Code | pipeline-planner: Read-only. pipeline-coder: Read+Write. pipeline-reviewer: Read-only |

### Наши конкурентные преимущества

1. **Формализованный pipeline** (planner→reviewer→coder→reviewer→deploy) — уникален, большинство используют single-agent loop
2. **Swappable adapters** (Jira/GitLab/Figma/Slack) — не реплицировано ни в одном публичном фреймворке
3. **trigger-eval.json** — тестирование триггеров скиллов (нет аналогов)
4. **community-sync** (cherry-pick на N веток) — нет аналогов
