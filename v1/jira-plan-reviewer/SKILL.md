---
name: jira-plan-reviewer
description: Automatic detailed review of implementation plans against Jira requirements, codebase patterns, and Figma designs. Runs as a subagent for objectivity. Called by jira-worker in full mode only.
allowed-tools: Bash(*), Read, Glob, Grep, Agent, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot
---

# Jira Plan Reviewer — Automated Plan Quality Gate

Reviews implementation plans for completeness, correctness, and alignment with Jira requirements, codebase conventions, and Figma designs.

## When Called

- By jira-worker Step 5 (full mode only)
- Runs as Agent (subagent) for isolated, objective review

## Input

```
ISSUE_KEY:       ARGO-XXXXX
SUMMARY:         Jira issue title
DESCRIPTION:     Jira issue body
AC:              Acceptance criteria (original + synthetic from Figma)
FIGMA_URLS:      Figma URLs (may be empty)
PROJECT_TYPE:    passport | community
MODULES:         Affected modules with paths
PLAN_PATH:       docs/plans/ARGO-XXXXX/plan.md
CHECKLIST_PATH:  docs/plans/ARGO-XXXXX/checklist.md
```

## Review Process

Dispatch a review subagent with the following prompt structure:

```
Agent tool (general-purpose):
  description: "Review plan for ARGO-XXXXX"
  prompt: |
    You are reviewing an implementation plan for a Jira task.
    Your job is to find gaps, errors, and risks BEFORE implementation starts.

    ## Jira Task
    Key: {ISSUE_KEY}
    Summary: {SUMMARY}
    Description: {DESCRIPTION}

    ## Acceptance Criteria
    {AC — numbered list}

    ## Plan Content
    {full content of plan.md}

    ## Checklist Content
    {full content of checklist.md}

    ## Project Info
    Type: {PROJECT_TYPE}
    Modules: {MODULES}

    ## Review Checklist

    ### 1. AC Coverage
    For EVERY AC item, verify:
    - Is there at least one task that implements it?
    - Is the task description sufficient to satisfy the AC?
    - Are there "phantom" tasks not linked to any AC?

    ### 2. Codebase Alignment
    Read the actual codebase files mentioned in the plan:
    - Do the patterns in the plan match existing project conventions?
    - Are the correct services/components referenced?
    - Is there duplication with something that already exists?
    - Does the plan respect read-only library code (libs/)?
    - Are path aliases correct (@app/*, @core/*, @shared/*)?

    ### 3. Figma Coverage (if URLs provided)
    {If FIGMA_URLS not empty, include this section}
    - Are all screens from mackets covered by tasks?
    - Are UI states accounted for (empty, loading, error, hover)?
    - Are responsive/mobile considerations mentioned?

    ### 4. Technical Soundness
    - Are file paths valid (existing files) or creation justified?
    - Do task dependencies make sense?
    - Is the task order correct (models before services before components)?
    - Are build/lint verification steps included?
    - Is the commit strategy clean (one logical change per commit)?

    ### 5. Risk Assessment
    - Any tasks that seem overly complex and should be split?
    - Any missing error handling?
    - Any security concerns?
    - Any performance risks?

    ## Output Format

    Write your review in this exact format:

    ```markdown
    # Plan Review — ARGO-XXXXX

    ## AC Coverage
    - AC-1: ✅ covered by Task 1, Task 2
    - AC-2: ⚠️ partially covered — [what's missing]
    - AC-3: ❌ not covered — [no task addresses this]

    ## Codebase Alignment
    - ✅ Patterns match existing conventions
    - ⚠️ [issue description with file references]
    - ❌ [critical misalignment]

    ## Figma Coverage
    - Screen "List View": ✅ covered
    - Screen "Empty State": ❌ missing — no task for this
    - State "Hover": ⚠️ mentioned but no specific task

    ## Issues
    - [HIGH] [description — must fix before implementation]
    - [MED] [description — should fix, quality concern]
    - [LOW] [description — nice to have]

    ## Suggestions
    - [Optional improvements or alternative approaches]

    ## Verdict: APPROVED | NEEDS_REVISION
    [One sentence justification]
    ```

    Be thorough but fair. Don't flag style preferences as issues.
    HIGH = will cause incorrect behavior or broken build.
    MED = quality concern or missing edge case.
    LOW = suggestion for improvement.
```

## After Review

### If APPROVED
- Save `plan-review.md` to artifacts directory
- Return to jira-worker: `REVIEW_RESULT: APPROVED`

### If NEEDS_REVISION
- Save `plan-review.md` to artifacts directory
- Return to jira-worker:
  ```
  REVIEW_RESULT: NEEDS_REVISION
  HIGH_ISSUES: [count]
  MED_ISSUES: [count]
  ISSUES_SUMMARY: [brief list of what needs fixing]
  ```

**jira-worker then:**
1. Shows review to user
2. Updates `plan.md` and `checklist.md` based on feedback
3. Does NOT re-run reviewer (avoid infinite loops)
4. Proceeds to implementation

## Quality Standards

The reviewer should NOT flag:
- Code style preferences (formatting, naming conventions) — that's for code review
- Implementation details (which specific Angular API to use) — trust the planner
- Pre-existing technical debt — only issues introduced by this plan

The reviewer SHOULD flag:
- Missing AC coverage (most critical)
- Wrong file paths or non-existent references
- Library modification attempts (libs/ is read-only)
- Missing states (empty, error, loading) when Figma shows them
- Circular or impossible dependencies between tasks
