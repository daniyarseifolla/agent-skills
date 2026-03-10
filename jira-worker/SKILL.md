---
name: jira-worker
description: Full-cycle Jira task implementation for Angular/Nx projects. Use PROACTIVELY when user provides a Jira issue key (ARGO-10698), Jira URL, or says anything like "сделай задачу", "возьми тикет", "реализуй", "take this ticket", "implement this issue", "work on ARGO-XXX". Even if the user just pastes a Jira key without any context, this skill applies. Covers the complete pipeline from Jira fetch through implementation to MR creation and deployment.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue, mcp__plugin_atlassian_atlassian__transitionJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot
---

# Jira Worker — Full-Cycle Task Implementation

Automated pipeline: Jira → analysis → branch → implement → build → lint → browser test → commit → push → MR → deploy.

## Project Registry

Detect project from git remote at the START of the workflow. All subsequent steps use the matched config.

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

**Module lookup** — match Jira task keywords to find affected code areas:

| Module | Keywords | passport path | community path |
|--------|----------|---------------|----------------|
| auth | auth, login, register, password | `app/auth/` | — |
| profile | profile, avatar, settings, my-world | `app/profile/` | `app/profile/` |
| layout | layout, header, footer, sidebar, nav | `app/layout/` | `app/layout/` |
| shared | shared, pipe, directive, component | `app/shared/` | `app/shared/` |
| store | store, state, action, effect, reducer | `app/store/` | `app/store/` |
| core | core, service, guard, interceptor | `app/core/` | `app/core/` |
| community | community, feed, post, comment | — | `app/community/` |
| post | post, article, content | — | `app/post/` |
| subscribe | subscribe, subscription, payment | — | `app/subscribe/` |
| events | event, calendar | — | `app/events/` |

Paths are relative to the project's `app_path`. Libraries (`libs/community/`, `libs/core/`) are shared across projects.

```bash
# Detection script
REMOTE=$(git remote get-url origin 2>/dev/null)
if [[ "$REMOTE" == *"ot4-passport-frontend"* ]]; then
  PROJECT_TYPE="passport"
elif [[ "$REMOTE" == *"community"* ]]; then
  PROJECT_TYPE="community"
else
  # Fallback: check directory structure
  [ -d "apps/passport" ] && PROJECT_TYPE="passport"
  [ -d "apps/web" ] && PROJECT_TYPE="community"
fi
```

## Step 0 — Parse Input

Extract Jira issue key from user input:
- Direct key: `ARGO-10698`
- URL: `https://....atlassian.net/browse/ARGO-10698` → extract `ARGO-10698`
- Pattern: `/([A-Z]+-\d+)/`

## Step 1 — Detect Project & Fetch Task

1. **Detect project** using the detection script above
2. Call `mcp__plugin_atlassian_atlassian__getJiraIssue` with `cloudId: "argomedia.atlassian.net"`
3. Extract: summary, description, acceptance criteria, subtasks, status, assignee
4. Look for Figma URLs in description (`figma.com/design/...`)
5. Build checklist from AC. If no explicit AC — derive from "Ожидаемый результат" / "Фактический результат" pattern (common in bug reports)
6. Identify affected modules by matching keywords from the detected project's module lookup table
7. Present summary and ASK for confirmation before proceeding:

```
Project: [passport/community] (auto-detected)
Task: ARGO-XXXXX — [Summary]
Type: [Bug/Feature]  Status: [status]
Modules: [list with paths]
AC Checklist:
  [ ] Item 1
  [ ] Item 2
Figma: [yes/no]
```

## Step 2 — Transition Task Status

1. Call `getTransitionsForJiraIssue` to get available transitions
2. Find "In Progress" by name (transition IDs vary between projects — always look up dynamically)
3. Call `transitionJiraIssue` to move task
4. If already "В работе" — skip. If fails — warn but continue

## Step 3 — Git Branch

```bash
git fetch origin {base_branch}
```

- If current branch is already `{branch_prefix}ARGO-XXXXX` — stay on it
- If branch exists — ASK: use existing or create fresh?
- Otherwise: `git checkout -b {branch_prefix}ARGO-XXXXX origin/{base_branch}`

## Step 4 — Implement

### Key principles

- **Library code is read-only** (`libs/community/`, `libs/core/`) — these are git submodules shared across projects. Modifying them requires a separate MR in the library repo and a submodule pointer update. Instead, use output events from library components and handle them in the app layer.
- Package manager: **yarn** (the lockfile is `yarn.lock`, using npm creates conflicts)
- Path aliases: `@app/*`, `@core/*`, `@shared/*`, `@env/*`, `@outlaw/*`
- Read CLAUDE.md in project root for full conventions

### Implementation workflow
1. Read existing relevant files BEFORE making changes
2. Search for similar patterns in codebase (grep for related services, events, components)
3. Check for **duplicate implementations** of the same thing (e.g., app-level vs lib-level SnackbarService) — use the correct one for the current context
4. Implement minimal changes to satisfy AC
5. Run `yarn build` — verify build passes
6. Run `yarn lint` — ignore pre-existing warnings, only fix NEW errors from changed files

### Common patterns

**Snackbar/Toast:**
- In passport app: `SnackbarService` from `@app/shared/services/snackbar.service`
- In community app: `SnackbarService` from `@outlaw/community`
- In library context: emit output event, handle in app component

**Clipboard:**
- `ClipboardService` from `@outlaw/core` — notification is commented out in the service, must handle separately in the app

**CSS centering with sidebar:**
- `position: fixed` with `left: calc(50% + var(--sidebar-width, 0px) / 2)` for proper centering when sidebar is present

## Step 5 — Browser Testing (Hybrid)

### 5a. Start dev server if needed

```bash
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200 2>/dev/null)
```
- 200 → server running, proceed
- Otherwise → `yarn start` (run_in_background), poll every 3s, max 60s

### 5b. Authentication

Pages under protected routes require login. Login flow:
```bash
agent-browser open http://localhost:4200/{protected_page}
# Will redirect to /auth/login
agent-browser snapshot -i                    # Find login fields
agent-browser fill @e1 "<nickname>"          # From Jira task description
agent-browser click <next_button>            # Click Next
# Wait for password field
agent-browser fill <password_field> "<pwd>"  # From Jira task description
agent-browser click <login_button>           # Click Login
# Wait 3s for redirect
```

**Credentials** are usually in the Jira task description under "Пользователь:" pattern.

### 5c. Testing
- Use CSS selectors for precise targeting: `agent-browser click "button[data-test='btn-post-share']>>nth=0"`
- `agent-browser snapshot -i` for interactive elements with refs
- **Clipboard API doesn't work** in headless browser — expect `NotAllowedError`, this is normal
- After clicking, check DOM: `agent-browser eval "document.querySelector('...')?.textContent"`
- For visual checks: `agent-browser screenshot /tmp/test.png` then `Read` the image

### 5d. Troubleshooting
- **Changes not reflected**: `touch <file>` to trigger rebuild, wait 5s, then `agent-browser reload`
- **Element not found in snapshot**: try CSS selector directly instead of @ref
- **Multiple matching elements**: use `>>nth=0` suffix for first match
- Close browser when done: `agent-browser close`

### 5e. Results
```
Browser Testing Results:
  [PASS] AC item 1 — verified via DOM
  [ASK]  AC item 2 — screenshot shown
  [FAIL] AC item 3 — fix and re-test
```

## Step 6 — Commit & Push

### Build verification

Before committing, verify the build passes. Pushing broken code means force-push later, which clutters pipeline history:
```bash
yarn build
```

### Commit
- Bug fix: `fix(ARGO-XXXXX): description`
- Feature: `feat(ARGO-XXXXX): description`
- Commit message in English, concise
- No Co-Authored-By (user preference)

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
git push origin {branch_prefix}ARGO-XXXXX
```

Create MR via **glab** (GitLab CLI, not gh — this is a GitLab repo):
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

MR description: **only Summary section**. No Test plan, no Changes section.

If `glab` not installed: `brew install glab && glab auth login`
If not authenticated: tell user to run `glab auth login` and wait.

## Step 7 — Deploy to Test (Optional)

After MR is created, ASK user: "Deploy to test environment?"

If yes — use the **deploy** skill. Provide it with:
- Branch name (the feature branch)
- Target: `test` (gcp:test job)
- Pipeline source: `push`

After successful deploy, transition Jira task to "Ready for Test":
1. Call `getTransitionsForJiraIssue` to get available transitions
2. Find transition containing "Ready for Test" or "Готово к тестированию" by name
3. Call `transitionJiraIssue`
4. If already in that status — skip

## Error Handling

- **Jira fetch fails** → verify issue key and MCP connection (`/mcp` to reconnect)
- **Project detection fails** → ask user which project this is
- **Git conflicts** → show conflicts, ask user
- **Build fails** → show errors, fix before proceeding
- **Lint fails on our files** → auto-fix; if can't — show errors
- **Pre-existing lint warnings** → ignore (exit code 1 from warnings is normal)
- **Dev server won't start** → check port: `lsof -i :4200`
- **agent-browser fails** → `agent-browser close` then retry, or fallback to manual testing
- **glab not installed** → `brew install glab`
- **glab auth expired** → 401 errors from API calls → tell user to run `glab auth login`

## Example

```
User: ARGO-10738

→ Step 0: Parse → key: ARGO-10738
→ Step 1: Detect project: community (remote contains "community")
          Fetch Jira → "Community. Постоянные ссылки на профиль"
          Type: Feature  Status: To Do
          Modules: profile (apps/web/src/app/profile/), core (apps/web/src/app/core/)
          AC: [ ] Profile links always visible  [ ] Remove feature flag
          → ASK user confirmation

→ Step 2: Transition → "In Progress"
→ Step 3: git checkout -b feat/ARGO-10738 origin/main
→ Step 4: Implement changes, yarn build OK, yarn lint OK
→ Step 5: Browser test → 2/2 PASS
→ Step 6: Commit, push, glab mr create → MR !1234
→ Step 7: Deploy to test? → (uses deploy skill)
```
