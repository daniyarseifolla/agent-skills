# Deep Task Analysis — Phase 0.7

**Date:** 2026-03-25
**Status:** Approved
**Author:** Danny + Claude consensus

## Problem

Planner receives raw AC + Figma URLs. Doesn't explore all screens/states, doesn't check if backend API exists, doesn't build functional flows. Result: incomplete plans, missed states, broken endpoints discovered late in Phase 3.

## Solution

New **Phase 0.7: Deep Task Analysis** with 3 consensus agents. Runs after workspace setup, before planner. Output: `task-analysis.md` — enriched context for planner.

## Phase 0.7: Deep Task Analysis

### 2 Parallel Agents + 1 Sequential Synthesis Agent

```yaml
dispatch_pattern:
  step_1: "Orchestrator launches Agent 1 + Agent 2 in parallel"
  step_2: "Orchestrator waits for both to complete"
  step_3: "Orchestrator checks verdicts: both SUCCESS or PARTIAL → proceed. Any FAILED → handle"
  step_4: "Orchestrator passes Agent 1 + Agent 2 output paths to Agent 3 (not direct file read)"
  step_5: "Agent 3 completes → orchestrator aggregates"
  iron_law_3: "Agent 3 receives file paths via orchestrator input, NOT by convention"

  on_both_failed: "HALT — show error to user. Figma unreachable AND Swagger unreachable. Cannot analyze."
  on_one_failed: "Proceed with partial data. Agent 3 works with what's available. WARN user."

verdict_protocol:
  rule: "Every agent MUST end output with verdict line"
  format: "## Verdict: SUCCESS | PARTIAL | FAILED"
  SUCCESS: "All data collected as expected"
  PARTIAL: "Some data missing but enough to proceed (e.g., Figma found screens but some states inaccessible)"
  FAILED: "Could not collect any useful data (e.g., Swagger 401, Figma MCP down)"

skip_condition: "complexity == S → skip Phase 0.7 (overhead exceeds benefit for 1-2 AC tasks)"
```

#### Agent 1 — Figma Explorer (opus)

```yaml
figma_explorer:
  model: opus
  purpose: "Discover ALL screens, states, and flows in Figma"
  tools: [get_design_context, get_screenshot, get_metadata]

  steps:
    1: "get_metadata(fileKey) → list all pages/frames in file"
    2: "For each frame that matches task entity (by name/proximity to nodeId):"
    3: "  get_design_context → extract components, CSS, structure"
    4: "  get_screenshot → save to docs/plans/{task-key}/screenshots/"
    5: "Identify screen types: list, create, edit, detail, delete confirmation"
    6: "Identify states per screen: default, empty, loading, error, validation, success"
    7: "Identify flows: which screen leads to which (button labels, navigation hints)"
    8: "Identify interactive components: forms, buttons, dropdowns, modals, tables"

  output: "docs/plans/{task-key}/.tmp/figma-screens.md"
  format: |
    ## Figma Screens

    | # | Screen | Frame | node-id | Type | States Found |
    |---|--------|-------|---------|------|-------------|
    | 1 | News List | NewsListPage | 100:200 | list | default, empty, loading |
    | 2 | News Create | NewsDialog | 100:201 | dialog | default, validation-error |
    | 3 | News Edit | NewsDialog (edit) | 100:202 | dialog | default, prefilled |
    | 4 | Delete Confirm | ConfirmModal | 100:203 | modal | default |

    ## Flows
    - List → [Add button] → Create Dialog
    - List → [Row click] → Edit Dialog
    - List → [Delete icon] → Confirm Modal → List (item removed)

    ## States Detail
    | Screen | State | node-id | Screenshot |
    |--------|-------|---------|------------|
    | News List | empty | 100:204 | screenshots/list-empty.png |
    | News List | loading | 100:205 | screenshots/list-loading.png |

  budget: "max 30 tool calls"
```

#### Agent 2 — API Discovery (sonnet)

```yaml
api_discovery:
  model: sonnet
  purpose: "Find, test, and document backend API endpoints for this task"
  tools: [WebFetch, Bash, Read, Glob, Grep]

  steps:
    1_find_swagger:
      action: "tech_stack_adapter.api_discovery()"
      chain:
        angular: "proxy.conf.json → target URL → /swagger/v1/swagger.json"
        fallback_1: "environment.ts → apiUrl → /swagger/v1/swagger.json"
        fallback_2: "project.yaml → api.swagger_url"
        fallback_3: "Ask user"
      save: "Store swagger_url in project.yaml ONLY if api.swagger_url field is absent (never overwrite)"

    2_parse_swagger:
      action: "WebFetch(swagger_url) → parse JSON"
      timeout: "10 sec"
      on_401: "Try with credentials from checkpoint. If still 401 → WARN: Swagger behind auth. Ask user for token or skip API analysis."
      on_html_response: "Detect content-type != application/json → WARN: Swagger URL returns HTML (login page?). Ask user."
      on_connection_refused: "WARN: Backend not running at {base_url}. API analysis skipped."
      extract: "All endpoints that match task entity name"
      matching: |
        Task title contains 'News' → search for:
        - paths containing 'news' (case-insensitive)
        - schemas containing 'News' in definitions/components
        - Also check pluralization: news, new, newsItem

    3_test_endpoints:
      action: "For each found endpoint → verify it's alive (READ-ONLY)"
      safety_rule: "NEVER send mutating requests (POST/PUT/DELETE) with real data. Use OPTIONS/HEAD only for write endpoints."
      method:
        GET: "WebFetch/curl → expect 200 or 401 (auth needed)"
        POST: "OPTIONS /api/news → check Allow header includes POST. Do NOT send actual POST."
        PUT: "OPTIONS /api/news/{id} → check Allow header includes PUT."
        DELETE: "OPTIONS /api/news/{id} → check Allow header includes DELETE."
        fallback: "If OPTIONS not supported (405) → HEAD request → check status != 404"
      credentials: "From checkpoint.credentials if available"
      timeout: "5 sec per endpoint"

    4_classify:
      working: "Status 200/201/204/400/401 — endpoint exists and responds"
      broken: "Status 500 — endpoint exists but errors"
      missing: "Status 404 OR not in Swagger — endpoint doesn't exist"
      auth_required: "Status 401/403 — needs auth, but route exists"

  output: "docs/plans/{task-key}/.tmp/api-analysis.md"
  format: |
    ## API Analysis

    **Swagger:** {swagger_url}
    **Base URL:** {base_url}

    ### Working Endpoints
    | Method | Path | Status | Response Schema |
    |--------|------|--------|-----------------|
    | GET | /api/news | 200 | { items: News[], total: number } |

    ### Broken Endpoints
    | Method | Path | Status | Error |
    |--------|------|--------|-------|
    | POST | /api/news | 500 | Internal server error |

    ### Missing Endpoints (expected from Figma but not in Swagger)
    | Expected | Reason |
    |----------|--------|
    | GET /api/news/filters | Figma shows date filter component |

    ### Schemas
    ```
    News: { id: number, title: string, body: string, imageUrl: string, createdAt: string }
    NewsDto: { title: string, body: string, imageUrl?: string }
    ```

  budget: "max 20 tool calls"
```

#### Agent 3 — Functional Mapper (opus)

```yaml
functional_mapper:
  model: opus
  purpose: "Build complete functional map: screens + data + user flows"
  tools: [Read]
  wait_for: "Agents 1 and 2 must complete first — this agent reads their outputs"

  note: |
    This agent runs AFTER agents 1 and 2 (not parallel).
    It needs figma-screens.md and api-analysis.md as input.

  steps:
    1: "Read .tmp/figma-screens.md → screen list + flows"
    2: "Read .tmp/api-analysis.md → endpoints + schemas"
    3: "For each user flow: map screen → action → endpoint → response → next screen"
    4: "For each form: map Figma fields → Swagger schema fields → find mismatches"
    5: "For each table/list: map columns → API response fields"
    6: "Identify gaps:"
    7: "  - Figma shows feature but no endpoint (missing API)"
    8: "  - Swagger has field but Figma doesn't show it (hidden data?)"
    9: "  - Form field types don't match (Figma: datepicker, API: string not date)"

  output: "docs/plans/{task-key}/.tmp/functional-map.md"
  format: |
    ## Functional Map

    ### User Flows
    | # | Flow | Screens | Endpoints | Data |
    |---|------|---------|-----------|------|
    | 1 | Create news | List → Create Dialog → List | POST /api/news | NewsDto |
    | 2 | Edit news | List → Edit Dialog → List | GET + PUT /api/news/{id} | News → NewsDto |
    | 3 | Delete news | List → Confirm → List | DELETE /api/news/{id} | id |
    | 4 | Filter news | List (filtered) | GET /api/news?date=X | ⚠ MISSING endpoint |

    ### Form ↔ Schema Mapping
    | Figma Field | Type (Figma) | Schema Field | Type (Swagger) | Match? |
    |-------------|--------------|--------------|----------------|--------|
    | Title | text input | title | string | ✓ |
    | Body | textarea | body | string | ✓ |
    | Image | file upload | imageUrl | string | ⚠ upload endpoint missing |
    | Date | datepicker | createdAt | string (ISO) | ✓ |

    ### Gaps Summary
    | # | Type | Description | Impact |
    |---|------|-------------|--------|
    | 1 | Missing API | Date filter endpoint | Can't implement filter |
    | 2 | Missing API | Image upload endpoint | Can't implement upload |
    | 3 | Broken API | POST /api/news → 500 | Can't test create flow |

  budget: "max 15 tool calls"
```

### Aggregation

```yaml
aggregation:
  order: "Agent 1 + Agent 2 (parallel) → Agent 3 (sequential, needs their output)"
  steps:
    1: "Agent 1 (Figma) + Agent 2 (API) run in parallel"
    2: "When both complete → Agent 3 (Functional Mapper) reads their outputs"
    3: "After Agent 3 → merge all into task-analysis.md"
  output: "docs/plans/{task-key}/task-analysis.md"
  cleanup:
    rule: "Per consensus-review protocol: cleanup NOT automatic"
    when: "ONLY after confirmation gate resolves to 'y' (proceed) AND checkpoint written for Phase 0.7"
    action: "rm .tmp/figma-screens.md .tmp/api-analysis.md .tmp/functional-map.md"
    on_interrupt: ".tmp/ preserved for /continue recovery"
```

### Confirmation Gate

```yaml
confirmation_gate:
  display: "Contents of task-analysis.md"
  show_screenshots: "Key Figma screenshots from docs/plans/{task-key}/screenshots/"

  user_options:
    y: "Proceed — planner starts with this context"
    edit: "User corrects: add screen, fix endpoint, clarify flow"
    abort: "Task postponed"

    create_backend_tasks:
      trigger: "BROKEN or MISSING endpoints exist in api-analysis"
      prompt: "Найдены проблемы с API. Создать задачи на бэкенд?"
      if_yes:
        action: "MCP tool mcp__plugin_atlassian_atlassian__createJiraIssue for each broken/missing endpoint"
        note: "Uses Atlassian MCP directly (not adapter method). Adapter-jira is for reading tasks."
        template:
          type: "Task"
          summary: "API: {method} {path} — {broken|missing}"
          description: "Required for {task_key}. {details from functional-map}"
          link: "blocks {task_key}"
        confirm: "Show list of tasks to create → user approves once → create all"
      if_no: "Continue"

    continue_without_api:
      trigger: "User decides not to wait for backend"
      action: |
        Planner builds plan with mock data strategy:
        - Service created with real endpoints where working
        - TODO comments on broken/missing endpoints
        - Mock responses for dev/testing
        - plan.md marks affected parts as 'pending backend'
```

### Integration with Existing Pipeline

```yaml
integration:

  # FILES TO MODIFY (companion changes):
  files_to_update:
    - file: "core/orchestration/SKILL.md"
      changes:
        - "Add Phase 0.7 to phase_sequence table"
        - "Add '0.7' to checkpoint_schema.phase_completed values"
        - "Add 0.7 → phase_id_normalization mapping"
        - "Add task_analysis_path to worker_to_planner handoff contract required fields"
        - "Add recovery_heuristic entry: { task_analysis: yes, plan: no → 'Phase 1 with task-analysis.md' }"
    - file: "pipeline/planner/SKILL.md"
      changes:
        - "step_2_design_context: skip_if task-analysis.md exists (avoid re-scanning Figma)"
        - "Add: Read task-analysis.md as first step when available"
    - file: "adapters/angular/SKILL.md"
      changes:
        - "Add api_discovery method (proxy.conf.json → environment.ts → derive swagger_url)"

  handoff_contract:
    worker_to_planner:
      added_field: "task_analysis_path: string — path to task-analysis.md"
      required: [task, complexity, route, figma_urls, ui_inventory_path, task_analysis_path]
      note: "task_analysis_path is null for S complexity (Phase 0.7 skipped)"

  planner_receives:
    before: "task object + AC + figma_urls (raw)"
    after: "task object + AC + task-analysis.md (enriched: screens, API, flows, gaps)"

  planner_behavior:
    reads: "docs/plans/{task-key}/task-analysis.md"
    skip_step_2: "If task-analysis.md exists → skip step_2_design_context (already scanned)"
    uses: |
      - Screen list → becomes Implementation Parts
      - API schemas → informs service/model design
      - User flows → informs component wiring
      - Gaps → documented as risks/blockers in plan
    does_not: "Re-scan Figma or Swagger — all data in task-analysis.md"

  coder_also_reads:
    file: "docs/plans/{task-key}/task-analysis.md"
    uses: "API schemas for service implementation, endpoint URLs"

  checkpoint:
    phase_completed: "0.7"
    artifact: "task-analysis.md"
    recovery: "If task-analysis.md exists → skip Phase 0.7"
    orchestration_update: "Add 0.7 to phase_completed enum and recovery heuristic"

  worker_phase_sequence:
    updated: |
      Phase 0:   Config + classify
      Phase 0.5: Workspace setup
      Phase 0.7: Deep Task Analysis (skip for S complexity) ← NEW
      Phase 1:   Planner (reads task-analysis.md)
      Phase 2:   Plan Review (consensus, opus)
      Phase 3:   Coder
      Phase 4+5: Code Review + UI Review (consensus)
      Phase 6:   Completion

  prerequisites:
    mkdir: "mkdir -p docs/plans/{task-key}/screenshots/ before Agent 1 starts"
    mkdir_tmp: "mkdir -p docs/plans/{task-key}/.tmp/ before agents start"
```

### Confirmation Gate: Edit Flow

```yaml
edit_flow:
  trigger: "User chooses 'edit' at confirmation gate"
  mechanics:
    step_1: "Ask user: what needs to change? (free text)"
    step_2: "Update task-analysis.md with user's corrections"
    step_3: "Show updated summary — ask again: y/edit/abort"
    max_edits: 3
    note: "Do NOT re-run agents. User provides corrections directly."
```

### Continue-Without-API Flag

```yaml
api_strategy:
  field: "api_strategy: real | mock"
  location: "Written at top of task-analysis.md"
  set_by: "Confirmation gate — based on user's choice"
  consumed_by:
    planner: "If mock → plan includes mock service layer + TODO markers"
    coder: "If mock → create service with hardcoded responses, TODO on broken endpoints"
```

### Tech-Stack Adapter Contract Extension

```yaml
adapter_contract_extension:
  tech-stack:
    existing: [commands, quality_checks, security_checks, patterns, module_lookup]
    new:
      api_discovery:
        purpose: "Find API base URL and Swagger/OpenAPI spec URL"
        returns: "{ base_url: string, swagger_url: string, auth_hint: string }"

  angular_implementation:
    api_discovery:
      chain:
        1: "Read proxy.conf.json → extract target URL from /api proxy"
        2: "Read environment.ts → extract apiUrl"
        3: "Derive: {base_url}/swagger/v1/swagger.json"
        4: "WebFetch to verify URL responds"
      fallback: "project.yaml → api.swagger_url"
      last_resort: "Ask user, save to project.yaml"
```

### Cost Estimate

```yaml
cost:
  agent_1_figma: "opus, ~30 calls, ~3 min"
  agent_2_api: "sonnet, ~20 calls, ~2 min"
  agent_3_functional: "opus, ~15 calls, ~2 min (sequential after 1+2)"
  total: "~65 calls, ~5-7 min"
  note: "Runs once per task. Saved by /continue if session interrupted."
```
