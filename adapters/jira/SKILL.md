---
name: adapter-jira
description: "Use when fetching and managing Jira tasks. Provides task fetching, AC parsing, transitions."
human_description: "Адаптер для Jira: fetch задачи, парсинг AC, переходы статуса, формат MR description."
allowed-tools: mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue, mcp__plugin_atlassian_atlassian__transitionJiraIssue, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_atlassian_atlassian__addCommentToJiraIssue
---

# Adapter: Jira (task-source)

Implements the `task-source` adapter contract. Loaded when `project.yaml` has `task-source: jira`.

---

## 1. fetch_task(key)

```yaml
steps:
  - call: getJiraIssue
    params:
      issueKey: "{key}"
  - extract:
      title: "fields.summary"
      description: "fields.description"
      acceptance_criteria: "parse_ac(fields.description)"
      priority: "fields.priority.name"
      assignee: "fields.assignee.displayName"
      status: "fields.status.name"
      figma_urls: "parse_urls(fields.description)"
      credentials: "parse_credentials(fields.description)"
      attachments: "fields.attachment (id, filename, mimeType, size)"
  - auto_fetch_images: |
      IF attachments contain mimeType image/* →
        call fetch_attachments(key)
        analyze each image with Read tool
        store results as visual_context field
  - return: "structured task object: title, description, acceptance_criteria, priority, assignee, status, figma_urls, credentials, attachments, visual_context"

  extended_parsing:
    subtasks: "Extract subtask list if present"
    credentials: "Look for 'Пользователь:' / 'Логин:' / 'Login:' / 'Password:' patterns"
    expected_result: "Extract 'Ожидаемый результат' / 'Expected Result' section"
    actual_result: "Extract 'Фактический результат' / 'Actual Result' section (for bugs)"
    checklist_from_ac: "Convert AC items to checkbox list for tracking"
```

---

## 2. fetch_attachments(key)

```yaml
steps:
  - run: "jira-attachments {key}"
  - output_dir: "/tmp/jira-attachments/{key}/"
  - for_each_image: "Read with Read tool to analyze screenshots/mockups"
  - return: "list of file paths + visual analysis summary"

note: |
  Script at ~/.local/bin/jira-attachments downloads all attachments via Jira REST API.
  Uses curl -L (Jira returns 303 redirect to api.media.atlassian.com).
  Auth via $ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN from ~/.zshrc.
```

---

## 3. parse_ac(description)

```yaml
heading_patterns:
  - "Acceptance Criteria"
  - "AC:"
  - "acceptance criteria"

extract_rules:
  - find: "first matching heading pattern in description"
  - collect: "all numbered/bulleted items below heading until next heading or end"
  - bullet_patterns:
      - "^\\s*[-*]\\s+"
      - "^\\s*\\d+[\\.)]\\s+"
      - "^\\s*\\[\\s*\\]\\s+"
  - return: "string[]"
```

---

## 4. get_complexity_hints(task)

```yaml
output:
  ac_count: "len(task.acceptance_criteria)"
  has_figma: "len(task.figma_urls) > 0"
  modules_mentioned: "extract module/lib names from description"
  estimated_scope: "S|M|L|XL based on ac_count thresholds"

scope_thresholds:
  S: "ac_count <= 2"
  M: "ac_count <= 4"
  L: "ac_count <= 6"
  XL: "ac_count >= 7"
```

Used by worker Phase 1: analyze for complexity classification.

---

## detect_modules

```yaml
detect_modules:
  strategy: "Scan description and AC for keywords, map to project modules"
  note: "Module paths are project-specific. Use tech-stack adapter module_lookup or .claude/project.yaml modules."
  keywords_hint:
    - "auth, login, registration → auth module"
    - "profile, settings, account → profile module"
    - "layout, header, sidebar, navigation → layout module"
    - "shared, common, utility → shared module"
    - "store, state, redux, ngrx → store module"
```

---

## 5. transition(key, status)

```yaml
steps:
  - call: getTransitionsForJiraIssue
    params:
      issueKey: "{key}"
  - find: "transition where name matches {status} (case-insensitive)"
  - call: transitionJiraIssue
    params:
      issueKey: "{key}"
      transitionId: "{matched_transition.id}"
  - on_no_match: "report available transitions to user"

  transition_after_deploy:
    action: "After successful deploy, transition to 'Ready for Test'"
    steps:
      - "getTransitionsForJiraIssue → find 'Ready for Test' or equivalent"
      - "transitionJiraIssue with found transition ID"
    skip_if: "No deploy was performed"
```

---

## 6. format_mr_description(task, plan_summary, changes)

```yaml
template: |
  ## {task.key}: {task.title}

  ### Changes
  {changes}

  ### Acceptance Criteria
  {for ac in task.acceptance_criteria}
  - [ ] {ac}
  {endfor}

  ### Testing
  {plan_summary.test_plan}

  ### Figma
  {for url in task.figma_urls}
  - {url}
  {endfor}
```

---

## 7. parse_task_key(user_input)

```yaml
regex: "([A-Z]{2,10})-\\d+"
sources:
  - raw_key: "ARGO-1234"
  - jira_url: "https://team.atlassian.net/browse/ARGO-1234"
  - message: "work on ARGO-1234 please"
extract: "first match from input"
```

---

## 8. add_comment(key, body)

```yaml
steps:
  - call: addCommentToJiraIssue
    params:
      issueKey: "{key}"
      body: "{body}"
```

---

## 9. search(jql)

```yaml
steps:
  - call: searchJiraIssuesUsingJql
    params:
      jql: "{jql}"
  - return: "issue[] with key, summary, status, assignee"
```
