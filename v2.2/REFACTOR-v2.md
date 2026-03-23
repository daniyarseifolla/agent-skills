# v2.2 Refactor Plan v2

Результаты consensus-review (9 агентов, 2026-03-23). Фокус: интеграция, standalone, качество для 9+.

## ПАТТЕРНЫ (применить ко всему pipeline)

### P-A: Consensus Pattern (x3 агента)

Применять НЕ ТОЛЬКО к review, а ко ВСЕМ фазам где качество критично:

```yaml
consensus_usage:
  planning:
    Phase_1: "3 агента планируют с разных углов → consensus план"
    angles: [minimal_approach, comprehensive_approach, risk_focused]

  implementation:
    Phase_3: "3 агента ревьюят каждый part после реализации → consensus quality"
    angles: [correctness, figma_fidelity, code_patterns]

  code_review:
    Phase_4: "3 агента ревьюят diff → consensus findings"
    angles: [bugs_and_logic, architecture_and_security, quality_and_readability]

  ui_review:
    Phase_5: "3 агента тестируют UI → consensus report"
    angles: [functional_happy_path, edge_cases_and_responsive, visual_fidelity_and_states]

  analysis:
    /scan-practices: "3 агента сканируют проект → consensus practices"
    /scan-qa: "3 агента собирают QA данные → consensus playbook"
    /attach: "3 агента оценивают состояние → consensus state detection"

  statistics:
    metrics: "3 агента собирают разные метрики → consensus report"

  condition: "complexity >= M (для S — один агент достаточно)"
```

### P-B: Промежуточные файлы (агенты общаются через файлы, не через context)

```yaml
intermediate_files:
  pattern: |
    Каждый агент пишет результат в отдельный файл.
    Orchestrator читает все файлы, строит consensus.
    Cleanup удаляет промежуточные файлы, оставляет только итог.

  structure:
    docs/plans/{task-key}/.tmp/
      agent-1-{section}-{angle}.md    ← агент 1
      agent-2-{section}-{angle}.md    ← агент 2
      agent-3-{section}-{angle}.md    ← агент 3
      consensus-{section}.md          ← orchestrator мержит

  lifecycle:
    phase_start: "mkdir -p docs/plans/{task-key}/.tmp/"
    agent_writes: "Each agent → docs/plans/{task-key}/.tmp/agent-{N}-{name}.md"
    aggregate: "Orchestrator reads all .tmp/*.md → builds consensus"
    promote: "Move consensus files from .tmp/ to parent dir"
    cleanup: "rm -rf docs/plans/{task-key}/.tmp/"

  benefits:
    - "Агенты не загружают чужие результаты в свой context"
    - "Orchestrator видит все результаты одновременно при aggregation"
    - "Cleanup — чистый финальный результат без промежуточного мусора"
    - "Debuggable — если что-то пошло не так, .tmp/ ещё не удалён"

  cleanup_rule: |
    Cleanup НЕ происходит автоматически.
    Происходит ТОЛЬКО после того как orchestrator подтвердил consensus.
    Если pipeline прервался — .tmp/ остаётся для recovery.
    /cleanup command удаляет .tmp/ вместе с остальными артефактами.
```

### P-C: Сообщать о проблеме вместо fallback

```yaml
skill_unavailable:
  rule: "Если внешний скилл не загрузился — сообщить юзеру, НЕ пытаться заменить"
  format: |
    WARN: Skill {name} unavailable.
    This phase requires it for: {purpose}.
    Options:
    1. Install: npx skills add {source}
    2. Skip this step (reduced quality)
    3. Abort phase
  applies_to:
    - brainstorming
    - qa-test-planner
    - ui-ux-pro-max
    - visual-qa
    - refactoring-ui
    - css-styling-expert
    - agent-browser
    - superpowers:dispatching-parallel-agents
```

---

## P1: Handoff контракты (CRITICAL)

- [x] **1. Добавить worker_to_planner контракт** — fields: task, complexity, route, tech_stack_adapter, design_adapter, figma_urls, ui_inventory_path
- [x] **2. Добавить worker_to_ui_reviewer контракт** — fields: branch, figma_urls, app_url, credentials, design_adapter, tech_stack_adapter, ui_inventory_path
- [x] **3. Добавить evaluate_return контракт** — fields: plan_issues[], suggestions[], blocked_parts[]
- [x] **4. Добавить ui_reviewer_to_completion контракт** — fields: verdict (PASS/PASS_WITH_ISSUES/ISSUES_FOUND), score, breakdown, blockers
- [x] **5. credentials: добавить в return block jira-адаптера + в checkpoint schema**
- [x] **6. app_url: спрашивать в Phase 0.5, хранить в checkpoint**
- [x] **7. evaluate_return: добавить счётчик (max 2) + REJECTED → halt сразу**

## P2: Standalone (CRITICAL)

- [x] **8. Skill unavailable → WARN, не fallback** — pattern P-C выше, применить ко всем standalone скиллам
- [x] **9. Detached HEAD fallback** — git log → parse task key → спросить юзера. В code-reviewer, ui-reviewer, /cr, /verify-figma
- [x] **10. Figma MCP preflight** — проверка доступности перед вызовом. В adapter-figma section 0
- [x] **11. Standalone output path fallback** — `docs/plans/standalone-{branch-name}/` если task-key не определяется
- [x] **12. /attach: обрабатывать blocking verdicts** — если review вернул CHANGES_REQUESTED → показать юзеру, не игнорировать
- [x] **13. /attach: checkpoint как SET фаз** — `completed_phases: [0, 1, 3]` вместо watermark `phase_completed: 3`

## P3: Pipeline-coder → 9.0 (HIGH)

- [ ] **14. Inline все "Per X, see Y"** — 5 ссылок на core-orchestration → вставить 3-5 строк каждую
- [ ] **15. Failure triage decision trees** — "fix issues, retry" → конкретные шаги attempt_1/attempt_2/attempt_3
- [ ] **16. Свернуть section 8 до 3 строк** — убрать дублирование step references
- [ ] **17. Убрать section 7 (Superpowers)** — перенести routing decision в section 3

## P4: Figma-coding-rules → 9.0 (HIGH)

- [ ] **18. Перенумеровать 8,8b,8c,8d,8e → 1,2,3,4,5**
- [ ] **19. Section 5 (UI rules): группировать по severity** — BLOCKER tier / MAJOR tier / MINOR tier
- [ ] **20. Убрать дублирование CSS properties** — определить один раз, ссылаться из section 2 и ui-reviewer
- [ ] **21. Section 3 quality check: decision tree для score < 8** — что конкретно делать с каждым типом проблемы

## P5: UI-reviewer → 9.0 (HIGH)

- [ ] **22. Добавить бюджеты** — per_agent: 40 calls / 8 min, total phase: 30 min, on_timeout: stop + aggregate partial
- [ ] **23. Вынести шаблоны в templates/** — test-plan-template.md, visual-check-properties.yaml, required-states.yaml. SKILL.md с ~368 до ~272 строк
- [ ] **24. Structured verdict** — PASS / PASS_WITH_ISSUES / ISSUES_FOUND + score 0-100 + breakdown
- [ ] **25. Объединить brainstorming + qa-test-planner в один шаг** — qa-test-planner уже генерирует сценарии, brainstorming избыточен
- [ ] **26. Degraded standalone mode** — no_figma: functional-only, no_browser: visual-only, no_dev_server: ask + abort

## P6: Core-metrics → 9.0 (HIGH)

- [ ] **27. Validation rules** — required fields, enum values, value ranges, on_invalid: WARN + partial write
- [ ] **28. Phase ID mapping** — нормализовать 0-7 (0=analysis, 1=workspace, 2=plan, 3=plan-review, 4=code, 5=code-review, 6=ui-review, 7=completion)
- [ ] **29. Duration collection HOW** — checkpoint timestamps diff, fallback: null
- [ ] **30. Убрать "Future" aggregation** — заменить на 2-line note
- [ ] **31. Error handling** — source missing/malformed → WARN + null, never crash Phase 6
- [ ] **32. Consumer docs** — кто читает: worker completion, /progress, re-routing

## P7: Кросс-скиллы (MEDIUM)

- [ ] **33. Унифицировать severity** — consensus-review: CRITICAL/HIGH → BLOCKER/MAJOR/MINOR/NIT
- [ ] **34. Исправить ссылку figma-adapter** — "pipeline-coder section 8d" → "figma-coding-rules section 4"
- [ ] **35. Coder section 3 ссылки** — "section 8" → "figma-coding-rules section 1"
- [ ] **36. Phase 4+5 checkpoint** — CHANGES_REQUESTED → phase_completed:3 + iteration++. APPROVED → phase_completed:6

## P8: Consensus pattern integration (MEDIUM)

- [ ] **37. Обновить consensus-review** — max_total: 9 → sequential sections (3×3, max 3 parallel)
- [ ] **38. Добавить intermediate files protocol** — .tmp/ lifecycle в consensus-review skill
- [ ] **39. Интегрировать consensus в worker** — Phase 2/4/5 используют consensus при complexity >= M
- [ ] **40. Интегрировать consensus в /attach** — 3 агента оценивают state → consensus detection
- [ ] **41. Интегрировать consensus в scan-*** — /scan-practices, /scan-qa используют 3 агента

## Notes

- Паттерн P-C (WARN вместо fallback) решает проблему 5 external skills в ui-reviewer
- Паттерн P-B (intermediate files) решает проблему context overflow при 9 агентах
- Паттерн P-A (consensus везде) поднимает качество ВСЕХ фаз, не только review
- Phase ID нормализация (P6 #28) требует обновления worker — одноразовая миграция
- Общий объём: ~335 строк по ~12 файлам
- Ожидаемый результат: 8.5-9.0 средний балл
