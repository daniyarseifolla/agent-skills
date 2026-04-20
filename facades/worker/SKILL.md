---
name: worker
description: "Full-cycle task implementation. Use PROACTIVELY when user provides a Jira issue key (ARGO-10698), Jira URL (atlassian.net/browse/..., atlassian.net/jira/...), GitHub issue (#123), task URL, or says anything like \"сделай задачу\", \"возьми тикет\", \"реализуй\", \"take this ticket\", \"implement this issue\", \"work on ARGO-XXX\". Even if the user just pastes a task key or URL without any context, this skill applies."
---

# Worker — Redirect

This facade is merged into pipeline-worker. Load pipeline-worker directly.

## Delegation

Load Skill: pipeline-worker
