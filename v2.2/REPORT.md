# Agent Skills v2.2 — Report

**Date:** 2026-03-25
**Commit:** 84fcad5

## Overview

| Metric | Value |
|--------|-------|
| Skills | 23 |
| Commands | 16 |
| Total lines (skills) | 5,863 |
| Total lines (commands) | 432 |
| Hooks | 1 (figma-verify-reminder) |
| Session commits | 23 |

## Architecture

```
User → Command → Facade → Worker → [Phase 0 → 0.5 → 0.7 → 1 → 2 → 3 → 4+5 → 6]
                                      ↓         ↓         ↓        ↓       ↓
                                    Adapters   Core    Consensus  Subagents  MCP
```

### Layers

| Layer | Count | Total Lines | Purpose |
|-------|-------|-------------|---------|
| Core | 4 | 989 | Orchestration, security, metrics, consensus |
| Pipeline | 8 | 3,089 | Worker, planner, coder, reviewers, researcher |
| Adapters | 4 | 1,068 | Jira, GitLab, Angular, Figma |
| Facades | 7 | 717 | Entry points: jira-worker, deploy, sync, scans, figma-audit |

## Skills Catalog

### Core (invisible, auto-loaded)

| Skill | Lines | Model | Purpose |
|-------|-------|-------|---------|
| orchestration | 415 | — | Phase table, handoffs, checkpoints, recovery, loops, routing |
| security | 151 | — | Universal OWASP checks (framework-specific → adapters) |
| consensus-review | 211 | — | 3x3 agent pattern: dispatch, aggregate, verdict |
| metrics | 212 | — | Pipeline metrics schema, collection, storage |

### Pipeline (project-agnostic phases)

| Skill | Lines | Model | Mode | Purpose |
|-------|-------|-------|------|---------|
| worker | 469 | — | inline | Orchestrator: phases, checkpoints, dispatch |
| planner | 283 | opus | inline | Research codebase, create plan (reads task-analysis.md) |
| plan-reviewer | 217 | opus | subagent | Validate plan (consensus 3x opus for M+) |
| coder | 281 | sonnet | inline | Evaluate gate + implement + commit gate |
| figma-coding-rules | 321 | — | loaded by coder | Figma extract, self-verify, UI quality, icons |
| code-reviewer | 279 | sonnet | subagent/worktree | Review diff (consensus 3x sonnet for M+) |
| ui-reviewer | 460 | sonnet | subagent | Functional + visual testing (consensus 3x sonnet for M+) |
| code-researcher | 101 | haiku | Agent tool | Cheap read-only search (L/XL only) |

### Adapters (swappable per project)

| Skill | Lines | Type | Key Methods |
|-------|-------|------|-------------|
| jira | 179 | task-source | fetch_task, parse_ac, transition, format_mr |
| gitlab | 304 | ci-cd | create_mr, pipeline, deploy, cherry_pick, CI disable/restore |
| angular | 361 | tech-stack | commands, quality_checks, security_checks, api_discovery, patterns |
| figma | 224 | design | get_design, get_screenshot, compare_visual, extract_tokens |

### Facades (user-facing entry points)

| Skill | Lines | Triggers |
|-------|-------|----------|
| figma-audit | 638 | `/figma`, "проверь верстку", "сравни с макетом" |
| scan-qa-playbook | 211 | `/scan-qa`, "скан QA" |
| community-sync | 186 | `/sync`, "обновить ветки" |
| scan-practices | 149 | `/scan-practices`, "скан практик" |
| scan-ui-inventory | 132 | `/scan-ui`, "скан UI" |
| jira-worker | 45 | `/worker`, ARGO-XXX, "сделай задачу" |
| deploy | 34 | `/deploy`, "задеплой" |

## Commands

| Command | Lines | Type |
|---------|-------|------|
| /worker | 13 | Pipeline orchestrator |
| /figma | 25 | Figma audit pipeline |
| /plan | 14 | Planning only |
| /attach | 162 | Attach to existing task |
| /continue | 28 | Resume from checkpoint |
| /progress | 24 | Show pipeline state |
| /cleanup | 18 | Remove artifacts |
| /cr | 15 | Code review |
| /code-review | 15 | Alias for /cr |
| /ui-review | 13 | UI review |
| /verify-figma | 53 | Figma CSS verification |
| /deploy | 14 | Deploy to env |
| /sync | 11 | Sync community branches |
| /scan-ui | 9 | Scan UI inventory |
| /scan-qa | 9 | Scan QA playbook |
| /scan-practices | 9 | Scan practices |

## Model Routing

| Model | Skills | Cost | Purpose |
|-------|--------|------|---------|
| opus | planner, plan-reviewer (consensus) | $$$ | Deep research, architecture, analytical review |
| sonnet | coder, code-reviewer, ui-reviewer, figma-audit agents | $$ | Implementation, pattern matching, review |
| haiku | code-researcher | $ | Cheap read-only search |

## Pipeline Phases (`/worker` for M+ tasks)

| Phase | Name | Agents | Model | Consensus? |
|-------|------|--------|-------|-----------|
| 0 | Config + classify | 1 | sonnet | No |
| 0.5 | Workspace setup | 1 | sonnet | No |
| 0.7 | **Deep Task Analysis** | 2+1 | opus+sonnet | Yes (Figma + API + Functional) |
| 1 | Planning | 1 | opus | No |
| 2 | Plan Review | 3 | opus | Yes (AC + Architecture + Design) |
| 3 | Implementation | 1+N | sonnet | No (subagents per part) |
| 4 | Code Review | 3 | sonnet | Yes (Bugs + Compliance + Security) |
| 5 | UI Review | 3 | sonnet | Yes (Functional + Visual + States) |
| 6 | Completion | 1 | sonnet | No |

**S tasks:** Phases 0.7, 2, 5 skipped. Single agent on 4.

## Key Features

### Consensus Review Pattern
- 3 agents with different angles review the same input
- 2+ agents agree → confirmed finding
- Agents disagree → flagged conflict
- Worst verdict wins

### Deep Task Analysis (Phase 0.7)
- Figma Explorer: all screens, states, flows, screenshots
- API Discovery: Swagger parse + OPTIONS endpoint testing
- Functional Mapper: screens × endpoints × user flows + gaps
- Output: task-analysis.md (planner reads instead of re-scanning)
- Confirmation gate: user reviews before planning starts

### Figma Self-Verify + Commit Gate
- Extract exact CSS from Figma → write → compare every property → fix
- Commit blocked if figma-verify.md has unresolved MISMATCH
- Hook reminds agent on every .scss/.css/.component.html edit
- Tolerance: coder ±0px (author), ui-reviewer ±2px (render)

### `/figma` Audit Pipeline
- Phase 1: Consensus node map (3 agents: structure + visual + code)
- Phase 2: Consensus comparison (3 agents: screenshot + getComputedStyle + UX)
- Phase 3: Subagent fix/build per component (inline ≤3, subagent >3)
- Phase 4: Consensus verification (before/after score)

## Adapter Contracts

```yaml
task-source:  fetch_task, parse_ac, get_complexity_hints, transition, format_mr_description
ci-cd:        create_mr, get_pipeline, wait_for_stage, deploy, retry_job, create_tag
tech-stack:   commands, quality_checks, security_checks, api_discovery, patterns, module_lookup
design:       parse_urls, get_design, get_screenshot, compare_visual, extract_tokens
```

## External Dependencies

| Skill | Used by | Required? |
|-------|---------|-----------|
| visual-qa | ui-reviewer, figma-audit | WARN if missing |
| css-styling-expert | coder | WARN if missing |
| refactoring-ui | coder, figma-coding-rules | WARN if missing |
| qa-test-planner | ui-reviewer | WARN if missing |
| ui-ux-pro-max | ui-reviewer | WARN if missing |
| agent-browser | ui-reviewer | WARN if missing |

## MCP Dependencies

| MCP | Used by | Required? |
|-----|---------|-----------|
| Figma | adapter-figma, figma-audit, coder | HALT if missing (for design tasks) |
| Atlassian | adapter-jira, Phase 0.7 (create backend tasks) | HALT if missing (for Jira tasks) |
| Playwright / Chrome DevTools | ui-reviewer, figma-audit | Fallback to non-browser mode |

## Files Changed This Session

23 commits since fe478c6:
- 10 consensus review fixes (P1-P10)
- 6 figma-audit facade creation
- 3 consensus mode in worker pipeline
- 4 Phase 0.7 implementation
- Hook fix + AGENT.md updates

## Known Issues (not fixed)

- Russian AC headings in Jira adapter
- `grep -P` for lookahead patterns in core-security
- Atomic checkpoint write (tmp → rename)
- `/attach` is 162 lines in command file (should be facade)
- `/code-review` is duplicate of `/cr`
- No eval tests for trigger accuracy
