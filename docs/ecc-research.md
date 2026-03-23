# ECC Research: ideas for agent-skills v2.2+

Source: [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (97K+ stars)

## 1. Pre-Compaction Hook

**Problem:** L/XL tasks hit context limit, Claude compacts and loses critical state.

**Solution:** Hook on `PreCompact` event that:
- Saves current pipeline state (phase, decisions, blockers) to file
- Extracts key patterns and decisions from conversation
- Writes a "context to load" summary for post-compaction recovery

**Priority:** HIGH value, LOW effort (1 hook file)

**Implementation:** Add to `v2.2/hooks/` as a new lifecycle hook. Format:
```
Exit code 0 = pass, state saved
Input: JSON on stdin with conversation context
Output: state file in .claude/sessions/
```

---

## 2. Agent Compression (Token Optimization)

**Problem:** 20 skills loaded = lots of tokens. Not all are needed simultaneously.

**Solution:** Three loading modes for skill definitions:
- **Catalog** (~2-3K tokens): name + description + triggers only
- **Summary** (~4-5K tokens): + first paragraph of instructions
- **Full**: complete skill content (loaded on demand)

**Priority:** HIGH value, MEDIUM effort

**Implementation:**
- Add frontmatter field `loading: catalog | summary | full` to each skill
- Core orchestration loads catalog by default
- Full content fetched only when skill is activated
- Estimated saving: 50%+ tokens on initial load

---

## 3. Eval Harness / `/health` Command

**Problem:** After sync or install, no way to verify all skills, commands, hooks are intact.

**Solution:** Deterministic self-check system:
- Verify all skill files exist and have valid frontmatter
- Verify all commands reference existing skills
- Verify hooks are properly configured
- Check adapter availability for project.yaml config
- Score by category (0-10), top 3 actions for fixes

**Priority:** MEDIUM value, LOW effort

**Implementation:** New command `v2.2/commands/health.md` that:
- Globs for expected files
- Validates YAML/frontmatter
- Reports missing or broken references
- Exit code 1 if critical issues found

---

## 4. Hook Profiles (minimal / standard / strict)

**Problem:** S-tasks don't need full validation, XL-tasks need maximum safety.

**Solution:** Environment variable `PIPELINE_HOOK_PROFILE` controls strictness:
- `minimal` — skip formatting, linting, only critical checks
- `standard` (default) — security + format + CI checks
- `strict` — all checks + Figma CSS verification + pre-commit audit

**Priority:** MEDIUM value, LOW effort

**Implementation:**
- Add `profiles` field to hook definitions
- Core orchestration sets profile based on complexity (S/M/L/XL)
- Each hook checks profile before executing

---

## 5. Session Persistence (SQLite)

**Problem:** Checkpoints are file-based and hard to query. No cross-session analytics.

**Solution:** SQLite state store with tables:
- `sessions` — pipeline runs with state, timing, snapshots
- `skill_runs` — skill executions with outcome, tokens, duration
- `decisions` — architectural decisions with rationale
- Queryable: "which skills fail most?", "average pipeline duration?"

**Priority:** HIGH value, HIGH effort

**Implementation:**
- New `core/state-store.md` skill or script
- AJV schema validation for data integrity
- Fallback to JSONL if SQLite unavailable
- Query interface via `/progress` command extension

---

## 6. Skill Evolution System

**Problem:** Skills are static. No feedback loop from execution results.

**Solution:** Four-layer system:
1. **Observation** — capture task, skill, outcome, user feedback per run
2. **Tracking** — normalize executions (success/failure/partial)
3. **Health** — 7-day and 30-day success rates, detect declining trends
4. **Amendment** — propose changes only on repeated patterns, not one-offs

Version management: `.versions/v1.md`, `.versions/v2.md` + rollback capability.

**Priority:** HIGH value, HIGH effort

**Implementation:**
- Observations stored in `~/.claude/ecc/skills/observations.jsonl`
- Health check via `/health` command extension
- Amendments are additive (original intent preserved)
- Minimum 2 runs per variant before recommending changes

---

## 7. Tmux + Worktree Parallel Orchestration

**Problem:** L/XL tasks run sequentially. Coder waits for researcher.

**Solution:** Launch workers in separate tmux panes with isolated git worktrees:
- Each worker gets its own worktree copy
- Coordination via filesystem (task/handoff/status files)
- No direct coupling between workers
- Supports dry-run mode

**Priority:** MEDIUM value, HIGH effort

**Implementation:**
- Extend `core/orchestration.md` with parallel mode
- New script `scripts/orchestrate.sh` for tmux management
- Status files in `.claude/pipeline/` for coordination
- Constraint: workers must not spawn subagents

---

## Priority Matrix

| Feature                  | Value | Effort | Phase   |
|--------------------------|-------|--------|---------|
| Pre-Compaction Hook      | HIGH  | LOW    | v2.3    |
| Eval Harness `/health`   | MED   | LOW    | v2.3    |
| Hook Profiles            | MED   | LOW    | v2.3    |
| Agent Compression        | HIGH  | MED    | v2.3    |
| Session Persistence      | HIGH  | HIGH   | v2.4    |
| Skill Evolution          | HIGH  | HIGH   | v2.4    |
| Tmux Orchestration       | MED   | HIGH   | v2.5+   |

## Next Steps

1. Start with v2.3: Pre-Compaction Hook + Eval Harness + Hook Profiles + Agent Compression
2. v2.4: Session Persistence + Skill Evolution (data-driven improvement loop)
3. v2.5+: Tmux orchestration for true parallel execution
