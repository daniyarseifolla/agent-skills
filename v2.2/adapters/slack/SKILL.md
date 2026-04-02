---
name: adapter-slack
description: "Slack notification adapter. Sends QA notifications after deploy. Loaded by pipeline skills when notification is slack."
allowed-tools: mcp__plugin_slack_slack__slack_send_message, mcp__plugin_slack_slack__slack_search_channels
---

# Adapter: Slack (notification)

Implements the `notification` adapter contract. Loaded when `project.yaml` has `notification: slack`.

---

## 1. notify_deploy(task_key, environment)

```yaml
trigger: "Called by worker Phase 6 after successful deploy"

config:
  channel: "project.yaml → slack.channel (default: #qa)"
  mention: "project.yaml → slack.mention (default: @qa-team)"

steps:
  - resolve_channel: "slack_search_channels({channel}) → get channel ID"
  - send_message:
      tool: slack_send_message
      channel: "{resolved_channel_id}"
      message: "{mention} {task_key} задеплоена на {environment}"

examples:
  - input: "notify_deploy('ARGO-12345', 'test')"
    message: "@qa-team ARGO-12345 задеплоена на test"

  - input: "notify_deploy('ARGO-12345', 'prod')"
    message: "@qa-team ARGO-12345 задеплоена на prod"
```

---

## Configuration

```yaml
# .claude/project.yaml
notification: slack
slack:
  channel: "#qa"          # default: #qa
  mention: "@qa-team"     # default: @qa-team
```
