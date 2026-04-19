# Предложения к внедрению из SuperClaude

> Дата: 2026-04-10
> Контекст: agent-skills v3 pipeline (planner → reviewer → coder → reviewer → deploy)

---

## P0 — Высокий импакт, низкое усилие

### 1. Confidence Check перед имплементацией

**Что:** Добавить фазу предварительной оценки уверенности в `pipeline-coder` (или как отдельную фазу между planner и coder).

**Как в SuperClaude:** 5 проверок с весами (25%+25%+20%+15%+15%), три порога (≥90/70-89/<70).

**Адаптация для нас:**

Добавить секцию в `pipeline-coder/SKILL.md`:

```markdown
## Pre-Implementation Confidence Check

Before writing any code, verify:

1. **No duplicates** (25%) — Grep the codebase for similar implementations. Are you about to create something that already exists?
2. **Architecture fit** (25%) — Does the planned approach match the project's existing patterns? Check adapter contracts and tech-stack conventions.
3. **Docs verified** (20%) — Have you checked official documentation for the APIs/libraries you plan to use? Do NOT rely on training data.
4. **Root cause clear** (15%) — For bug fixes: is the root cause identified with evidence, not assumed?
5. **Acceptance criteria mapped** (15%) — Can you map each acceptance criterion to a specific code change?

### Decision:
- ≥90% → Proceed with implementation
- 70-89% → Report gaps to user, investigate before coding
- <70% → STOP. Ask user for clarification.

Cost: ~100-200 tokens. Savings: 5,000-50,000 tokens of wrong-direction work.
```

**Где:** `v3/pipeline-coder/SKILL.md` — новая секция перед "Implementation Protocol"

---

### 2. Anti-Pattern / Correct Pattern формат

**Что:** Добавить явные примеры "что нельзя" vs "что нужно" в ключевые скиллы.

**Для pipeline-coder:**

```markdown
## Anti-Patterns (strictly prohibited)

❌ "Got a build error. Let's just try again"
❌ "Retry: attempt 1... attempt 2... attempt 3..."
❌ "Tests are failing but the logic looks correct, shipping anyway"
❌ "I'll add a TODO for this edge case"
❌ "This probably works for most cases"

## Correct Patterns (required)

✅ "Got a build error. Reading the error message: [exact error]. Root cause: [analysis]"
✅ "Tests failing. Investigating: expected [X], got [Y]. The issue is in [file:line]"
✅ "Edge case identified. Implementing handler now, not deferring"
✅ "Verified via [test output / grep result / doc reference]"
```

**Для pipeline-code-reviewer:**

```markdown
## Anti-Patterns (strictly prohibited)

❌ "The code looks good overall" (without specific evidence)
❌ "LGTM" (without checking tests, security, performance)
❌ "Minor style issues but otherwise fine" (ignoring logic bugs)

## Correct Patterns (required)

✅ "Verified: [specific test] passes with [output]"
✅ "Security check: [input validation present at line X]"
✅ "Performance: [no N+1 queries, verified via grep for DB calls]"
```

**Где:** `v3/pipeline-coder/SKILL.md`, `v3/pipeline-code-reviewer/SKILL.md`

---

### 3. Will / Will Not Boundaries

**Что:** Добавить чёткые границы ответственности в каждый pipeline-скилл.

**pipeline-planner:**
```markdown
## Boundaries
### Will
- Research codebase structure and patterns
- Create implementation plan with phases
- Identify risks and dependencies
- Estimate complexity

### Will Not
- Write implementation code
- Run tests or builds
- Make git commits
- Modify any files in the project
```

**pipeline-coder:**
```markdown
## Boundaries
### Will
- Implement code changes according to the plan
- Write/update tests for new code
- Run tests to verify implementation
- Follow adapter conventions

### Will Not
- Change the plan or scope
- Skip tests "to save time"
- Create new architectural patterns not in the plan
- Deploy or push code
```

**pipeline-code-reviewer:**
```markdown
## Boundaries
### Will
- Review code changes against the plan
- Check for security vulnerabilities
- Verify test coverage
- Report issues with evidence

### Will Not
- Fix code directly (report issues, let coder fix)
- Approve without running verification
- Expand scope beyond what was planned
- Skip security or performance checks
```

**Где:** Каждый `v3/pipeline-*/SKILL.md`

---

### 4. Evidence-Based Communication

**Что:** Запретить утверждения без доказательств в выводе pipeline-фаз.

```markdown
## Evidence Requirement

Every claim in your output MUST be backed by concrete evidence:

❌ "The integration is complete and working correctly"
✅ "Integration complete. Test results: 3/3 passed. Output: [actual test output]"

❌ "No security issues found"
✅ "Security check: no raw SQL (grep: 0 matches), input validation present (file:line), no secrets in code (grep: 0 matches for API_KEY/SECRET/PASSWORD)"

❌ "Performance should be fine"
✅ "Performance: single DB query per request (verified: grep for repository calls in handler), no N+1 pattern detected"
```

**Где:** `v3/pipeline-code-reviewer/SKILL.md`, `v3/pipeline-ui-reviewer/SKILL.md`

---

## P1 — Высокий импакт, среднее усилие

### 5. Глобальный RULES.md

**Что:** Вынести общие правила из скиллов в один файл. Скиллы ссылаются на него, не дублируют.

**Содержание:**

```markdown
# Global Rules (v3)

## Priority Levels
- **CRITICAL** — never compromise (security, data safety, production)
- **IMPORTANT** — strongly prefer (quality, maintainability)
- **RECOMMENDED** — apply when practical (optimization, style)

## CRITICAL Rules

### No Partial Features
If you start implementing, you MUST complete to working state.
No TODOs for core functionality.

### Evidence Over Assertions
Every technical claim must be verifiable. Show test output, grep results, or doc references.
Never say "should work" or "probably fine".

### Scope Discipline
Build ONLY what's asked. No extra features, no speculative abstractions.
Conflict resolution: Safety > Scope > Quality > Speed.

### No Sycophantic Behavior
No "Great question!", no "Excellent approach!", no marketing language.
Professional, direct feedback only.

## IMPORTANT Rules

### Anti-Retry
Never retry the same approach without understanding WHY it failed.
Read the error. Check assumptions. Try a focused fix.

### Temporal Awareness
Never assume dates. Check current date context. Never default to knowledge cutoff.

## RECOMMENDED Rules

### Token Efficiency
- Bullets over paragraphs for internal handoffs
- Abbreviations OK in handoff artifacts (fn, impl, cfg)
- Skip preambles and greetings in pipeline output
```

**Где:** Новый файл `v3/RULES.md`, ссылки из каждого SKILL.md

---

### 6. Complexity-Based Phase Skipping

**Что:** Расширить complexity routing в `core-orchestration` — пропускать дорогие фазы для простых задач.

**Текущее состояние:** У нас есть S/M/L complexity hints, но все задачи проходят полный pipeline.

**Предложение:**

```markdown
## Complexity Routing

### S (Simple) — MINIMAL pipeline
Skip: impact-analysis, plan-review, ui-review
Pipeline: planner(light) → coder → code-review(light)
Criteria: 1-3 файла, один компонент, нет новых зависимостей

### M (Medium) — STANDARD pipeline  
Skip: plan-review (если planner confident ≥90%)
Pipeline: impact → planner → coder → code-review → ui-review(optional)
Criteria: 4-10 файлов, 2-3 компонента

### L (Large) — FULL pipeline
Skip: nothing
Pipeline: impact → planner → plan-review → coder → code-review → ui-review
Criteria: 10+ файлов, кросс-модульные изменения, новые зависимости
```

**Где:** `v3/core-orchestration/SKILL.md`

---

### 7. Resource Zones в core-orchestration

**Что:** Добавить автоматическое управление объёмом вывода при приближении к лимиту контекста.

```markdown
## Context Management

### Green Zone (context < 75%)
Full output. Detailed explanations. Complete code blocks.

### Yellow Zone (context 75-85%)
Reduce verbosity. Bullet points only. Skip explanations for obvious changes.
Activate token-efficient handoff format between phases.

### Red Zone (context > 85%)
Essential operations only. Minimal output.
Skip optional phases (ui-review, plan-review).
If in coder phase — complete current file, then checkpoint.
```

**Где:** `v3/core-orchestration/SKILL.md`

---

## P2 — Средний импакт, среднее усилие

### 8. Token-Efficient Handoff Format

**Что:** Формализовать компактный формат передачи данных между фазами pipeline.

**Текущее:** Handoff-контракты описаны текстом, каждая фаза выдаёт свободный формат.

**Предложение:**

```markdown
## Handoff Format (planner → coder)

```yaml
complexity: S|M|L
confidence: 0.0-1.0
files:
  - path: src/app/feature/component.ts
    action: create|modify|delete
    changes: "brief description"
phases:
  - name: "Phase 1: Data layer"
    files: [list]
    deps: [list of phase names]
risks:
  - "risk description"
decisions:
  - "decision + rationale"
```

## Handoff Format (coder → reviewer)

```yaml
files_changed:
  - path: src/app/feature/component.ts
    lines_added: N
    lines_removed: N
tests:
  - path: src/app/feature/component.spec.ts
    status: pass|fail|skip
    output: "brief"
plan_adherence: full|partial|deviated
deviations:
  - "what changed from plan and why"
```
```

**Где:** Новый файл `v3/handoff-schemas.md` или секции в каждом SKILL.md

---

### 9. Four-Question Verification

**Что:** Добавить в `pipeline-code-reviewer` обязательную четырёхвопросную валидацию.

```markdown
## Mandatory Verification (answer ALL four)

1. **Tests passing?** — Run tests. Paste actual output. "Tests should pass" is NOT acceptable.
2. **Requirements met?** — Map each acceptance criterion to specific code change. Itemize.
3. **Assumptions verified?** — List every assumption made during implementation. For each: verified (how?) or unverified (risk?).
4. **Evidence present?** — For each claim in your review: what concrete evidence supports it? (test output, grep result, doc link)
```

**Где:** `v3/pipeline-code-reviewer/SKILL.md`

---

### 10. Post-Task Reflection (lightweight)

**Что:** Добавить опциональную фазу рефлексии после завершения pipeline.

Не полный PM Agent (который overengineered), а простой чеклист:

```markdown
## Post-Completion Reflection (optional, for M/L tasks)

After pipeline completes, briefly note:
- What worked well? (approach, tool choice, pattern)
- What was unexpected? (error, wrong assumption, scope change)
- What would you do differently? (for similar tasks in future)

Save only if insight is non-obvious and applicable to future tasks.
Format: 2-3 sentences max. No essay.
```

**Где:** `v3/core-orchestration/SKILL.md` — в конце pipeline

---

## P3 — Низкий приоритет / на будущее

### 11. Behavioral Flags (--think levels)

**Идея:** Три уровня глубины анализа, управляемые флагами.

**Пока не внедрять** — наш pipeline уже управляет глубиной через complexity hints. Но идея автоматического переключения по сложности задачи заслуживает внимания.

### 12. Wave → Checkpoint → Wave

**Идея:** Параллельное выполнение независимых фаз.

**Пока не внедрять** — требует существенных изменений в core-orchestration. SuperClaude сами обнаружили, что Python GIL делает это бесполезным — только Task Tool даёт реальный параллелизм.

### 13. Mistake Journal

**Идея:** Автоматический журнал ошибок в формате JSONL.

**Пока не внедрять** — у SuperClaude это не взлетело (пустые поля, дубликаты). Если внедрять — нужен механизм принудительного заполнения всех полей + дедупликация.

---

## Сводная таблица

| # | Практика | Приоритет | Усилие | Файлы |
|---|----------|-----------|--------|-------|
| 1 | Confidence Check | P0 | Низкое | pipeline-coder/SKILL.md |
| 2 | Anti-Pattern format | P0 | Низкое | pipeline-coder, pipeline-code-reviewer |
| 3 | Will/Will Not boundaries | P0 | Низкое | Все pipeline-*/SKILL.md |
| 4 | Evidence-based communication | P0 | Низкое | pipeline-code-reviewer, pipeline-ui-reviewer |
| 5 | Глобальный RULES.md | P1 | Среднее | Новый v3/RULES.md |
| 6 | Complexity-based skip rules | P1 | Среднее | core-orchestration/SKILL.md |
| 7 | Resource zones | P1 | Среднее | core-orchestration/SKILL.md |
| 8 | Token-efficient handoff | P2 | Среднее | handoff-schemas.md или SKILL.md |
| 9 | Four-question verification | P2 | Низкое | pipeline-code-reviewer/SKILL.md |
| 10 | Post-task reflection | P2 | Низкое | core-orchestration/SKILL.md |
| 11 | Behavioral flags | P3 | Высокое | — |
| 12 | Wave/Checkpoint | P3 | Высокое | — |
| 13 | Mistake journal | P3 | Среднее | — |
