---
name: arch-review
description: "Retrospective architectural review. 3 reviewers analyze code → 3 alternatives proposed. Use when user says /arch-review, \"оцени архитектуру\", \"review architecture\", \"как улучшить архитектуру\"."
human_description: "Ретроспективный архитектурный анализ: 3 ревьюера находят проблемы, затем 3 агента предлагают альтернативы."
---

# Arch-Review — Facade

Post-implementation or existing code architectural analysis. Sequential: 3 review agents → 3 alternative agents.

## Activation

Triggers:
- `/arch-review` command
- "оцени архитектуру", "review architecture"
- "как улучшить архитектуру", "архитектурный ревью"
- "предложи улучшения к коду"

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| --stack | Override tech-stack detection | autodetect |
| --model | Override agent model | opus |
| --scope | Path or module to focus on | auto-detect from git diff |

## Input Variants

| Variant | Example |
|---------|---------|
| After task | `/arch-review ARGO-12345` — review completed task |
| Existing code | `/arch-review src/features/notifications` — review module |
| Bare | `/arch-review` — ask user what to review |

## Flow

### Phase A: Review (3 agents parallel)

1. Load role adapter (same lenses as /arch)
2. Determine scope:
   - If task key → `git diff develop...HEAD` for changed files
   - If path → that directory
   - If bare → ask user
3. Dispatch 3 review agents in parallel
4. Each reviews code through their lens (review mode, not proposal mode)
5. Aggregate: consensus findings (2+ agents agree)

Review agent instruction template:
```yaml
instruction: |
  You are {lens.name} in REVIEW mode.
  Analyze existing code through your lens.
  Find: over-abstractions, under-abstractions, pattern violations,
  missed reuse opportunities, unnecessary complexity.
  Rate: 1-10 per area.
  Output: structured findings with severity (BLOCKER/MAJOR/MINOR).
```

Output per agent: `docs/plans/{scope}/.tmp/review-agent-{N}.md`

### Phase B: Alternatives (3 agents parallel)

Input: aggregated review findings from Phase A.

1. Dispatch 3 alternative agents with freedom gradient:
   - Agent 1: Conservative — fix within current patterns
   - Agent 2: Balanced — targeted improvements, justify cost
   - Agent 3: Challenger — alternative architecture + migration plan

Alternative agent instruction template:
```yaml
agent_1_conservative:
  instruction: |
    Review findings: {aggregated_findings}
    For each finding — propose a fix within current patterns.
    No new dependencies, no new abstractions.
    Show: what to change, estimated effort, risk.

agent_2_balanced:
  instruction: |
    Review findings: {aggregated_findings}
    For each finding — propose improvement, may introduce targeted changes.
    Justify cost of each deviation.

agent_3_challenger:
  instruction: |
    Review findings: {aggregated_findings}
    Propose alternative architecture for the reviewed code.
    May suggest significant refactoring if justified.
    MUST include: migration plan, effort estimate, what breaks during migration.
```

Output per agent: `docs/plans/{scope}/.tmp/alt-agent-{N}.md`

### Display

Show review report + 3 alternatives + comparison:

```markdown
## Architectural Review: {scope}

### Review Summary
| Area | Score | Key Finding |
|------|-------|-------------|
| {lens_1} | 7/10 | {finding} |
| {lens_2} | 5/10 | {finding} |
| {lens_3} | 8/10 | {finding} |

### Consensus Findings (2+ agents agree)
| # | Finding | Severity | Agents | Impact |

### Alternative 1: Conservative
{targeted fixes}

### Alternative 2: Balanced
{improvements with justified deviations}

### Alternative 3: Challenger
{alternative architecture + migration plan}

### Comparison
| Criteria | Alt 1 | Alt 2 | Alt 3 |
|----------|-------|-------|-------|
| Effort   | low   | medium | high |
| Risk     | none  | low    | medium |
| Improvement | incremental | moderate | significant |
```
