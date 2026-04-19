---
name: literal-facade-worker
description: "Full-cycle task implementation. Use PROACTIVELY when user provides a Jira issue key (ARGO-10698), Jira URL (atlassian.net/browse/..., atlassian.net/jira/...), GitHub issue (#123), task URL, or says anything like \"сделай задачу\", \"возьми тикет\", \"реализуй\", \"take this ticket\", \"implement this issue\", \"work on ARGO-XXX\". Even if the user just pastes a task key or URL without any context, this skill applies."
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, Skill, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue, mcp__plugin_atlassian_atlassian__transitionJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot
---

# Worker — Facade

Universal entry point for task implementation. Autodetects task source and delegates to pipeline/worker.

## Activation

1. Parse task reference from user input
2. If task reference found or user intent matches triggers → activate

## Task Source Autodetect

| Pattern | Detected source |
|---------|----------------|
| `[A-Z]{2,10}-\d+` (e.g., ARGO-XXX) | Jira |
| `#\d+` | GitHub |
| URL containing `atlassian.net` | Jira |
| URL containing `github.com` | GitHub |
| Other URL | Parse and detect |

## Delegation

1. Autodetect task source from input and set adapter overrides:
   ```yaml
   task-source: "{autodetected}"
   task_key: "{parsed key}"
   ```

2. Load and invoke: `Skill: literal-pipeline-worker`
   - Worker reads .claude/project.yaml for remaining config (ci-cd, tech-stack, design)
   - Worker handles full pipeline with all phases

3. If user says "быстро" or "quick" → pass `complexity_override: SIMPLE`
4. If user says "полный цикл" or "full cycle" → pass `complexity_override: FULL`

## User Overrides

| User says | Effect |
|-----------|--------|
| "быстро", "по-быстрому", "quick" | Force SIMPLE route (S complexity) |
| "полный цикл", "full cycle", "с ревью" | Force FULL route (L complexity) |
| "только план", "just plan" | Run only Phase 1 (Planning), stop |
| "без деплоя", "no deploy" | Skip MR/deploy at completion |

## What this facade does NOT do

- No business logic — all in pipeline/worker
- No adapter loading — worker handles it
- No phase management — worker handles it
- No checkpoint/recovery — worker handles it
