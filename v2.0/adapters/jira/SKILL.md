---
name: adapter-jira
description: "Jira task source adapter. Provides task fetching, AC parsing, transitions, and MR description generation. Loaded by pipeline skills when task-source is jira."
disable-model-invocation: true
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
  - return: structured task object
```

---

## 2. parse_ac(description)

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

## 3. get_complexity_hints(task)

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

Used by worker Phase 0 for complexity classification.

---

## 4. transition(key, status)

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
```

---

## 5. format_mr_description(task, plan_summary, changes)

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

## 6. parse_task_key(user_input)

```yaml
regex: "([A-Z]{2,10})-\\d+"
sources:
  - raw_key: "ARGO-1234"
  - jira_url: "https://team.atlassian.net/browse/ARGO-1234"
  - message: "work on ARGO-1234 please"
extract: "first match from input"
```

---

## 7. add_comment(key, body)

```yaml
steps:
  - call: addCommentToJiraIssue
    params:
      issueKey: "{key}"
      body: "{body}"
```

---

## 8. search(jql)

```yaml
steps:
  - call: searchJiraIssuesUsingJql
    params:
      jql: "{jql}"
  - return: "issue[] with key, summary, status, assignee"
```
