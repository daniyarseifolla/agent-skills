---
name: adapter-slack
description: "Use when sending notifications to Slack. Provides QA deploy notification template."
human_description: "Адаптер для Slack: отправка QA-уведомлений после деплоя в канал."
allowed-tools: mcp__plugin_slack_slack__slack_send_message, mcp__plugin_slack_slack__slack_search_channels, mcp__plugin_slack_slack__slack_search_users
disable-model-invocation: true
---

# Adapter: Slack (notification)

Implements the `notification` adapter contract. Loaded when `project.yaml` has `notification: slack`.

---

## 1. notify_deploy(task_key, environment, options?)

```yaml
trigger: "Called by worker Phase 6 or ship Step 5/6 after successful deploy"

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
    Описание видимого изменения / импакта для пользователя. НЕ технические детали.
    Плохо: "Добавлена валидация whitespace-only строк для поля Title (En)"
    Хорошо: "Поле Title (En) теперь не принимает строку из одних пробелов"
    Sources (in priority order):
      1. User provided description
      2. Jira task summary (title/description — что видит пользователь)
      3. Last commit message — переформулировать на понятный язык
    NEVER use: код терминов, названий функций, классов, технических деталей реализации.
    Пиши так, чтобы QA-инженер понял что проверять.
  env_url: |
    MUST be resolved from the current project's config. Check in order:
      1. CLAUDE.md — look for host URLs AND base href. Combine: host + base_href.
         Example: host "https://app.ot4.dev" + base href "/creator/" = "https://app.ot4.dev/creator/"
         CRITICAL: Do NOT use host alone. Always check for base href and append it.
      2. .gitlab-ci.yml — look for environment URLs in deploy jobs
      3. project.yaml — look for environment config
    NEVER hardcode. NEVER guess. If not found — ask user.

missing_env: |
  IF any required env var is missing:
    Ask user: "Для Slack-уведомлений нужны env-переменные. Добавь в ~/.zshrc:
      export JIRA_BASE_URL=\"https://your-jira.atlassian.net\"
      export SLACK_QA_CHANNEL_ID=\"C...\"
      export SLACK_QA_MENTION=\"<!subteam^S...>\""
    STOP notification (don't fail the whole pipeline)

template: |
  {mention}
  <{task_url}|{task_key}> задеплоен на {environment}
  {summary}
  <{env_url}|{env_label}>

template_fields:
  mention: "Resolved @qa-team or @specific-person"
  task_key: "PROJ-12345 — rendered as Slack hyperlink <url|text>"
  task_url: "$JIRA_BASE_URL/browse/{task_key} — link target for task_key"
  environment: "test / prod"
  summary: "Импакт для пользователя на русском, без тех. терминов, 1-2 предложения"
  env_label: "'Тест' for test, 'Прод' for prod — rendered as Slack hyperlink"
  env_url: "URL среды из CLAUDE.md / .gitlab-ci.yml — link target for env_label"

slack_formatting:
  hyperlink: "<https://example.com|Display Text> — clickable link in Slack"
  bold: "*text* — bold text"
  note: "Do NOT use markdown []() links — Slack uses <url|text> syntax"

rules:
  - Task key MUST be a Slack hyperlink: <{task_url}|{task_key}>
  - Env label MUST be a Slack hyperlink: <{env_url}|{env_label}>
  - env_url MUST come from project config (CLAUDE.md / .gitlab-ci.yml) — NEVER hardcode
  - NEVER include branch name
  - NEVER include MR/merge request link
  - NEVER include pipeline link or pipeline status
  - NEVER include verification steps (those go to Jira comment)
  - NEVER include raw URLs in message text — all URLs must be hyperlinks
  - NEVER put "Задача:" as separate line — task_key hyperlink replaces it
  - Summary MUST be in Russian
  - Keep message compact — no extra blank lines
  - Message contains EXACTLY 4 lines: mention, task hyperlink + env, summary, env hyperlink

steps:
  - resolve_env: "Read $SLACK_QA_CHANNEL_ID, $SLACK_QA_MENTION, $JIRA_BASE_URL from env"
  - resolve_mention: "Use default or resolve specific person via slack_search_users"
  - resolve_env_url: "Read CLAUDE.md or .gitlab-ci.yml for test/prod URL"
  - build_message: "Fill template using Slack <url|text> hyperlink syntax"
  - send_message:
      tool: slack_send_message
      channel_id: "{resolved_channel_id}"
      message: "{filled_template}"

examples:
  - input: "notify_deploy('PROJ-850', 'test')"
    message: |
      {$SLACK_QA_MENTION}
      <$JIRA_BASE_URL/browse/PROJ-850|PROJ-850> задеплоен на test
      В футере мобильной страницы отображался 2020 год вместо текущего. Исправлено.
      <https://app.example.dev|Тест>

  - input: "notify_deploy('PROJ-824', 'test', mention: 'Sergey')"
    message: |
      <@RESOLVED_USER_ID>
      <$JIRA_BASE_URL/browse/PROJ-824|PROJ-824> задеплоен на test
      Исправлен лейбл на странице Links — было "All Links", стало "Links".
      <https://app.example.dev|Тест>

  - input: "notify_deploy('PROJ-1000', 'prod')"
    message: |
      {$SLACK_QA_MENTION}
      <$JIRA_BASE_URL/browse/PROJ-1000|PROJ-1000> задеплоен на prod
      Некорректный email теперь не проходит при регистрации.
      <https://app.example.com|Прод>
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
