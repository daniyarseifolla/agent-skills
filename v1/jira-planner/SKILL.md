---
name: jira-planner
description: Creates implementation plan and checklist for Jira tasks. Wraps brainstorming + writing-plans with Jira-specific context (AC, modules, Figma). Supports Figma-first mode when Jira description is empty. Called by jira-worker orchestrator, not independently.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata
---

# Jira Planner — Task Planning from Jira + Figma

Creates `plan.md` + `checklist.md` for a Jira task by wrapping brainstorming and writing-plans skills with Jira-specific context.

## Input

Called by jira-worker with these parameters:

```
ISSUE_KEY:       ARGO-XXXXX
SUMMARY:         Jira issue title
DESCRIPTION:     Jira issue body text
AC:              Acceptance criteria (list)
FIGMA_URLS:      Figma design URLs (may be empty)
PROJECT_TYPE:    passport | community
MODULES:         Affected modules with paths
COMPLEXITY:      simple | full
ARTIFACTS_DIR:   docs/plans/ARGO-XXXXX
```

## Step 1 — Detect Mode

Analyze inputs to determine planning approach:

```
Figma-first IF:
  - DESCRIPTION is empty/meaningless AND FIGMA_URLS is not empty
  - OR AC is empty AND FIGMA_URLS is not empty
  - OR DESCRIPTION contains only Figma link(s)

Standard IF:
  - DESCRIPTION has clear requirements or AC

Standard + Figma enrichment IF:
  - DESCRIPTION has requirements AND FIGMA_URLS is not empty
```

## Step 2 — Figma Extraction (if Figma-first or enrichment)

When Figma URLs are present:

1. For each Figma URL, extract fileKey and nodeId from the URL
2. Call `get_design_context` with fileKey and nodeId — returns code hints + screenshot
3. Call `get_screenshot` for additional frames if needed
4. Analyze screens:
   - Identify distinct pages/views
   - Identify components (cards, dialogs, lists, forms)
   - Identify states (empty, loading, error, hover, active)
   - Identify navigation flow between screens
5. If Figma-first mode: generate synthetic AC:

```markdown
## Derived Acceptance Criteria (from Figma)
- AC-F1: Page "/profile/saved" displays grid of selection cards
- AC-F2: Each card shows cover image, name, and post count
- AC-F3: "+Add" button opens dialog with name input and save button
- AC-F4: Card hover shows menu button with Edit/Delete options
- AC-F5: Empty state shows illustration and "No selections yet" message
```

## Step 3 — Component Discovery

**Always runs before brainstorming.** Find reusable components that match the task's UI needs.

### 3a. Load UI inventory

Check if the project has a UI inventory file:

```bash
# Check for UI inventory
cat .claude/ui-inventory.md 2>/dev/null
```

**If `.claude/ui-inventory.md` exists** → use it as the source of truth for available components, mixins, and design tokens. Skip 3b.

**If not** → fall back to scanning (3b).

### 3b. Fallback: scan project manually

Only if no inventory file found:

```bash
# Scan shared components
ls apps/*/src/app/shared/ui/ apps/*/src/app/shared/components/ apps/*/src/app/shared/dialogs/ 2>/dev/null

# Scan library components
ls libs/*/src/lib/components/ 2>/dev/null

# Scan SCSS mixins
grep -rn '@mixin' apps/*/src/scss/mixins/ 2>/dev/null | head -30

# Scan SCSS variables
grep -rn '^\$' apps/*/src/scss/variables/ 2>/dev/null | head -30
```

### 3c. Check Figma for design system components

If Figma URLs are present, use `figma:implement-design` skill guidance:
- Check if Figma frames use shared design system components
- Map Figma components to project components
- Note any design tokens (colors, spacing, radii) from Figma

### 3d. Output component map

For each AC item that involves UI, match against inventory:

```markdown
## Component Map
### Reuse existing:
- [UI need] → [component/mixin from inventory]
- ...

### Create new:
- [Component] (no existing match in inventory)
- ...

### SCSS:
- [Which variables/mixins to use from inventory]
```

## Step 4 — Brainstorming

**Always runs** (both simple and full mode).

Invoke `brainstorming` skill with focused context, **including component map from Step 3**:

```
Context for brainstorming:

Task: ARGO-{ISSUE_KEY} — {SUMMARY}
Type: {Bug/Feature}
Project: {PROJECT_TYPE}

Acceptance Criteria:
{AC or synthetic AC from Figma}

Affected Modules:
{MODULES with paths}

Figma Analysis (if available):
{screens, components, states from Step 2}

Component Map (from discovery):
{component map from Step 3}

Focus areas:
1. Which existing components/mixins to reuse? (MUST prefer existing over custom)
2. What new components genuinely needed?
3. What's the minimal approach to satisfy all AC?
4. Any risks or edge cases?
```

The brainstorming explores the codebase, identifies patterns, and produces an approach.

## Step 5 — Plan Generation

### Full Mode

Invoke `writing-plans` skill with brainstorming output:

```
Create implementation plan for ARGO-{ISSUE_KEY}.

{brainstorming output — approach, files, patterns}

Requirements:
- Each task = one logical commit
- Map every task to AC item(s)
- Include file paths (create/modify)
- Include build/lint verification steps
- Follow project conventions from CLAUDE.md
- Library code (libs/) is read-only
- Use yarn, not npm

Save to: {ARTIFACTS_DIR}/plan.md
```

After plan.md is generated, extract checklist:

**`{ARTIFACTS_DIR}/checklist.md`:**
```markdown
# Implementation Checklist — ARGO-XXXXX

## Tasks
- [ ] Task 1: [name] | AC: [AC-1, AC-2] | commit: `feat(ARGO-XXXXX): ...`
- [ ] Task 2: [name] | AC: [AC-3] | commit: `feat(ARGO-XXXXX): ...`
- [ ] Task 3: [name] | AC: [AC-4, AC-5] | commit: `feat(ARGO-XXXXX): ...`

## Verification
- [ ] yarn build — passes
- [ ] yarn lint — no new errors
- [ ] All AC items covered

## AC Coverage Map
| AC | Task(s) |
|----|---------|
| AC-1 | Task 1 |
| AC-2 | Task 1 |
| AC-3 | Task 2 |
| AC-4 | Task 3 |
| AC-5 | Task 3 |
```

### Simple Mode

Skip writing-plans. Generate checklist directly from brainstorming:

**`{ARTIFACTS_DIR}/checklist.md`:**
```markdown
# Implementation Checklist — ARGO-XXXXX

## Tasks
- [ ] Task 1: [name] | commit: `fix(ARGO-XXXXX): ...`
- [ ] yarn build — passes
- [ ] yarn lint — no new errors
```

No `plan.md` generated in simple mode.

## Output

| Artifact | Full Mode | Simple Mode |
|----------|-----------|-------------|
| `plan.md` | Yes | No |
| `checklist.md` | Yes | Yes |

Return to jira-worker:
```
PLANNING_COMPLETE: true
MODE: figma-first | standard | standard+figma
ARTIFACTS: [list of created files]
TASK_COUNT: N
```
