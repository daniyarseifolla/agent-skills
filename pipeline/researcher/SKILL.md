---
name: pipeline-researcher
description: "Use when performing deep task research with multi-agent analysis. Called by worker Phase 3, not directly."
human_description: "Deep research: 3 агента (Figma + API + Functional) анализируют задачу параллельно → task-analysis.md"
model: opus
---

# Pipeline Researcher

Phase 3: research. Deep task analysis with 3 specialized agents. Runs for M/L/XL complexity.

---

## 1. Input

```yaml
input:
  task:
    title: string
    description: string
    acceptance_criteria: string[]
    key: string
  figma_urls: string[]
  api_config:
    swagger_url: string
    base_url: string
  complexity: "M|L|XL"
  tech_stack_adapter: "for api_discovery()"
  design_adapter: "for Figma access"
```

---

## 2. Skip Condition

```yaml
skip_when: "complexity == S"
reason: "Small tasks don't need deep research — direct to planning"
```

---

## 3. Setup

```yaml
setup:
  step_1: "mkdir -p docs/plans/{task-key}/screenshots/"
  step_2: "mkdir -p docs/plans/{task-key}/.tmp/"
```

---

## 4. Dispatch Strategy

```yaml
MANDATORY: |
  ALL 3 agents MUST run. Do NOT skip any agent.
  Do NOT do inline analysis instead of dispatching agents.
  Do NOT decide "this is retro mode, skip Agent 3".
  Even for /attach — run all 3 agents if task-analysis.md doesn't exist.
  Use Agent(subagent_type: 'general-purpose') — NOT 'Explore' (Explore can't Write files).

dispatch:
  step_1_parallel:
    description: "Launch Agent 1 + Agent 2 IN PARALLEL"
    method: "Use Skill: superpowers:dispatching-parallel-agents"

    agent_1_figma_explorer:
      name: "Figma Explorer"
      model: opus
      subagent_type: "general-purpose"
      role: "Extract design context from Figma files"
      steps:
        - "get_metadata(fileKey) → list all frames"
        - "For each matching frame: get_design_context → extract components/CSS"
        - "get_screenshot per frame → save to screenshots/"
        - "Identify: screen types, states, flows, interactive components"
      output: ".tmp/figma-screens.md"
      verdict: "End with: ## Verdict: SUCCESS | PARTIAL | FAILED"

    agent_2_api_discovery:
      name: "API Discovery"
      model: sonnet
      subagent_type: "general-purpose"
      role: "Discover and validate API endpoints"
      steps:
        - "tech_stack_adapter.api_discovery() → find swagger_url"
        - "WebFetch(swagger_url) → parse endpoints matching task entity"
        - "Test endpoints: GET → WebFetch, POST/PUT/DELETE → OPTIONS only (safety)"
        - "Classify: working / broken / missing / auth_required"
      output: ".tmp/api-analysis.md"
      verdict: "End with: ## Verdict: SUCCESS | PARTIAL | FAILED"

  step_2_check_verdicts:
    description: "Check verdicts (Iron Law #2)"
    rules:
      both_failed: "HALT, show error to user"
      one_failed: "WARN, continue with partial data"

  step_3_sequential:
    description: "Launch Agent 3 SEQUENTIALLY (needs output from 1+2)"

    agent_3_functional_mapper:
      name: "Functional Mapper"
      model: opus
      subagent_type: "general-purpose"
      role: "Map screens to actions to endpoints"
      input: "orchestrator passes paths to .tmp/figma-screens.md + .tmp/api-analysis.md"
      steps:
        - "Maps: screen → action → endpoint → response → next screen"
        - "Maps: form fields → Swagger schema fields"
        - "Finds: gaps (Figma feature without endpoint, schema mismatches)"
      output: ".tmp/functional-map.md"
```

---

## 5. Merge

```yaml
merge:
  action: "Read .tmp/*.md → combine into docs/plans/{task-key}/task-analysis.md"
  sources:
    - ".tmp/figma-screens.md"
    - ".tmp/api-analysis.md"
    - ".tmp/functional-map.md"
  output: "docs/plans/{task-key}/task-analysis.md"
```

---

## 6. Confirmation Gate

```yaml
confirmation:
  show: "task-analysis.md + screenshots to user"
  options:
    y: "Proceed to next phase"
    edit: "Max 3 corrections, then re-confirm"
    abort: "Stop pipeline"
  broken_endpoints:
    offer: "create_backend_tasks (mcp createJiraIssue)"
    if_user_chooses_continue: "Set api_strategy: mock in task-analysis.md"
  after_confirm: "Cleanup .tmp/ (only after user confirms)"
```

---

## 7. Output

```yaml
output:
  path: "docs/plans/{task-key}/task-analysis.md"
  format: |
    ## Task Analysis: {task-key}

    ### Figma Screens
    {from figma-screens.md}

    ### API Endpoints
    {from api-analysis.md}

    ### Functional Map
    {from functional-map.md}

    ### Gaps & Risks
    - Figma features without endpoints
    - Schema mismatches
    - Missing states
```

---

## 8. Handoff

```yaml
handoff:
  to: "impact-analyzer (Phase 4: impact), planner (Phase 5: plan)"
  payload:
    task_analysis_path: string
  required: [task_analysis_path]
  validation: "task-analysis.md must exist and contain Figma Screens + API Endpoints + Functional Map sections"
```
