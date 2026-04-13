---
name: adapter-slack
description: "Slack notification adapter. Sends QA notifications after deploy. Loaded by pipeline skills when notification is slack."
allowed-tools: mcp__plugin_slack_slack__slack_send_message, mcp__plugin_slack_slack__slack_search_channels, mcp__plugin_slack_slack__slack_search_users
---

# Adapter: Slack (notification)

Implements the `notification` adapter contract. Loaded when `project.yaml` has `notification: slack`.

---

## 1. notify_deploy(task_key, environment, options?)

```yaml
trigger: "Called by worker Phase 6 after successful deploy"

env_vars:
  JIRA_BASE_URL: "Jira instance URL (e.g. https://team.atlassian.net)"
  SLACK_QA_CHANNEL_ID: "Slack channel ID for QA notifications"
  SLACK_QA_MENTION: "Default mention syntax (e.g. <!subteam^ID>)"

resolve:
  channel_id: "$SLACK_QA_CHANNEL_ID — REQUIRED, fail if not set"
  mention: |
    IF options.mention specified (user asked to tag specific person):
      slack_search_users({name}) → resolve user ID → <@USER_ID>
    ELSE:
      $SLACK_QA_MENTION — REQUIRED, fail if not set
  task_url: "$JIRA_BASE_URL/browse/{task_key}"
  summary: |
    Short description of what was done. Sources (in priority order):
      1. User provided description
      2. Last commit message summary (translated to Russian if needed)
      3. Jira task summary
  env_url: |
    From project's deploy config or CI/CD adapter.
    NOT hardcoded — resolved per project at deploy time.

missing_env: |
  IF any required env var is missing:
    Ask user: "Для Slack-уведомлений нужны env-переменные. Добавь в ~/.zshrc:
      export JIRA_BASE_URL=\"https://your-jira.atlassian.net\"
      export SLACK_QA_CHANNEL_ID=\"C...\"
      export SLACK_QA_MENTION=\"<!subteam^S...>\""
    STOP notification (don't fail the whole pipeline)

template: |
  {mention}
  *{task_key}* задеплоен на {environment}
  {summary}
  Задача: {task_url}
  {env_label}: {env_url}

template_fields:
  mention: "Resolved @qa-team or @specific-person"
  task_key: "ARGO-12345 (bold with *)"
  environment: "test / prod"
  summary: "Краткое описание на русском, 1-2 предложения"
  task_url: "$JIRA_BASE_URL/browse/{task_key}"
  env_label: "'Тест' for test, 'Прод' for prod"
  env_url: "URL среды из deploy config"

rules:
  - NEVER include branch name
  - NEVER include verification steps (those go to Jira comment)
  - Summary MUST be in Russian
  - Keep message compact — no extra blank lines

steps:
  - resolve_env: "Read $SLACK_QA_CHANNEL_ID, $SLACK_QA_MENTION, $JIRA_BASE_URL from env"
  - resolve_mention: "Use default or resolve specific person via slack_search_users"
  - build_message: "Fill template with resolved values"
  - send_message:
      tool: slack_send_message
      channel_id: "{resolved_channel_id}"
      message: "{filled_template}"

examples:
  - input: "notify_deploy('ARGO-10850', 'test')"
    env: "JIRA_BASE_URL=https://team.atlassian.net, SLACK_QA_CHANNEL_ID=C08DDSMHZMJ"
    message: |
      <!subteam^S08G7CUMM0E>
      *ARGO-10850* задеплоен на test
      Исправлен захардкоженный год в футере мобильной страницы.
      Задача: https://team.atlassian.net/browse/ARGO-10850
      Тест: https://app.example.dev

  - input: "notify_deploy('ARGO-10824', 'test', mention: 'Sergey')"
    message: |
      <@U0SERGEY_ID>
      *ARGO-10824* задеплоен на test
      Исправлен лейбл на странице Links — было "All Links", стало "Links".
      Задача: https://team.atlassian.net/browse/ARGO-10824
      Тест: https://app.example.dev

  - input: "notify_deploy('ARGO-11000', 'prod')"
    message: |
      <!subteam^S08G7CUMM0E>
      *ARGO-11000* задеплоен на prod
      Добавлена валидация email при регистрации.
      Задача: https://team.atlassian.net/browse/ARGO-11000
      Прод: https://app.example.com
```

---

## Configuration

All configuration via environment variables (`~/.zshrc`):

```bash
export JIRA_BASE_URL="https://your-jira.atlassian.net"
export SLACK_QA_CHANNEL_ID="C..."        # channel ID for QA notifications
export SLACK_QA_MENTION="<!subteam^S...>" # @qa-team user group mention
```

No secrets or URLs are stored in the repository.

---

## Slack Mention Syntax

```yaml
user_group: "<!subteam^GROUP_ID> — for @qa-team etc."
individual: "<@USER_ID> — for specific person"

discovery:
  user_groups: "slack_search_public_and_private(query: '<!subteam') → extract IDs"
  individuals: "slack_search_users({name}) → get user ID"
```
