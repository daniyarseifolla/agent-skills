# GSD (Get Shit Done) — Research Analysis

**Source:** [gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done) v1.30.0
**Date:** 2026-03-30
**Purpose:** Extract reusable patterns, compare architectures, identify integration opportunities

---

## 1. Overview

GSD is a context engineering and meta-prompting system for Claude Code. Solves **context rot** — quality degradation as context window fills. Each task gets fresh 200k tokens; orchestrator stays at 30-40%.

**Core model:** Milestone → Phase → Plan → Wave (parallel execution)

**Scale:** 18 agents, 55+ slash commands, 41 templates, 5 hooks

---

## 2. Architecture Comparison

| Aspect | GSD | Agent Skills v2.2 |
|--------|-----|-------------------|
| Task model | Milestone/Phase waterfall | Pipeline with adaptive complexity |
| Agents | 18 named (planner, executor, verifier...) | 1 worker + 8 phase skills |
| State | `.planning/` (markdown files) | `checkpoint.yaml` (YAML) |
| Entry points | 55+ `/gsd:*` commands | `/worker` + facades |
| Adapters | Monolithic | Modular (jira/gitlab/angular/figma) |
| Complexity routing | None (all phases always) | S/M/L/XL with phase skipping |
| Reviews | Single-agent | 3× consensus |
| Resume | Manual (`/gsd:resume-work`) | Auto (`checkpoint.resume_phase`) |

---

## 3. Prompt Engineering Patterns Worth Adopting

### 3.1 Goal-Backward Verification

Instead of "did tasks complete?", verify "does the goal actually work?":

```
Level 1: What must be TRUE? (observable user behaviors)
Level 2: What must EXIST? (concrete artifacts)
Level 3: What must be WIRED? (imports, routes, connections)
Level 4: Does DATA FLOW? (not hardcoded empty)
```

**Verification matrix:**

| Exists | Substantive | Wired | Status |
|--------|-------------|-------|--------|
| ✓ | ✓ | ✓ | ✓ VERIFIED |
| ✓ | ✓ | ✗ | ⚠ ORPHANED |
| ✓ | ✗ | — | ✗ STUB |
| ✗ | — | — | ✗ MISSING |

Data-flow level catches "hollow components" — UI exists but renders nothing.

**Where to apply:** `pipeline-code-reviewer`, `pipeline-plan-reviewer`

---

### 3.2 Deviation Rules (Autonomous Decision Tiers)

```
RULE 1: Auto-fix bugs              → broken behavior, errors
RULE 2: Auto-add critical items    → missing validation, auth, error handling
RULE 3: Auto-fix blockers          → prevents task completion
RULE 4: ASK about architecture     → new DB table, major schema, new service

Priority: Rule 4 → STOP. Rules 1-3 → FIX. Unsure → Rule 4.
Scope: Only issues DIRECTLY caused by current task's changes.
Limit: 3 auto-fix attempts per task, then document and move on.
```

**Where to apply:** `pipeline-coder`

---

### 3.3 Analysis Paralysis Guard

```
If 5+ consecutive Read/Grep/Glob calls without any Edit/Write/Bash:
  STOP.
  State in one sentence why you haven't written anything yet.
  Then either:
    1. Write code (you have enough context), or
    2. Report "blocked" with the specific missing information.
  Do NOT continue reading.
```

**Where to apply:** `pipeline-coder`, `pipeline-planner`

---

### 3.4 Mandatory Initial Read

```
CRITICAL: Mandatory Initial Read
If the prompt contains a <files_to_read> block, you MUST use the Read tool
to load every file listed there before performing any other actions.
This is your primary context.
```

**Where to apply:** All pipeline skills that receive handoff payloads

---

### 3.5 Confidence Tiers

```
HIGH   — Context7 or official docs, multiple sources verified
MEDIUM — Official docs + secondary source, OR single project consistency
LOW    — WebSearch only, unverified, marked for validation
UNSCORED — No evidence found
```

**Where to apply:** `pipeline-planner` (research output), `pipeline-code-researcher`

---

### 3.6 Locked / Discretion / Deferred Decision Model

From CONTEXT.md pattern:

```
<decisions>
### Area 1
- D-01: Card-based layout, not timeline        ← LOCKED (do exactly this)
- D-02: Infinite scroll with new posts indicator ← LOCKED

### Claude's Discretion
- Loading skeleton design                        ← Agent decides
- Exact spacing and typography                   ← Agent decides
</decisions>

<deferred>
- Commenting on posts — Phase 5                  ← DO NOT implement
- Bookmarking posts — backlog                    ← DO NOT implement
</deferred>
```

**Where to apply:** Phase 0 (task analysis) → pass to planner as structured constraints

---

### 3.7 Scope Creep Guardrail

```
Allowed (clarifying ambiguity):
  "How should posts be displayed?" (layout, density)
  "What happens on empty state?" (within the feature)

Not allowed (scope creep):
  "Should we also add comments?" (new capability)
  "What about search/filtering?" (new capability)

Heuristic: Does this clarify HOW to implement what's scoped,
or does it add a NEW capability that could be its own phase?
```

**Where to apply:** `pipeline-planner` system prompt

---

## 4. Hooks Architecture

### 4.1 Context Monitor (gsd-context-monitor.js)
- Reads context metrics from `/tmp/claude-ctx-{sessionId}.json` (written by statusline)
- WARNING at ≤35% remaining, CRITICAL at ≤25%
- Debounce: 5 tool uses between warnings, but severity escalation bypasses
- Outputs via `additionalContext` in hook response JSON
- **Status:** Restored to our settings.json ✓

### 4.2 Statusline (gsd-statusline.js)
- Shows: `model | current task | directory | context usage`
- 10-segment progress bar with color coding
- Writes bridge file for context-monitor
- **Status:** Kept in our settings.json ✓

### 4.3 Prompt Guard (gsd-prompt-guard.js)
- PreToolUse hook on Write/Edit targeting `.planning/`
- Scans for 13+ injection patterns (ignore previous, `<system>`, invisible unicode)
- Advisory only (does not block)
- **Status:** Removed (low value for our use case)

### 4.4 All Hooks Pattern
```javascript
// Stdin timeout guard — prevents hanging
const stdinTimeout = setTimeout(() => process.exit(0), 10000);
process.stdin.on('end', () => { clearTimeout(stdinTimeout); /* process */ });

// Silent failure — never blocks tool execution
try { /* logic */ } catch (e) { process.exit(0); }

// Output format
{ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: "..." } }
```

---

## 5. Unique Features (Not in Agent Skills v2.2)

### 5.1 Seeds — Forward-Looking Ideas
Captured ideas with trigger conditions that auto-surface at milestone creation:
```yaml
status: dormant
trigger_when: "when user accounts added"
scope: Medium
breadcrumbs: [src/auth/, docs/decisions/adr-003.md]
why_this_matters: "Session tokens currently stored plaintext..."
```
Stored in `.planning/seeds/SEED-NNN-slug.md`.

### 5.2 Threads — Cross-Session Knowledge
Lightweight persistence outside the phase system:
- Status: OPEN → IN PROGRESS → RESOLVED
- Goal, Context, References, Next Steps
- Can be promoted to phases or backlog when mature

### 5.3 Forensics — Post-Mortem Analysis
Detects anomalies automatically:
- **Stuck loop:** Same file in 3+ consecutive commits
- **Missing artifacts:** Phase complete but lacks SUMMARY.md
- **Abandoned work:** Large commit gap + mid-execution STATE.md
- **Scope drift:** Commits touch files outside phase domain
- **Test regression:** "fix test", "revert", "broken" patterns

### 5.4 Fast Mode — Inline Trivial Tasks
≤3 file edits, <1 min, no research needed. Direct: Read → Edit → Verify → Commit. No subagents, no PLAN.md.

### 5.5 Manager Mode — Multi-Phase Dashboard
Interactive terminal showing all phases with visual status (✓◆○). Runs discuss inline, plan/execute as background agents. Parallel dispatch from single terminal.

### 5.6 Autonomous Mode — Full Milestone Autopilot
Runs all remaining phases: discuss → plan → execute → verify per phase. Pauses only for explicit user decisions. Re-reads ROADMAP after each phase for dynamically inserted phases.

### 5.7 User Profiling — 8-Dimension Behavioral Analysis
Analyzes session messages for: communication style, risk tolerance, code preferences, testing approach, debugging style. Outputs USER-PROFILE.md.

### 5.8 Workspace Management — Multi-Project Isolation
Creates isolated directories with repo worktrees + independent `.planning/`. Enables parallel GSD sessions per workspace.

### 5.9 Backlog Management
999.x numbering for parking-lot items. `/review-backlog` promotes to active phases or removes stale entries.

---

## 6. State Management Model

### Core Files
```
.planning/
├── PROJECT.md          — Living context (vision, core value, constraints, decisions)
├── STATE.md            — Short-term memory (<100 lines): position, metrics, blockers
├── ROADMAP.md          — Phase breakdown with requirements traceability
├── REQUIREMENTS.md     — v1 (active) / v2 (deferred) / out-of-scope
├── config.json         — Workflow toggles, model profiles, parallelization
├── phases/NN-name/
│   ├── CONTEXT.md      — Locked decisions (D-01, D-02)
│   ├── RESEARCH.md     — Domain investigation
│   ├── PLAN.md         — XML-structured atomic tasks
│   ├── SUMMARY.md      — Execution results + commits
│   ├── UAT.md          — User acceptance testing
│   └── VERIFICATION.md — Automated verification report
├── seeds/              — Forward-looking ideas
├── threads/            — Cross-session knowledge
├── todos/pending/      — Captured ideas
└── milestones/         — Archived versions
```

### Key Design Decisions
- STATE.md <100 lines (digest, not archive)
- gsd-tools.cjs CLI for atomic state operations
- Bridge files in /tmp for hook-to-hook communication
- YAML frontmatter for machine-readable metadata
- `.continue-here.md` for session handoff (created on pause, deleted on resume)

---

## 7. GSD Strengths Over Agent Skills v2.2

| Area | Why Better |
|------|------------|
| Greenfield projects | `/new-project` with full research, no ticket needed |
| Cross-session continuity | STATE.md + threads + seeds + pause/resume |
| Decision locking | CONTEXT.md (locked/discretion/deferred) |
| Verification depth | 4-level (exists → substantive → wired → data-flow) |
| Forensics | Structured post-mortem with anomaly detection |
| UI output branding | Standardized banners, checkpoints, symbols, anti-patterns |

## 8. Agent Skills v2.2 Strengths Over GSD

| Area | Why Better |
|------|------------|
| Adaptive complexity | S/M/L/XL routing, phase skipping |
| Consensus reviews | 3× agents on code/plan/UI |
| Modularity | Swappable adapters per project |
| Auto-resume | checkpoint.yaml + invalidated_phases |
| Entry point | Single `/worker` vs 55 commands |
| Parallel phases | 4+5 run simultaneously |

---

## 9. Integration Roadmap

### Phase 1 — Prompt Patterns (no architecture changes)
- [ ] Add goal-backward verification to `pipeline-code-reviewer`
- [ ] Add deviation rules to `pipeline-coder`
- [ ] Add analysis paralysis guard to `pipeline-coder`
- [ ] Add mandatory initial read to all phase skills
- [ ] Add confidence tiers to `pipeline-planner` and `pipeline-code-researcher`

### Phase 2 — New Capabilities
- [ ] Add scope creep guardrail to planner system prompt
- [ ] Add locked/discretion/deferred model to Phase 0 output
- [ ] Consider fast-mode bypass for S-complexity tasks

### Phase 3 — Evaluation
- [ ] Compare code-reviewer output quality with/without goal-backward
- [ ] Measure coder autonomy improvement with deviation rules
- [ ] Test analysis paralysis guard impact on implementation speed

---

*Research conducted: 2026-03-30*
*Methodology: 10 parallel exploration agents covering hooks, agents, commands, state, prompts, install, comparison, README, unique features, project structure*
