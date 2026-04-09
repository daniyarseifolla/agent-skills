# Agent Skills Overview

This repo contains **custom Claude Code skills** that are installed globally at `~/.claude/skills/` and used across Angular/Nx projects (passport, community). This is a backup/mirror — the source of truth is `~/.claude/skills/{skill-name}/`.

## Architecture

```
jira-worker (orchestrator)
  │
  ├─ jira-planner         → creates plan.md + checklist.md
  ├─ jira-plan-reviewer   → reviews plan (subagent, full mode)
  ├─ jira-code-reviewer   → reviews code (standalone or from pipeline)
  ├─ jira-ui-reviewer     → UI testing (standalone or from pipeline)
  │
  ├─ scan-ui-inventory    → generates .claude/ui-inventory.md
  │
  ├─ deploy               → GitLab CI/CD deployment
  └─ community-sync       → cherry-pick across community/* branches
```

## Skills

### jira-worker (443 lines) — Orchestrator
Full-cycle Jira task automation: Jira fetch → assess complexity → plan → review plan → implement → code review → UI review → commit → MR → deploy.

**Triggers:** Any Jira key (ARGO-XXXXX), "сделай задачу", "возьми тикет", "implement", "work on"
**Key features:**
- Adaptive complexity: SIMPLE (1-2 AC, no Figma) vs FULL (3+ AC, Figma, multi-module)
- User override: "быстро" forces SIMPLE, "полный цикл" forces FULL
- Artifacts in `docs/plans/ARGO-XXXXX/`, cleanup on command
- Uses `subagent-driven-development` (FULL) or `executing-plans` (SIMPLE)
- `figma:implement-design` for UI tasks when Figma URLs present
- Reads `.claude/ui-inventory.md` for component reuse rules

**Pipeline:**
```
FULL:  Parse → Fetch → Assess → Branch → Plan → Plan Review → Implement → Code Review → UI Review → Commit → MR → Deploy
SIMPLE: Parse → Fetch → Assess → Branch → Quick Plan → Implement → Code Review → UI Review → Commit → MR → Deploy
```

---

### jira-planner (239 lines) — Planning
Creates implementation plan and checklist from Jira task + Figma designs.

**Called by:** jira-worker Step 4 (not standalone)
**Key features:**
- **Figma-first mode:** when Jira description is empty, builds plan from Figma mockups
- **Component Discovery (Step 3):** reads `.claude/ui-inventory.md` to find reusable components, SCSS mixins, design tokens before brainstorming
- Wraps `brainstorming` + `writing-plans` superpowers skills
- Generates `plan.md` (FULL) and `checklist.md` (always)

---

### jira-plan-reviewer (168 lines) — Plan Review
Automatic review of implementation plans against Jira AC, codebase patterns, and Figma.

**Called by:** jira-worker Step 5 (FULL mode only, as subagent)
**Checks:** AC coverage, codebase alignment, Figma coverage, technical soundness, risk assessment
**Verdict:** APPROVED or NEEDS_REVISION (no re-review loop)

---

### jira-code-reviewer (220 lines) — Code Review
Reviews code for plan compliance, Angular quality, component reuse, and project conventions.

**Triggers:** "проверь код", "code review", "ревью кода" (standalone) OR called by jira-worker Step 7
**Key features:**
- **Standalone mode:** detects branch → finds plan in `docs/plans/` → reviews against it. No plan? Reviews diff only
- **Component Reuse check (Section C):** reads `.claude/ui-inventory.md`, flags custom UI that duplicates shared components
- Uses Angular skills reference: angular-component, angular-signals, angular-di, angular-http, angular-routing
- Severity: HIGH (auto-fix), MED (ask user), LOW (informational)

---

### jira-ui-reviewer (303 lines) — UI Testing
Functional + visual UI testing via agent-browser and Figma MCP comparison.

**Triggers:** "проверь UI", "ui review", "протестируй UI" (standalone) OR called by jira-worker Step 8
**Key features:**
- **Parallel subagents:** functional-tester (agent-browser, clicks/verifies) + visual-comparator (Figma screenshots comparison)
- Test planning via brainstorming → `ui-test-plan.md`
- Component reuse quality check (reads `.claude/ui-inventory.md`)
- Results in `ui-review.md` with screenshots

---

### scan-ui-inventory (174 lines) — Component Scanner
Scans project for shared components, SCSS mixins, design tokens → generates `.claude/ui-inventory.md`.

**Triggers:** "скан UI", "scan components", "обнови инвентарь", "сканируй компоненты"
**Key features:**
- Scans: shared/ui, shared/components, shared/dialogs, libs/*/components, scss/mixins, scss/variables
- Generates structured inventory file that all other skills reference
- Run once per project or after adding new shared components

---

### deploy (258 lines) — CI/CD Deployment
Triggers and monitors GitLab CI/CD pipelines for test/production deployment.

**Triggers:** "задеплой", "залей на тест", "deploy to test/prod", "check pipeline"
**Supports:** passport, community projects. Test and production environments.
**Features:** Pipeline monitoring, job retry, tag-based production releases.

---

### community-sync (276 lines) — Branch Sync
Distributes commits across multiple `community/*` branches with parallel cherry-pick, build verification, and deployment.

**Triggers:** "обновить ветки", "sync branches", "распространить коммит"
**Features:** Parallel batches (3 at a time), conflict resolution, build verification, tag-based prod deploy for specific branches.

---

## Project-Level Files

Each project using these skills should have:

| File | Purpose | Created by |
|------|---------|-----------|
| `.claude/ui-inventory.md` | UI components, mixins, tokens inventory | `scan-ui-inventory` skill |
| `docs/plans/ARGO-XXXXX/` | Per-task artifacts (plan, checklist, reviews) | `jira-planner` + reviewers |
| `CLAUDE.md` | Project conventions, path aliases, build commands | Manual |

## Integration with Superpowers

These skills use the following superpowers skills internally:
- `brainstorming` — idea exploration before planning
- `writing-plans` — structured implementation plans
- `executing-plans` — sequential plan execution (SIMPLE mode)
- `subagent-driven-development` — parallel task execution with review (FULL mode)
- `dispatching-parallel-agents` — parallel UI testing (functional + visual)
- `figma:implement-design` — 1:1 Figma-to-code for UI tasks

## How to Improve

Areas where these skills could be enhanced:
1. **Test generation** — no skill for auto-generating unit tests after implementation
2. **Accessibility review** — no a11y checks in UI reviewer
3. **Performance review** — no bundle size / lazy loading analysis
4. **Cross-project sync** — when passport and community share a feature, no coordination skill
5. **Rollback** — deploy skill has no rollback workflow
6. **Estimation** — no skill for task complexity estimation before taking a ticket
7. **Design system rules** — could integrate `figma:create-design-system-rules` into scan-ui-inventory
8. **Incremental inventory** — scan-ui-inventory regenerates from scratch; could diff and update incrementally
