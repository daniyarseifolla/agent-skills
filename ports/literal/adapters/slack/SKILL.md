---
name: literal-adapter-slack
description: "Slack notification adapter. Sends QA notifications after deploy. Loaded by pipeline skills when notification is slack."
allowed-tools: mcp__plugin_slack_slack__slack_send_message, mcp__plugin_slack_slack__slack_search_channels
---

# Adapter: Slack (notification)

Implements the `notification` adapter contract. Loaded when `project.yaml` has `notification: slack`.

---

## 1. notify_deploy(task_key, environment)

```yaml
trigger: "Called by worker Phase 6 after successful deploy"

defaults:
  channel_id: "C08DDSMHZMJ"          # #qa
  mention: "<!subteam^S08G7CUMM0E>"  # @qa-team user group

steps:
  - resolve_channel: |
      IF config overrides defaults (non-default channel/mention):
        slack_search_channels({channel_name}) → resolve channel ID
      ELSE:
        use defaults.channel_id (C08DDSMHZMJ)
  - send_message:
      tool: slack_send_message
      channel_id: "{resolved_channel_id}"
      message: "{mention} {task_key} задеплоена на {environment}"

examples:
  - input: "notify_deploy('ARGO-12345', 'test')"
    call: |
      slack_send_message(
        channel_id: "C08DDSMHZMJ",
        message: "<!subteam^S08G7CUMM0E> ARGO-12345 задеплоена на test"
      )

  - input: "notify_deploy('ARGO-12345', 'prod')"
    call: |
      slack_send_message(
        channel_id: "C08DDSMHZMJ",
        message: "<!subteam^S08G7CUMM0E> ARGO-12345 задеплоена на prod"
      )
```

---

## Configuration

```yaml
# .claude/project.yaml
notification: slack
slack:
  channel_id: "C08DDSMHZMJ"           # #qa (default)
  mention: "<!subteam^S08G7CUMM0E>"   # @qa-team (default)
```

---

## Slack User Group Reference

```yaml
qa_team:
  channel: "#qa"
  channel_id: "C08DDSMHZMJ"
  user_group_id: "S08G7CUMM0E"       # subteam ID
  mention_syntax: "<!subteam^S08G7CUMM0E>"

note: |
  User groups use <!subteam^ID> syntax, NOT @group-name.
  Group IDs (S...) are found by searching messages where the group was mentioned:
    slack_search_public_and_private(query: "<!subteam")
  NOT via slack_search_users (that only finds individual users).
```
