---
name: jira-worker
description: Full-cycle Jira task implementation for Angular/Nx projects. Use PROACTIVELY when user provides a Jira issue key (ARGO-10698), Jira URL, or says anything like "сделай задачу", "возьми тикет", "реализуй", "take this ticket", "implement this issue", "work on ARGO-XXX". Even if the user just pastes a Jira key without any context, this skill applies. Orchestrates specialized skills (jira-planner, jira-plan-reviewer, jira-code-reviewer, jira-ui-reviewer) through the complete pipeline from Jira fetch to deployment.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, Skill, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue, mcp__plugin_atlassian_atlassian__transitionJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot
---

# Jira Worker — Orchestrator

Pipeline: Jira → assess → plan → review plan → implement → review code → review UI → commit → MR → deploy.

Delegates to specialized skills at each stage. Adapts pipeline based on task complexity.

## Skill Ecosystem

| Skill | Role | Called by |
|-------|------|----------|
| **jira-worker** | Orchestrator | User (ARGO-XXXXX) |
| **jira-planner** | Planning (brainstorming + writing-plans + Figma) | jira-worker Step 4 |
| **jira-plan-reviewer** | Plan review (subagent) | jira-worker Step 5 (full only) |
| **jira-code-reviewer** | Code review (plan + Angular quality) | jira-worker Step 7 OR standalone |
| **jira-ui-reviewer** | UI testing (agent-browser + Figma) | jira-worker Step 8 OR standalone |

## Project Registry

Detect project from git remote at the START of the workflow.

| Field | passport | community |
|-------|----------|-----------|
| **Detect** | remote contains `ot4-passport-frontend` OR `apps/passport/` exists | remote contains `community` OR `apps/web/` exists |
| **GitLab path** | `argo-media%2F...%2Fot4-passport-frontend` | `argo-media%2F...%2Fcommunity` |
| **Base branch** | `develop` | `main` |
| **Branch prefix** | `feat/` | `feat/` |
| **App path** | `apps/passport/src/app` | `apps/web/src/app` |
| **Test env** | passport.maji.la | per-branch domains |
| **Dev port** | 4200 | 4200 |
| **Commands** | `yarn start` / `yarn build` / `yarn lint` | same |

**Module lookup:**

| Module | Keywords | passport path | community path |
|--------|----------|---------------|----------------|
| auth | auth, login, register, password | `app/auth/` | — |
| profile | profile, avatar, settings, my-world, saved | `app/profile/` | `app/profile/` |
| layout | layout, header, footer, sidebar, nav | `app/layout/` | `app/layout/` |
| shared | shared, pipe, directive, component | `app/shared/` | `app/shared/` |
| store | store, state, action, effect, reducer | `app/store/` | `app/store/` |
| core | core, service, guard, interceptor | `app/core/` | `app/core/` |
| community | community, feed, post, comment | — | `app/community/` |
| post | post, article, content | — | `app/post/` |
| subscribe | subscribe, subscription, payment | — | `app/subscribe/` |
| events | event, calendar | — | `app/events/` |

```bash
# Detection script
REMOTE=$(git remote get-url origin 2>/dev/null)
if [[ "$REMOTE" == *"ot4-passport-frontend"* ]]; then
  PROJECT_TYPE="passport"
elif [[ "$REMOTE" == *"community"* ]]; then
  PROJECT_TYPE="community"
else
  [ -d "apps/passport" ] && PROJECT_TYPE="passport"
  [ -d "apps/web" ] && PROJECT_TYPE="community"
fi
```

---

## Step 0 — Parse Input

Extract Jira issue key:
- Direct key: `ARGO-10698`
- URL: `https://....atlassian.net/browse/ARGO-10698` → extract `ARGO-10698`
- Pattern: `/([A-Z]+-\d+)/`

## Step 1 — Detect Project & Fetch Task

1. **Detect project** using detection script
2. Call `mcp__plugin_atlassian_atlassian__getJiraIssue`. Resolve cloudId via `getAccessibleAtlassianResources` or from `$JIRA_BASE_URL`
3. Extract: summary, description, acceptance criteria, subtasks, status, assignee
4. Look for Figma URLs in description (`figma.com/design/...`)
5. Build checklist from AC. If no explicit AC — derive from "Ожидаемый результат" / "Фактический результат" pattern
6. Identify affected modules from module lookup table
7. Look for credentials in description ("Пользователь:" pattern)

## Step 2 — Assess Complexity

Determine pipeline mode:

```
SIMPLE if:
  - User said "быстро" / "quick" / "простая задача"
  - OR (AC_count <= 2 AND module_count <= 1 AND no Figma URLs)

FULL otherwise.

User can always override:
  - "быстро" / "quick" → force SIMPLE
  - "полный цикл" / "full" → force FULL
```

Present summary and ASK for confirmation:

```
Project: [passport/community] (auto-detected)
Task: ARGO-XXXXX — [Summary]
Type: [Bug/Feature]  Status: [status]  Mode: [SIMPLE/FULL]
Modules: [list with paths]
AC:
  [ ] Item 1
  [ ] Item 2
Figma: [yes/no — URLs]
Credentials: [found/not found]
```

## Step 3 — Transition & Git Branch

### Transition
1. Call `getTransitionsForJiraIssue` to get available transitions
2. Find "In Progress" by name (IDs are dynamic)
3. Call `transitionJiraIssue` to move task
4. If already "В работе" — skip

### Git Branch
```bash
git fetch origin {base_branch}
```

- If current branch is already `{branch_prefix}ARGO-XXXXX` — stay on it
- If branch exists — ASK: use existing or create fresh?
- Otherwise:
  ```bash
  git checkout -b {branch_prefix}ARGO-XXXXX origin/{base_branch}
  git branch --unset-upstream
  ```

### Create artifacts directory
```bash
mkdir -p docs/plans/ARGO-XXXXX
```

---

## Step 4 — Planning (jira-planner)

Invoke `jira-planner` skill with context:

```
ISSUE_KEY:    ARGO-XXXXX
SUMMARY:      [from Jira]
DESCRIPTION:  [from Jira]
AC:           [acceptance criteria]
FIGMA_URLS:   [URLs from description]
PROJECT_TYPE: [passport/community]
MODULES:      [affected modules with paths]
COMPLEXITY:   [SIMPLE/FULL]
ARTIFACTS_DIR: docs/plans/ARGO-XXXXX
```

**jira-planner** will:
- Run brainstorming (always)
- Detect if Figma-first needed (empty description → build plan from mackets)
- In FULL mode: run writing-plans → generate `plan.md` + `checklist.md`
- In SIMPLE mode: generate `checklist.md` directly

**Wait for:** `plan.md` (full only) and `checklist.md` in artifacts dir.

---

## Step 5 — Plan Review (jira-plan-reviewer) — FULL MODE ONLY

Skip in SIMPLE mode.

Invoke `jira-plan-reviewer` via Agent (subagent) with:

```
ISSUE_KEY:      ARGO-XXXXX
SUMMARY:        [from Jira]
DESCRIPTION:    [from Jira]
AC:             [acceptance criteria]
FIGMA_URLS:     [URLs]
PROJECT_TYPE:   [passport/community]
MODULES:        [modules]
PLAN_PATH:      docs/plans/ARGO-XXXXX/plan.md
CHECKLIST_PATH: docs/plans/ARGO-XXXXX/checklist.md
```

**If APPROVED** → proceed to Step 6.

**If NEEDS_REVISION:**
1. Show review issues to user
2. Update `plan.md` and `checklist.md` based on feedback
3. Do NOT re-run reviewer (avoid loops)
4. Proceed to Step 6

---

## Step 6 — Implementation

### FULL mode → subagent-driven-development
Use `superpowers:subagent-driven-development` with `checklist.md`:
- Fresh subagent per task
- Two-stage review per task (spec + quality)
- Sequential by default, `dispatching-parallel-agents` for truly independent groups

### SIMPLE mode → executing-plans
Use `superpowers:executing-plans` with `checklist.md`:
- Sequential execution
- Lightweight review checkpoints

### UI Implementation — use `figma:implement-design` skill
**When Figma URLs are present**, each UI task MUST use `figma:implement-design` guidance:
1. Call `get_design_context` for the relevant Figma frame before writing any UI code
2. Map Figma components to project shared components (from jira-planner's Component Map)
3. Extract exact design tokens: colors, spacing, radii, shadows, typography from Figma
4. Implement with 1:1 visual fidelity to the design

### Component Reuse Rules (CRITICAL for UI quality)
**Read `.claude/ui-inventory.md` first** (if exists). It lists all reusable components, SCSS mixins, and design tokens for this project.

Rules:
- **MUST reuse existing components** from inventory instead of writing custom UI
- **MUST use SCSS mixins** from inventory for buttons, dialogs, typography
- **MUST use design token variables** — NEVER hardcode hex/named colors
- If no inventory file exists, scan `shared/`, `libs/`, and `scss/mixins/` manually

### Key principles (apply to both modes)
- **Library code is read-only** (`libs/community/`, `libs/core/`)
- Package manager: **yarn**
- Path aliases: `@app/*`, `@core/*`, `@shared/*`, `@env/*`, `@outlaw/*`
- Read CLAUDE.md for full conventions
- Run `yarn build` and `yarn lint` after implementation

### Common patterns
**Snackbar:** passport → `@app/shared/services/snackbar.service`, community → `@outlaw/community`
**Clipboard:** `@outlaw/core` ClipboardService — notification commented out, handle separately
**CSS centering with sidebar:** `left: calc(50% + var(--sidebar-width, 0px) / 2)`

---

## Step 7 — Code Review (jira-code-reviewer)

Invoke `jira-code-reviewer` via Agent (subagent) with:

```
ISSUE_KEY:      ARGO-XXXXX
PLAN_PATH:      docs/plans/ARGO-XXXXX/plan.md (null in SIMPLE)
CHECKLIST_PATH: docs/plans/ARGO-XXXXX/checklist.md
PROJECT_TYPE:   [passport/community]
BASE_BRANCH:    [develop/main]
```

**If APPROVED** → proceed to Step 8.

**If HAS_ISSUES:**
- HIGH issues → auto-fix (edit, rebuild, re-lint)
- MED issues → show to user, ask whether to fix
- LOW issues → show for awareness
- After fixes → proceed (no re-review loop)

---

## Step 8 — UI Review (jira-ui-reviewer)

Invoke `jira-ui-reviewer` with:

```
ISSUE_KEY:      ARGO-XXXXX
CHECKLIST_PATH: docs/plans/ARGO-XXXXX/checklist.md
FIGMA_URLS:     [URLs]
PROJECT_TYPE:   [passport/community]
DEV_PORT:       [4200/6200]
CREDENTIALS:    [from Jira or ask user]
ARTIFACTS_DIR:  docs/plans/ARGO-XXXXX
```

**jira-ui-reviewer** will:
- Create test plan (brainstorming)
- Dispatch parallel agents (functional-tester + visual-comparator)
- Generate `ui-test-plan.md` + `ui-review.md`

**If APPROVED** → proceed to Step 9.

**If HAS_ISSUES:**
- Fix what's possible (code changes for visual mismatches)
- Re-take screenshots for fixed items
- Show remaining issues to user
- Proceed to Step 9

---

## Step 9 — Commit & Push & MR

### Build verification
```bash
yarn build
```

### Commit
- Bug fix: `fix(ARGO-XXXXX): description`
- Feature: `feat(ARGO-XXXXX): description`
- Commit message in English, concise
- No Co-Authored-By

```bash
git add <specific files>
git commit -m "$(cat <<'EOF'
fix(ARGO-XXXXX): short description

- bullet point details
EOF
)"
```

### Push & MR
```bash
git push -u origin {branch_prefix}ARGO-XXXXX
```

Create MR via **glab** (NOT gh):
```bash
glab mr create \
  --title "fix(ARGO-XXXXX): short description" \
  --target-branch {base_branch} \
  --description "$(cat <<'EOF'
## Summary
- Bullet point 1
- Bullet point 2
EOF
)" --no-editor
```

MR description: **only Summary section**.

## Step 10 — Deploy to Test (Optional)

ASK user: "Deploy to test environment?"

If yes → use **deploy** skill with branch name and target `test`.

After deploy, transition Jira to "Ready for Test":
1. `getTransitionsForJiraIssue` → find "Ready for Test"
2. `transitionJiraIssue`

## Step 11 — Cleanup (On User Command)

Triggered by: "почисти" / "cleanup" / "clean" / "убери планы"

```bash
rm -rf docs/plans/ARGO-XXXXX/
git add -u docs/plans/
git commit -m "chore(ARGO-XXXXX): cleanup planning artifacts"
```

**NOT automatic** — user triggers manually. Task may be returned after deploy.

---

## Error Handling

- **Jira fetch fails** → verify issue key and MCP connection (`/mcp`)
- **Project detection fails** → ask user which project
- **Git conflicts** → show conflicts, ask user
- **Build fails** → show errors, fix before proceeding
- **Lint fails on our files** → auto-fix; if can't — show errors
- **Pre-existing lint warnings** → ignore (exit code 1 normal)
- **Dev server won't start** → check port: `lsof -i :4200`
- **agent-browser fails** → `agent-browser close` then retry, or skip UI review
- **glab not installed** → `brew install glab`
- **glab auth expired** → tell user to run `glab auth login`
- **Skill not found** → fall back to inline execution (old behavior)

---

## Pipeline Summary

```
FULL MODE:
  Step 0:  Parse Input
  Step 1:  Fetch Jira + Detect Project
  Step 2:  Assess Complexity → FULL
  Step 3:  Transition + Git Branch + mkdir docs/plans/ARGO-XXXXX
  Step 4:  jira-planner (brainstorming → writing-plans → Figma)
           → plan.md + checklist.md
  Step 5:  jira-plan-reviewer (subagent)
           → plan-review.md
  Step 6:  subagent-driven-development (using checklist.md)
  Step 7:  jira-code-reviewer (subagent)
           → code-review.md → auto-fix HIGH
  Step 8:  jira-ui-reviewer (parallel agents)
           → ui-test-plan.md + ui-review.md → fix issues
  Step 9:  Commit → Push → MR
  Step 10: Deploy (optional)
  Step 11: Cleanup (on command)

SIMPLE MODE:
  Steps 0-3: Same
  Step 4s: jira-planner (brainstorming → checklist only)
           → checklist.md
  Step 5:  SKIP
  Step 6:  executing-plans (using checklist.md)
  Step 7:  jira-code-reviewer (diff-based, lightweight)
           → code-review.md
  Step 8:  jira-ui-reviewer (functional only, no Figma)
           → ui-review.md
  Steps 9-11: Same
```

## Example

```
User: ARGO-10743

→ Step 0: Parse → key: ARGO-10743
→ Step 1: Detect: passport | Fetch Jira → "Passport. Saved selections"
          Type: Feature  Modules: profile, layout
          AC: 5 items  Figma: yes (3 URLs)
→ Step 2: Assess → FULL (5 AC, 2 modules, Figma)
→ Step 3: Transition → "In Progress" | Branch: feat/ARGO-10743
→ Step 4: jira-planner → plan.md (7 tasks) + checklist.md
→ Step 5: jira-plan-reviewer → APPROVED
→ Step 6: subagent-driven-development → 7/7 tasks done
→ Step 7: jira-code-reviewer → HAS_ISSUES (1 HIGH) → auto-fix → done
→ Step 8: jira-ui-reviewer → 2 agents parallel
          functional: 8/8 PASS | visual: 4/5 MATCH (1 border-radius)
          → fix border-radius → done
→ Step 9: Commit, push, glab mr create → MR !45
→ Step 10: Deploy to test? → yes → deploy skill → "Ready for Test"
```

```
User: ARGO-10800 быстро

→ Step 0: Parse → key: ARGO-10800
→ Step 1: Detect: community | Fetch → "Fix padding on tabs"
          Type: Bug  AC: 1 item  No Figma
→ Step 2: Assess → SIMPLE (user said "быстро" + 1 AC)
→ Step 3: Transition + Branch
→ Step 4s: jira-planner → checklist.md (1 task)
→ Step 6: executing-plans → done
→ Step 7: jira-code-reviewer → APPROVED
→ Step 8: jira-ui-reviewer → functional only → PASS
→ Step 9: Commit, push, MR
```
