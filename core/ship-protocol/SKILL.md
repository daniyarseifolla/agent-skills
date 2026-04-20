---
name: core-ship-protocol
description: "Use when executing shipping steps (MR, pipeline, merge, deploy, transition, notify). Loaded by worker Phase 9 and ship facade as shared protocol."
human_description: "Общий протокол деплоя: MR → pipeline → merge → deploy → Jira transition → Slack notify."
disable-model-invocation: true
---

# Ship Protocol — Core

Reusable shipping sequence. Callers provide context (task_key, mr_title, mr_description, target_branch, environment). Protocol executes the shared steps.

---

## Inputs

```yaml
inputs:
  task_key: "Jira task key (e.g., ARGO-12345). Resolved by caller."
  mr_title: "MR title. Caller generates."
  mr_description: "MR description. Caller generates."
  target_branch: "Merge target. From project.yaml → project.branches.main (fallback: develop)"
  environment: "Deploy target: 'test' or 'prod'"
  skip_after_mr: "boolean — if true, stop after MR creation (e.g., worker 'только MR' option)"
  skip_mr: "boolean — if true, skip Steps 1-6 (push, MR creation, pipeline wait, merge). Caller already pushed to target branch directly."
  skip_merge: "boolean — if true, skip Steps 5-6 (merge + wait). Implied by skip_mr."
```

---

## Steps

### Step 1: Push

```yaml
skip_if: "skip_mr == true (caller already pushed to target branch)"
action: "git push -u origin {current_branch}"
note: "Ensure feature branch is on remote before MR creation"
```

### Step 2: Create MR

```yaml
skip_if: "skip_mr == true"
action: |
  ci-cd adapter create_mr(
    branch: current_branch,
    title: mr_title,
    description: mr_description,
    target_branch: target_branch
  )
  Output: mr_url, mr_iid
```

### Step 3: Stop If MR Only

```yaml
skip_if: "skip_mr == true"
skip_to: "caller checkpoint"
condition: "skip_after_mr == true"
```

### Step 4: Wait MR Pipeline

```yaml
skip_if: "skip_mr == true"
action: "ci-cd adapter wait_for_stage(pipeline, 'build')"
timeout: "15min"
```

### Step 5: Merge

```yaml
skip_if: "skip_mr == true OR skip_merge == true"
action: "glab mr merge {mr_iid} --auto-merge"
```

### Step 6: Wait Merge

```yaml
skip_if: "skip_mr == true OR skip_merge == true"
action: "Poll MR state until state == 'merged'"
poll_interval: "30s"
timeout: "10min"
```

### Step 7: Find Target Pipeline

```yaml
action: "ci-cd adapter get_pipeline(target_branch)"
note: "Post-merge pipeline on target branch"
```

### Step 8: Wait Build

```yaml
action: "ci-cd adapter wait_for_stage(target_pipeline, 'build')"
timeout: "15min"
```

### Step 9: Deploy

```yaml
action: "ci-cd adapter deploy(target_branch, environment)"
```

### Step 10: Wait Deploy

```yaml
action: "Poll deploy job until success"
timeout: "10min"
```

### Step 11: Transition

```yaml
action: |
  MANDATORY — Jira transition is a REQUIRED step, not optional.
  task_source_adapter.transition(task_key, environment == 'test' ? 'Ready for Test' : 'Done')
  QA tracks readiness via Jira status — skipping this breaks their workflow.
  skip_if: no task_source adapter loaded (this is the ONLY valid skip reason)
  Do NOT rationalize skipping: "small change", "not critical", "I'll do later" — WRONG.
  Do NOT skip because "task_key not resolved" — extract from branch name first, then commits.
  If task_key truly unresolvable → WARN, continue.
  If transition API call fails → WARN (don't halt pipeline), log error, continue to step 12.
```

### Step 12: Notify

```yaml
action: |
  MUST load adapter-slack skill and follow its template EXACTLY.
  Call: notification_adapter.notify_deploy(task_key, environment)
  Template (4 lines, no extras):
    {mention}
    <{$JIRA_BASE_URL}/browse/{task_key}|{task_key}> задеплоен на {environment}
    {summary — импакт для пользователя, НЕ тех. термины}
    <{env_url from CLAUDE.md/.gitlab-ci.yml: host + base_href}|Тест/Прод>
  env_url source: CLAUDE.md OR .gitlab-ci.yml
  NEVER add: MR link, pipeline link, branch name, raw URLs, verification steps.
  skip_if: no notification adapter loaded
```

---

## Error Handling

```yaml
errors:
  push_rejected:
    cause: "Remote has changes not in local"
    fix: "git pull --rebase, then retry push"

  pipeline_fail:
    action: "Show job log tail. Ask: retry / abort. On abort: write checkpoint, MR stays open."

  merge_conflict:
    action: "Show conflicted files. STOP. User resolves manually, then caller retries."

  mr_merge_fail:
    action: "Show MR URL + error. Ask user to resolve manually."

  mr_pipeline_timeout:
    action: "Show pipeline URL. Ask: keep waiting / abort."

  deploy_fail:
    action: "Show deploy log. Offer: retry / rollback / abort."
```

---

## Report

```yaml
report:
  format: |
    Готово:
    - MR: {mr_url}
    - Deploy: {environment} success
    - Jira: {transition_status}
    - Slack: {notified_channel or 'skipped'}
```
