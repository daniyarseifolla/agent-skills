---
name: consensus-review
description: "Multi-agent consensus review pattern. Dispatches 2-3 agents per section for independent analysis, then aggregates findings. Used by pipeline-code-reviewer, pipeline-ui-reviewer, and /attach for thorough reviews."
disable-model-invocation: true
---

# Consensus Review Pattern

Dispatch multiple independent agents per review section. Aggregate findings. Catch what single-agent reviews miss.

## When to Use

- Code review (Phase 4): 3 agents review same diff from different angles
- UI review (Phase 5): 3 agents test same page with different focus
- Plan review (Phase 2): 2-3 agents validate plan from different perspectives
- /attach: 3 agents assess current state independently
- Any review where confidence matters more than speed

## Pattern

```yaml
consensus_review:
  sections: 3          # number of independent review sections
  agents_per_section: 3 # agents per section (2 minimum, 3 recommended)
  max_total_agents: 9   # hard cap per Iron Law #5 adaptation

  dispatch:
    rule: "Each agent in a section gets the SAME input but a DIFFERENT prompt/angle"
    parallel: true       # all agents in same section launch simultaneously
    sequential_sections: false  # sections can also run in parallel if independent

  agent_prompt_template: |
    You are reviewer {N} of {total} for section "{section_name}".
    Your angle: {angle_description}

    Input: {shared_input}

    Return structured findings:
    - CRITICAL: {list}
    - HIGH: {list}
    - MEDIUM: {list}
    - LOW: {list}
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

## Budget

```yaml
budget:
  per_agent: "max 30 tool calls, max 5 minutes"
  per_section: "wait for all agents, then aggregate (max 7 minutes)"
  total: "3 sections × 7 min = max 21 minutes for full consensus review"

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
    Phase_2: "Load consensus-review, use plan_review_sections"
    Phase_4: "Load consensus-review, use code_review_sections"
    Phase_5: "Load consensus-review, use ui_review_sections"
    condition: "complexity >= M"

  attach_command:
    Phase_0: "Dispatch 3 agents to assess state independently, aggregate"

  standalone:
    /cr: "Use code_review_sections for thorough review"
    /ui-review: "Use ui_review_sections for thorough review"
```
