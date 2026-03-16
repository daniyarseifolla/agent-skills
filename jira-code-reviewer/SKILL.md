---
name: jira-code-reviewer
description: Reviews code against implementation plan and Angular best practices. Works standalone ("проверь код", "code review", "ревью кода") or called by jira-worker. Uses Angular skills for quality checks. Generates code-review.md with verdict.
allowed-tools: Bash(*), Read, Glob, Grep, Agent
---

# Jira Code Reviewer — Plan Compliance + Quality

Reviews implementation code for plan compliance, Angular best practices, and project conventions. Can run standalone or as part of jira-worker pipeline.

## Triggers

### From jira-worker (automatic)
Called at Step 7 with full context (plan, checklist, project info).

### Standalone (independent)
User says: "проверь код", "code review", "ревью кода", "review code", "проверь изменения"

**Standalone detection:**
1. Get current branch: `git branch --show-current` → `feat/ARGO-XXXXX`
2. Extract issue key from branch name
3. Look for `docs/plans/ARGO-XXXXX/`
4. If found → use plan.md + checklist.md for plan compliance
5. If not found → skip plan compliance, do quality review only
6. Detect base branch from project type (develop for passport, main for community)

## Input

### From jira-worker
```
ISSUE_KEY:       ARGO-XXXXX
PLAN_PATH:       docs/plans/ARGO-XXXXX/plan.md (may be null in simple mode)
CHECKLIST_PATH:  docs/plans/ARGO-XXXXX/checklist.md
PROJECT_TYPE:    passport | community
BASE_BRANCH:     develop | main
```

### Standalone (auto-detected)
```
ISSUE_KEY:       extracted from branch name
PLAN_PATH:       auto-discovered or null
CHECKLIST_PATH:  auto-discovered or null
PROJECT_TYPE:    detected from git remote
BASE_BRANCH:     detected from project type
```

## Review Process

### Step 1 — Gather Changes

```bash
# Get all changed files
git diff origin/{BASE_BRANCH}...HEAD --name-only

# Get full diff
git diff origin/{BASE_BRANCH}...HEAD

# Get commit log
git log origin/{BASE_BRANCH}..HEAD --oneline
```

### Step 2 — Dispatch Review Subagent

```
Agent tool (general-purpose):
  description: "Code review for ARGO-XXXXX"
  prompt: |
    You are reviewing code changes for ARGO-{ISSUE_KEY}.

    ## Changed Files
    {list of changed files}

    ## Full Diff
    {git diff output}

    ## Plan (if available)
    {content of plan.md or "No plan available — skip plan compliance"}

    ## Checklist (if available)
    {content of checklist.md or "No checklist available — skip plan compliance"}

    ## Review Areas

    ### A. Plan Compliance (skip if no plan)
    For each task in checklist:
    - Is it implemented?
    - Are all planned files touched?
    - Any deviations? (note if deviation is an improvement)

    Check for out-of-scope changes:
    - Files modified that aren't in the plan
    - Features added that aren't in any AC

    ### B. Angular Quality
    Review each changed file against Angular best practices:

    **Components (angular-component):**
    - Standalone components (no NgModule)
    - OnPush change detection
    - Signal-based inputs: input(), input.required()
    - Signal-based outputs: output()
    - Host bindings via host: {} in @Component

    **Signals (angular-signals):**
    - signal() for mutable state
    - computed() for derived state
    - effect() only for side effects (logging, external sync)
    - No manual subscribe when signals suffice

    **Dependency Injection (angular-di):**
    - inject() function (not constructor injection)
    - providedIn: 'root' for singleton services
    - Correct provider scope

    **HTTP (angular-http):**
    - httpResource() / resource() for signal-based fetching (if applicable)
    - Interceptors properly configured
    - Error handling present

    **Routing (angular-routing):**
    - Lazy loading with loadComponent
    - Functional guards (not class-based)
    - Route parameters via signals

    ### C. Component Reuse
    Check that implementation reuses existing project components instead of writing custom UI.

    **First, read the project UI inventory:**
    ```
    cat .claude/ui-inventory.md 2>/dev/null
    ```

    If the inventory file exists, use it as the source of truth:
    - For each new UI element in the diff, check if the inventory lists a reusable component
    - For each custom SCSS button/dialog/form style, check if the inventory lists a mixin
    - For each hardcoded color value, check if the inventory lists a design token variable

    If no inventory file, scan shared/components/ and scss/mixins/ manually.

    **Severity:**
    - Flag as HIGH if hardcoded colors are used instead of SCSS variables
    - Flag as MED if a custom component duplicates an existing shared one
    - Flag as MED if custom button/dialog styles used instead of available mixins

    ### D. Project Conventions
    - Library code (libs/) NOT modified
    - Correct SnackbarService used (app vs community)
    - Path aliases: @app/*, @core/*, @shared/*, @env/*
    - SCSS via variables ($text-color, $block-color) and mixins, no hardcoded colors
    - takeUntilDestroyed() on all subscriptions
    - No memory leaks (unsubscribed observables)
    - Package manager: yarn (no npm traces)

    ### E. General Quality
    - No unused imports
    - No console.log left in production code
    - Error handling where needed
    - Meaningful variable/method names
    - No security vulnerabilities (XSS, injection)

    ## Output Format

    ```markdown
    # Code Review — ARGO-XXXXX

    ## Plan Compliance
    - [x] Task 1: [name] — implemented as planned
    - [x] Task 2: [name] — minor deviation: [description] (improvement)
    - [ ] Task 3: [name] — missing: [what's missing]

    ## Out of Scope Changes
    - [file:line — description] or "None detected"

    ## Quality Issues
    - [HIGH] file.ts:line — description (must fix)
    - [MED] file.ts:line — description (should fix)
    - [LOW] file.ts:line — description (suggestion)

    ## Strengths
    - [Notable good practices observed]

    ## Verdict: APPROVED | HAS_ISSUES
    [Justification]
    ```

    Severity guide:
    - HIGH: Will cause bugs, broken build, memory leaks, security issues
    - MED: Missing best practices, potential issues under edge cases
    - LOW: Style suggestions, minor improvements
```

### Step 3 — Process Results

Save subagent output to `docs/plans/ARGO-XXXXX/code-review.md` (if plan dir exists) or print to console (standalone without plan dir).

### If APPROVED
Return to jira-worker: `CODE_REVIEW_RESULT: APPROVED`

### If HAS_ISSUES
Return to jira-worker:
```
CODE_REVIEW_RESULT: HAS_ISSUES
HIGH_ISSUES: [list with file:line]
MED_ISSUES: [list with file:line]
```

**jira-worker then:**
- HIGH issues → auto-fix (edit files, rebuild, re-lint)
- MED issues → show to user, ask whether to fix
- LOW issues → show for awareness, don't block
- After fixes → does NOT re-run full review (avoid loops)

## Standalone Output

When called independently (no jira-worker context):

1. Print review to console with formatted markdown
2. If `docs/plans/ARGO-XXXXX/` exists → also save to `code-review.md`
3. If HIGH issues found → ask user: "Fix automatically?"
4. If user says yes → fix and show diff
