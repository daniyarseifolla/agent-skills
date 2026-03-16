---
name: jira-ui-reviewer
description: Functional and visual UI review using agent-browser and Figma MCP. Works standalone ("проверь UI", "ui review", "протестируй UI", "проверь интерфейс") or called by jira-worker. Dispatches parallel subagents for functional testing and visual Figma comparison. Generates ui-test-plan.md and ui-review.md.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot, mcp__plugin_figma_figma__get_metadata
---

# Jira UI Reviewer — Functional + Visual Testing

Tests UI through agent-browser (functional) and compares with Figma designs (visual) using parallel subagents.

## Triggers

### From jira-worker (automatic)
Called at Step 8 with full context.

### Standalone (independent)
User says: "проверь UI", "ui review", "протестируй UI", "проверь интерфейс", "test UI", "visual review"

**Standalone detection:**
1. Get current branch → extract ARGO-XXXXX
2. Look for `docs/plans/ARGO-XXXXX/checklist.md` → AC items for test cases
3. If no plan → ask user: "What pages/features should I test?"
4. Detect dev server: check ports 4200, 6200
5. Look for Figma URLs in plan.md or ask user

## Input

### From jira-worker
```
ISSUE_KEY:       ARGO-XXXXX
CHECKLIST_PATH:  docs/plans/ARGO-XXXXX/checklist.md
FIGMA_URLS:      Figma design URLs (may be empty)
PROJECT_TYPE:    passport | community
DEV_PORT:        4200 | 6200
CREDENTIALS:     { nickname, password } (from Jira description)
ARTIFACTS_DIR:   docs/plans/ARGO-XXXXX
```

### Standalone (auto-detected)
```
ISSUE_KEY:       from branch name
CHECKLIST_PATH:  auto-discovered or null
FIGMA_URLS:      from plan.md or asked
DEV_PORT:        auto-detected (curl localhost:4200/6200)
CREDENTIALS:     asked if needed
ARTIFACTS_DIR:   docs/plans/ARGO-XXXXX or null
```

## Step 1 — Dev Server Check

```bash
# Check if dev server is running
for port in 4200 6200; do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo "Server running on port $port"
    break
  fi
done
```

If not running:
- Ask user: "Dev server not running. Start with `yarn start`?"
- Or start in background: `yarn start` (run_in_background), poll every 3s

## Step 2 — Test Planning (brainstorming)

Analyze inputs and create test plan:

### Functional Tests (from AC/checklist)
Map each AC item to a testable UI action:

```markdown
## Functional Tests
- F1: Navigate to /profile/saved → page loads, header visible
- F2: Click "+Add" button → dialog opens with name input
- F3: Fill name "Test", click Save → new card appears in grid
- F4: Click card menu → dropdown with Edit and Delete options
- F5: Click Edit → dialog with pre-filled name
- F6: Click Delete → card removed from grid
- F7: Click card body → navigates to detail page /profile/saved/:id
- F8: Click "< Saved" breadcrumb → returns to list
```

### Visual Tests (from Figma)
For each Figma frame, create a comparison case:

```markdown
## Visual Tests
- V1: Selections list page — compare with Figma frame "Saved List"
- V2: Add dialog — compare with Figma frame "Add Selection Dialog"
- V3: Card hover state — compare with Figma frame "Card Hover"
- V4: Empty state — compare with Figma frame "Empty Saved"
- V5: Detail page — compare with Figma frame "Selection Detail"
```

Save to `{ARTIFACTS_DIR}/ui-test-plan.md` (if artifacts dir exists).

## Step 3 — Dispatch Parallel Subagents

Use `dispatching-parallel-agents` pattern to run functional and visual tests simultaneously.

### Agent "functional-tester"

```
Agent tool (general-purpose):
  description: "Functional UI test for ARGO-XXXXX"
  prompt: |
    You are testing UI functionality using agent-browser.

    ## Test Cases
    {F1-F8 from test plan}

    ## Setup
    - Dev server: http://localhost:{DEV_PORT}
    - Credentials: nickname={nickname}, password={password}

    ## Instructions

    1. Open the dev server URL
    2. If redirected to login — authenticate:
       - Fill nickname field, click Next (may need JS: nativeInputValueSetter + dispatchEvent)
       - Fill password field, click Login
       - Wait for redirect

    3. For each test case:
       a. Navigate to the target page
       b. Perform the action (click, fill, etc.)
       c. Verify the expected result via DOM inspection
       d. Take screenshot: agent-browser screenshot /tmp/ARGO-XXXXX-F{N}.png
       e. Record PASS/FAIL with details

    ## Browser Tips
    - Use `agent-browser snapshot -i` for interactive elements with refs
    - Use CSS selectors when @refs are ambiguous: `agent-browser click "button.add-button"`
    - For Angular inputs, use nativeInputValueSetter pattern:
      ```
      agent-browser eval "
        const input = document.querySelector('input');
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(input, 'value');
        input.dispatchEvent(new Event('input', { bubbles: true }));
      "
      ```
    - After changes, wait 2s then `agent-browser snapshot -i` to get fresh refs
    - For multiple matching elements: use `>>nth=0` suffix
    - Clipboard API will fail in headless — this is expected

    ## Output Format
    ```
    FUNCTIONAL_TEST_RESULTS:
    - F1: PASS | Selections list loads, 2 cards visible
    - F2: PASS | Dialog opens with name input and Save button
    - F3: PASS | Card "Test" created, appears in grid
    - F4: FAIL | Menu button opens edit dialog directly, no dropdown
    - F5: PASS | Edit dialog shows pre-filled name
    ...
    SCREENSHOTS: /tmp/ARGO-XXXXX-F1.png, /tmp/ARGO-XXXXX-F2.png, ...
    PASS_COUNT: 7/8
    ```

    Close browser when done: `agent-browser close`
```

### Agent "visual-comparator" (only if Figma URLs provided)

```
Agent tool (general-purpose):
  description: "Visual Figma comparison for ARGO-XXXXX"
  prompt: |
    You are comparing the implemented UI with Figma designs.

    ## Comparison Cases
    {V1-V5 from test plan}

    ## Figma URLs
    {FIGMA_URLS with frame names}

    ## Instructions

    For each comparison case:

    1. Get Figma screenshot:
       - Call get_screenshot or get_design_context for the frame
       - Note key visual elements: layout, spacing, colors, typography, components

    2. Get app screenshot:
       - Open http://localhost:{DEV_PORT}/{page_url}
       - Navigate to the correct state
       - `agent-browser screenshot /tmp/ARGO-XXXXX-V{N}-app.png`

    3. Compare (descriptive, not pixel-perfect):
       - Layout: grid, flex, positioning match?
       - Spacing: margins, paddings approximately correct?
       - Colors: match design tokens or hex values?
       - Typography: font sizes, weights similar?
       - Components: all elements present?
       - States: correct state rendered?
       - Border radius, shadows, hover effects?

    4. Check component reuse quality:
       - Read `.claude/ui-inventory.md` if it exists — use as source of truth
       - Are project SCSS button/typography mixins used (from inventory)?
       - Are project shared components used (from inventory)?
       - Are design tokens from SCSS variables used instead of hardcoded values?
       - Does the UI feel consistent with the rest of the project?
       - Compare with other existing pages (profile, my-world) for consistency

    5. Record result with specific differences

    ## Output Format
    ```
    VISUAL_TEST_RESULTS:
    - V1: PASS | Layout matches — 2-column grid, card sizes correct
    - V2: WARN | Dialog border-radius 20px in code, 40px in Figma
    - V3: PASS | Hover state shows menu icon as expected
    - V4: FAIL | Empty state not implemented — shows blank page
    - V5: PASS | Detail page layout matches
    SCREENSHOTS: /tmp/ARGO-XXXXX-V1-app.png, ...
    DIFFERENCES:
    - V2: border-radius mismatch (20px vs 40px)
    - V4: empty state completely missing
    MATCH_RATE: 3/5
    ```

    Close browser when done: `agent-browser close`
```

## Step 4 — Collect & Merge Results

After both agents complete:

1. Read functional test results
2. Read visual test results (if available)
3. Read screenshots for verification
4. Generate `ui-review.md`:

```markdown
# UI Review — ARGO-XXXXX

## Functional Tests
- F1 ✅ Selections list loads, 2 cards visible
- F2 ✅ Dialog opens with name input and Save button
- F3 ✅ Card created successfully
- F4 ⚠️ Menu opens edit directly, should show dropdown first
- F5 ✅ Edit dialog works correctly
- F6 ✅ Delete removes card
- F7 ✅ Detail page opens
- F8 ✅ Back navigation works

**Functional: 7/8 PASS, 1 WARNING**

## Visual Comparison
- V1 ✅ List page matches Figma layout
- V2 ⚠️ Dialog border-radius: 20px (code) vs 40px (Figma)
- V3 ✅ Hover state correct
- V4 ❌ Empty state not implemented
- V5 ✅ Detail page matches

**Visual: 3/5 MATCH, 1 WARNING, 1 MISSING**

## Screenshots
| Test | Path |
|------|------|
| F1 | /tmp/ARGO-XXXXX-F1.png |
| V1 | /tmp/ARGO-XXXXX-V1-app.png |
| ... | ... |

## Issues
- [HIGH] V4: Empty state from Figma not implemented
- [MED] V2: Dialog border-radius doesn't match Figma (20px vs 40px)
- [LOW] F4: Context menu could use mat-menu dropdown instead of direct dialog

## Verdict: APPROVED | HAS_ISSUES
```

## Step 5 — Return Results

### If APPROVED
Return to jira-worker: `UI_REVIEW_RESULT: APPROVED`

### If HAS_ISSUES
Return to jira-worker:
```
UI_REVIEW_RESULT: HAS_ISSUES
HIGH_ISSUES: [list]
MED_ISSUES: [list]
SCREENSHOTS: [paths]
```

**jira-worker then:**
- Shows issues + screenshots to user
- Fixes what it can (code changes for border-radius, missing states)
- Re-takes screenshots for fixed items
- Does NOT re-run full UI review

## Standalone Output

When called independently:
1. Print review to console
2. If `docs/plans/ARGO-XXXXX/` exists → save to `ui-review.md` and `ui-test-plan.md`
3. Show screenshots inline (Read tool on .png files)
4. If HAS_ISSUES → ask: "Fix issues automatically?"
