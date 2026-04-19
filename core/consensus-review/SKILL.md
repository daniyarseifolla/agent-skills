---
name: consensus-review
description: "Use when dispatching multi-agent review with independent analysis and aggregation."
human_description: "Паттерн мульти-агентного ревью: 3 агента на секцию, разные углы, агрегация consensus."
disable-model-invocation: true
---

# Consensus Review Pattern

Dispatch multiple independent agents per review section. Aggregate findings. Catch what single-agent reviews miss.

## When to Use

- Code review (Phase 8: review): 3 agents review same diff from different angles
- UI review (Phase 8: review, parallel): 3 agents test same page with different focus
- Plan review (Phase 6: plan-review): 2-3 agents validate plan from different perspectives
- /attach: 3 agents assess current state independently
- Any review where confidence matters more than speed

## Pattern

```yaml
consensus_review:
  sections: 3          # number of independent review sections
  agents_per_section: 3 # agents per section (2 minimum, 3 recommended)
  max_total_agents: 9 (3 sections × 3 agents, sections run sequentially)

  dispatch:
    rule: "Each agent in a section gets the SAME input but a DIFFERENT prompt/angle"
    parallel: true       # all agents in same section launch simultaneously
    sequential_sections: true   # sections run sequentially to respect Iron Law #5
    note: "Iron Law #5 (max 7 parallel) applies per section. With sequential sections: max 3 parallel at once."

  agent_prompt_template: |
    You are reviewer {N} of {total} for section "{section_name}".
    Your angle: {angle_description}

    Input: {shared_input}

    Return structured findings:
    - BLOCKER: {list}
    - MAJOR: {list}
    - MINOR: {list}
    - NIT: {list}
    - Score: {1-10}
    - Top 3 recommendations: {list}

  aggregation:
    method: "After all agents in a section complete, aggregate:"
    consensus: "Issues found by 2+ agents → confirmed findings"
    conflicts: "Issues where agents disagree → flag for user"
    unique: "Issues found by only 1 agent → lower confidence, still report"
    score: "Average of all agent scores"

    output_format: |
      ## Section: {name}

      ### Consensus (2+ agents agree)
      | # | Finding | Severity | Agents | Recommendation |

      ### Conflicts (agents disagree)
      | # | Finding | Agent A says | Agent B says | Agent C says |

      ### Unique Findings (1 agent only)
      | # | Finding | Severity | Source Agent | Confidence |

      ### Score: {avg}/10 (range: {min}-{max})
```

## Intermediate Files Protocol

```yaml
intermediate_files:
  directory: "docs/plans/{task-key}/.tmp/"

  lifecycle:
    create: "mkdir -p docs/plans/{task-key}/.tmp/ at section start"
    write: "Each agent writes to .tmp/agent-{N}-{section}-{angle}.md"
    aggregate: "Orchestrator reads all .tmp/*.md → builds consensus"
    promote: "Copy consensus results to docs/plans/{task-key}/ (parent dir)"
    cleanup: "rm -rf .tmp/ ONLY after orchestrator confirms consensus"

  benefits:
    - "Agents don't load each other's results into context"
    - "Orchestrator sees all results at aggregation time"
    - "Debuggable: .tmp/ preserved until cleanup confirmed"

  cleanup_rule: |
    Cleanup is NOT automatic.
    Happens ONLY after orchestrator confirms consensus is valid.
    If pipeline interrupted → .tmp/ remains for recovery.
    /cleanup command removes .tmp/ with other artifacts.
```

## Section Templates

### For Code Review (3 sections × 3 agents)

```yaml
code_review_sections:
  section_1_correctness:
    name: "Correctness & Logic"
    agents:
      - angle: "Bug hunter — find logic errors, edge cases, off-by-one, null handling"
      - angle: "Plan compliance — compare implementation vs plan, find deviations"
      - angle: "Type safety — find type mismatches, unsafe casts, missing generics"

  section_2_architecture:
    name: "Architecture & Patterns"
    agents:
      - angle: "Clean architecture — separation of concerns, dependency direction, SRP"
      - angle: "Project patterns — does code follow existing patterns in codebase?"
      - angle: "Security — OWASP checks, input validation, auth, secrets"

  section_3_quality:
    name: "Code Quality & UX"
    agents:
      - angle: "Readability — naming, complexity, documentation, magic numbers"
      - angle: "Performance — N+1, unnecessary re-renders, memory leaks, bundle size"
      - angle: "Component quality — reuse, states, accessibility, responsive"
```

### For UI Review (3 sections × 3 agents)

```yaml
ui_review_sections:
  section_1_functional:
    name: "Functional Testing"
    agents:
      - angle: "Happy path — main user flows work as expected"
      - angle: "Edge cases — empty states, long text, special chars, network errors"
      - angle: "Cross-browser/responsive — mobile, tablet, zoom, dark mode"

  section_2_visual:
    name: "Visual Fidelity"
    agents:
      - angle: "Per-element Figma comparison — CSS properties exact match"
      - angle: "Overall visual quality — hierarchy, spacing rhythm, consistency"
      - angle: "States & interactions — hover, focus, disabled, loading, transitions"

  section_3_quality:
    name: "UX & Accessibility"
    agents:
      - angle: "Accessibility — keyboard nav, screen reader, contrast, focus visible"
      - angle: "UX guidelines — ui-ux-pro-max checklist, interaction patterns"
      - angle: "Component reuse — duplicated components, missing shared mixins"
```

### For Plan Review (3 sections × 2 agents)

```yaml
plan_review_sections:
  section_1_completeness:
    name: "Plan Completeness"
    agents:
      - angle: "AC coverage — every AC maps to implementation part"
      - angle: "Scope — all files listed, dependencies correct, nothing missing"

  section_2_architecture:
    name: "Architecture & Feasibility"
    agents:
      - angle: "Architecture alignment — follows project patterns, correct imports"
      - angle: "Risk assessment — what could go wrong, missing error handling"

  section_3_design:
    name: "Design & Figma"
    agents:
      - angle: "Figma coverage — all components have node-ids, states documented"
      - angle: "Component design — reuse existing, correct patterns, responsive"
```

## Agent Failure Handling

```yaml
failure_handling:
  per_agent_timeout: "5 minutes — if agent does not return within 5 min, treat as FAILED"

  detection:
    no_verdict: "Agent returned text but no verdict keyword (BLOCKER/MAJOR/MINOR/Score) → FAILED"
    empty_output: "Agent returned empty or error message → FAILED"
    timeout: "Agent did not complete within per_agent_timeout → FAILED"

  degradation:
    one_of_three_fails:
      action: "Use 2 remaining agents for consensus"
      consensus_rule: "2 agents agree → confirmed (same as normal). 1 unique → lower confidence."
      log: "WARN: Agent {N} failed in section {section_name}. Proceeding with 2/3 agents."

    two_of_three_fail:
      action: "Fall back to single inline review for this section"
      consensus_rule: "No consensus possible — treat all findings as unique (lower confidence)"
      log: "WARN: 2/3 agents failed in section {section_name}. Falling back to single-agent findings."

    all_three_fail:
      action: "HALT section. Mark section as FAILED in output."
      log: "ERROR: All agents failed in section {section_name}. Section skipped."
      pipeline_action: "Continue to next section. Final verdict excludes failed sections."

  cross_section:
    one_section_fails: "Proceed with remaining sections. Note gap in output."
    two_sections_fail: "WARN user. Proceed with single section if it passed."
    all_sections_fail: "HALT review. Return ERROR verdict to worker. Request user intervention."

  NEVER:
    - "Do NOT silently ignore a failed agent — always log and adjust consensus"
    - "Do NOT stall the pipeline waiting for an agent that will never return"
    - "Do NOT re-dispatch failed agents automatically — log failure, degrade gracefully"
```

## Budget

```yaml
budget:
  per_agent: "max 80 tool calls, max 15 minutes"
  per_section: "wait for all agents, then aggregate (max 20 minutes)"
  total: "3 sections × 20 min = max 60 minutes for full consensus review"

  cost_consideration: |
    9 agents is expensive. Use consensus review for:
    - M/L/XL complexity tasks (worth the investment)
    - Final review before MR (catch bugs before they ship)
    - /attach on large existing codebases (understand state thoroughly)

    Skip for:
    - S complexity (single-agent review sufficient)
    - Quick fixes / hotfixes
    - Documentation-only changes
```

## Integration

```yaml
integration:
  pipeline_worker:
    Phase_7_implement: "condition: complexity >= M. Use code_review_sections for per-part verification"
    Phase_8_review: "condition: complexity >= M. Use code_review_sections"
    Phase_8_review_parallel: "condition: complexity >= M. Use ui_review_sections"

  commands:
    /cr: "condition: user adds --thorough flag. Use code_review_sections"
    /ui-review: "condition: user adds --thorough flag. Use ui_review_sections"
    /attach: "Use 3 agents for state detection"
    /scan-practices: "Use 3 agents for project analysis"
    /scan-qa: "Use 3 agents for QA data collection"

  activation: |
    Consensus review is NOT default.
    Activated by: complexity >= M in pipeline, OR --thorough flag in commands.
    For S complexity: single-agent review is sufficient.
```
