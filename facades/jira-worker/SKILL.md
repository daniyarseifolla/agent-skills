---
name: jira-worker
description: "Full-cycle Jira task implementation. Use PROACTIVELY when user provides a Jira issue key (ARGO-10698), Jira URL (atlassian.net/browse/..., atlassian.net/jira/...), or says anything like \"сделай задачу\", \"возьми тикет\", \"реализуй\", \"take this ticket\", \"implement this issue\", \"work on ARGO-XXX\". Even if the user just pastes a Jira key or URL without any context, this skill applies."
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent, Skill, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue, mcp__plugin_atlassian_atlassian__transitionJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_figma_figma__get_design_context, mcp__plugin_figma_figma__get_screenshot
---

# Jira Worker — Facade

Entry point for Jira-based task workflow. Delegates to pipeline/worker with Jira adapter.

## Activation

1. Parse task key from user input (regex: `[A-Z]{2,10}-\d+`)
2. If task key found or user intent matches triggers → activate

## Delegation

1. Set adapter overrides:
   ```yaml
   task-source: jira
   task_key: "{parsed key}"
   ```

2. Load and invoke: `Skill: pipeline-worker`
   - Worker reads .claude/project.yaml for remaining config (ci-cd, tech-stack, design)
   - Worker handles full pipeline with all phases

3. If user says "быстро" or "quick" → pass `complexity_override: SIMPLE`
4. If user says "полный цикл" or "full cycle" → pass `complexity_override: FULL`

## User Overrides

| User says | Effect |
|-----------|--------|
| "быстро", "по-быстрому", "quick" | Force SIMPLE route (S complexity) |
| "полный цикл", "full cycle", "с ревью" | Force FULL route (L complexity) |
| "только план", "just plan" | Run only Phase 5: plan, stop |
| "без деплоя", "no deploy" | Skip MR/deploy at completion |

## What this facade does NOT do

- No business logic — all in pipeline/worker
- No adapter loading — worker handles it
- No phase management — worker handles it
- No checkpoint/recovery — worker handles it
