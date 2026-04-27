# claude-mem — Полное исследование

> Дата: 2026-04-27
> Источник: https://github.com/thedotmack/claude-mem
> Версия: v12.4.7 (последний релиз 26 апреля 2026)
> Метод: 4 параллельных Explore-агента, WebFetch GitHub API + raw README + структуры файлов
> Автор: Alex Newman (`@thedotmack`)
> Лицензия: AGPL-3.0 (часть директорий — PolyForm Noncommercial 1.0.0)

---

## 1. Обзор проекта

claude-mem — TypeScript-плагин для Claude Code, который автоматически захватывает, сжимает и переиспользует контекст между сессиями. В отличие от встроенной auto-memory Claude Code (статические markdown-заметки), claude-mem работает как фоновый сервис с собственной БД и AI-саммаризацией.

**Назначение:** преодолеть «забывчивость» Claude Code между сессиями — каждая новая беседа стартует без памяти о предыдущих действиях. claude-mem решает это через автоматическую индексацию всех событий через hooks и послойную выдачу контекста при запросах.

**Не путать с встроенной memory Claude Code** — это два разных слоя:
- Встроенная: ручная запись Claude'ом в `~/.claude/projects/.../memory/MEMORY.md`
- claude-mem: автоматический захват в SQLite + Chroma vector DB

---

## 2. Архитектура

### 2.1 Компоненты

```
claude-mem/
├── Worker Service          # фоновый оркестратор на :37777
├── SQLite                  # observations, sessions, summaries
├── Chroma Vector DB        # embeddings для семантического поиска
├── MCP Server (stdio)      # 15+ tools для Claude Code
├── Web UI                  # http://localhost:37777
└── Hooks                   # 5-6 lifecycle hooks
```

### 2.2 Структура SQLite

| Таблица | Назначение |
|---|---|
| `sdk_sessions` | метаданные сессии (статус, проект, таймстемпы) |
| `observations` | структурированные «воспоминания» (decision/bugfix/feature), JSON-деревья фактов и концепций, дедуп по `UNIQUE(memory_session_id, content_hash)` |
| `session_summaries` | LLM-саммаризации: что запрошено, что изучено, что завершено |
| `pending_messages` | очередь обработки SDK-сообщений с self-healing через worker PID |
| `user_prompts` | история промптов для поиска и UI |

### 2.3 Hooks интеграция

6 lifecycle hooks через `plugin/hooks/hooks.json`:

| Hook | Действие |
|---|---|
| `SessionStart` | инициализация worker'а, окружение |
| `UserPromptSubmit` | старт обработки при вводе пользователя |
| `PreToolUse` (Read) | захват контекста файлов перед чтением |
| `PostToolUse` | генерация observations после tool calls |
| `Stop` | LLM-саммаризация сессии при остановке |
| `SessionEnd` | финализация |

Все hooks выполняются через bash с таймаутом 60–120 сек, бутстрап через bun-runner.

### 2.4 MCP tools (15+)

**Поиск и память (послойная выдача):**
- `search` — компактный индекс с ID (~50–100 ток)
- `timeline` — хронологический контекст вокруг найденных результатов
- `get_observations` — полные детали по отфильтрованным ID (~500–1000 ток)

**Knowledge Agents (v12.1.0+):**
- `build_corpus` — компиляция «мозга» из набора observations
- `prime_corpus` — инициализация AI-сессии с корпусом
- `query_corpus` — многоходовой диалог поверх корпуса

**AST-анализ кода (tree-sitter):**
- `smart_search` — поиск символов/функций
- `smart_outline` — структура файла со свёрнутыми символами

### 2.5 LLM-цепочка

- **Claude SDK** — основной агент саммаризации
- **Gemini, OpenRouter** — fallback при обрыве SDK-сессии
- Knowledge Agents — компилируемые «мозги» из истории observations с многоходовым диалогом

---

## 3. Установка и использование

### 3.1 Требования

- Node.js ≥ 20.0.0 (Bun ≥ 1.0.0 автоустанавливается)
- Claude Code с поддержкой плагинов
- Python через `uv` (автоустановка)
- SQLite 3 (встроена в пакет)

### 3.2 Установка

```bash
npx claude-mem install
# или через marketplace
/plugin marketplace add thedotmack/claude-mem
```

Альтернативные IDE:
```bash
npx claude-mem install --ide gemini-cli
npx claude-mem install --ide opencode
```

### 3.3 Конфигурация

Создаётся в `~/.claude-mem/settings.json`:
- `CLAUDE_MEM_MODE` — язык/режим (`code`, `code--ja`, `code--zh`)
- `worker_port` — HTTP API (по умолчанию 37777)
- `data_directory` — где SQLite + Chroma
- `model` — AI-модель для саммаризации

### 3.4 Использование

Память работает прозрачно через hooks. Запросы на чтение — через 3 MCP-инструмента (search → timeline → get_observations). Web UI на `:37777` для просмотра в реальном времени.

**Приватность:** оборачивай чувствительное в `<private>`-теги:
```xml
<private>API_KEY=secret_value</private>
```

⚠️ **Известный баг:** privacy-теги не всегда удаляются перед отправкой содержимого в LLM-саммаризатор (см. раздел 5).

### 3.5 Скрипты разработчика

```bash
npm run build           # компиляция и синхронизация
npm run dev             # dev-режим
npm run worker:restart  # перезапуск memory-сервиса
npm run test            # тесты
```

---

## 4. Особенности и фичи

### 4.1 Послойный поиск (token-aware)

Трёхслойная выдача даёт ~10× экономию токенов на больших историях:
1. `search` — индекс (компактно)
2. `timeline` — контекст вокруг
3. `get_observations` — полные детали только для нужных ID

### 4.2 Mode inheritance

`ModeManager.ts` поддерживает наследование режимов: `code` → `code--ko`. Дочерние режимы переопределяют параметры родителя — удобно для разных проектов/языков.

### 4.3 Worktree adoption

Автоматическое слияние observations при мерже git-веток — предотвращает дублирование при перемещении кода между ветками.

### 4.4 Гибридный поиск

Chroma (semantic embeddings) + SQLite FTS5 (полнотекстовый) — комбинация даёт релевантность по смыслу + точный keyword-match.

### 4.5 Self-healing очередь

Worker PID + `UNIQUE`-индекс автоматически восстанавливают зависшие задачи. Graceful shutdown по сигналам, fail-open для немедленного приёма HTTP-запросов.

### 4.6 Многоязычность

39+ языков через ISO 639-1 коды (через mode inheritance: `code--ja`, `code--zh`, `code--ko` и т.д.).

### 4.7 Интеграции

Telegram, Discord, Slack — real-time лента observations во внешние каналы.

---

## 5. Зрелость и риски

### 5.1 Активность

- v12.4.7 (релиз 2026-04-26 — за день до этого исследования)
- Десятки релизов, частые патчи
- Стартовал август 2025 (~8 месяцев в продакшене)
- 823 закрытых PR — все от автора, 2 открытых (тоже автор)
- 15 открытых issues
- Bus factor = 1 (контрибьютов снаружи нет)

### 5.2 Звёзды

Один из агентов сообщил **68K звёзд** за 8 месяцев. Цифра подозрительно высокая для нишевого тулинга — требует ручной проверки на странице репо. Возможно, опечатка агента (6.8K выглядит правдоподобнее) или искажение данных WebFetch. На решение не влияет — популярность ≠ стабильность.

### 5.3 Красные флаги

| Проблема | Серьёзность | Описание |
|---|---|---|
| Worker зависает | Высокая | Регулярно не генерирует observations, ломается миграция БД — рушит ядро функциональности |
| Утечка `<private>` | Критическая | Содержимое privacy-тегов доходит до LLM-саммаризатора. Реальный риск для NDA-кода |
| ChromaSearch ранжирует по дате | Высокая | Поиск отдаёт свежее вместо релевантного — нарушает основу контекстного поиска |
| Конфликты Zod / tree-sitter | Средняя | `undefined is not an object` при выполнении hooks |
| Windows-несовместимость | Средняя | Пустые CMD-окна, проблемы PowerShell encoding, конфликты с Gemini CLI |
| Bus factor = 1 | Долгосрочная | Один автор, нет внешних мейнтейнеров |

### 5.4 Безопасность

- Worker слушает `localhost:37777` — нужно проверять, что не торчит наружу
- Запись в `~/.claude-mem/` — SQLite-файлы могут содержать privacy-leak'и из п.5.3
- AGPL-3.0 — если форкаешь и публикуешь, обязан открыть исходники
- Аудит безопасности отсутствует

---

## 6. Сравнение со встроенной memory Claude Code

| Параметр | Встроенная memory | claude-mem |
|---|---|---|
| Захват | Ручной (Claude решает что писать) | Автоматический (5-6 hooks ловят всё) |
| Хранилище | Markdown в `~/.claude/projects/.../memory/` | SQLite + Chroma vector DB |
| Поиск | Линейное чтение `MEMORY.md` | Послойный гибрид (semantic + FTS5) |
| Кросс-проектность | Per-project | Сквозная между проектами |
| Стоимость токенов | Весь индекс грузится в контекст | Послойная выдача (~10× экономия) |
| AI-обработка | Нет | LLM-саммаризация сессий |
| Зрелость | Стабильна (часть Claude Code) | Бета, критические баги |
| Контроль | Полный (ты пишешь) | Опосредованный (Claude+LLM решают) |

---

## 7. Метаданные исследования

**Агенты, отправленные параллельно:**
1. Overview — что это, философия, активность
2. Install — пошаговая установка, компоненты, требования
3. Technical architecture — SQLite/Chroma/MCP/hooks
4. Issues and quality — зрелость, риски, красные флаги

**Источники:**
- https://github.com/thedotmack/claude-mem
- https://raw.githubusercontent.com/thedotmack/claude-mem/main/README.md
- https://api.github.com/repos/thedotmack/claude-mem
- Issues, PRs, releases страницы
- docs.claude-mem.ai (упомянут в README)

**Не проверено вручную:**
- Точное число звёзд (агент сообщил 68K, выглядит подозрительно)
- Содержимое issues по конкретным багам worker'а
- Реальный масштаб privacy-leak — насколько часто срабатывает
