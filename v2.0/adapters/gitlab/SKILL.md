---
name: adapter-gitlab
description: "GitLab CI/CD adapter. Provides MR creation, pipeline monitoring, deploy triggers, and branch management. Loaded by pipeline skills when ci-cd is gitlab."
disable-model-invocation: true
allowed-tools: Bash(glab *), Bash(git *)
---

# Adapter: GitLab (ci-cd)

Implements the `ci-cd` adapter contract. Loaded when `project.yaml` has `ci-cd: gitlab`.

---

## 1. create_mr(branch, title, description, target_branch)

```yaml
confirmation: REQUIRED — always ask user before creating MR

command: |
  glab mr create --source-branch "{branch}" --target-branch "{target_branch}" \
    --title "{title}" --description "{description}" --no-editor

target_branch_default: "project.yaml → project.branches.main (fallback: develop)"
```

---

## 2. get_pipeline(branch)

```yaml
command: |
  glab api "projects/:id/pipelines?ref={branch}&source=push&per_page=1"

note: "ALWAYS use source=push filter. Without it, you'll find MR pipelines on refs/merge-requests/*/head that lack deploy jobs."

extract:
  id: "data[0].id"
  status: "data[0].status"
  web_url: "data[0].web_url"

statuses:
  - running
  - pending
  - success
  - failed
  - canceled
  - skipped
```

---

## 3. wait_for_stage(pipeline_id, stage_name, timeout_min)

```yaml
defaults:
  timeout_min: 15
  poll_interval_sec: 30

steps:
  - call: "glab api projects/:id/pipelines/{pipeline_id}/jobs"
  - filter: "jobs where stage == {stage_name}"
  - check_status:
      success: "return done"
      failed: "return failed + job log tail"
      running: "wait {poll_interval_sec}, retry"
      pending: "wait {poll_interval_sec}, retry"
  - on_timeout: "report last known status to user"
```

---

## 4. deploy(branch, environment)

```yaml
confirmation: REQUIRED — always ask user before deploying

steps:
  - find_pipeline: "get_pipeline({branch})"
  - wait_build: "wait_for_stage(pipeline.id, 'build')"
  - find_deploy_job: |
      glab api "projects/:id/pipelines/{pipeline.id}/jobs"
      filter: job.name matches project.yaml → project.deploy.{environment}-job
  - trigger: |
      glab api --method POST "projects/:id/jobs/{job_id}/play"
  - wait_deploy: "wait_for_stage(pipeline.id, 'deploy', timeout_min=20)"
  - report: "status + web_url"

environment_mapping:
  source: "project.yaml → project.deploy"
  example:
    test-job: deploy-test
    prod-job: production
```

---

## 5. retry_job(job_id)

```yaml
command: |
  glab api --method POST "projects/:id/jobs/{job_id}/retry"
```

---

## 6. create_tag(tag_name, ref)

```yaml
command: |
  git tag "{tag_name}" "{ref}" && git push origin "{tag_name}"

use_case: "production releases"
```

---

## 7. branch_management

```yaml
create_branch:
  command: "git checkout -b {name} {from}"

push_branch:
  command: "git push -u origin {name}"

delete_branch:
  confirmation: REQUIRED
  command: "git push origin --delete {name}"
```

---

## 8. get_job_log(job_id, tail_lines)

```yaml
defaults:
  tail_lines: 50

command: |
  glab api "projects/:id/jobs/{job_id}/trace" | tail -n {tail_lines}

use_case: "diagnosing pipeline failures"
```

---

## 9. community_sync

Cherry-pick distribution across community branches.

```yaml
cherry_pick_batch:
  params:
    commit: "string — commit SHA"
    branches: "string[] — target branches"
    batch_size: 3
  steps:
    - for_each_batch: "branches in chunks of {batch_size}"
    - parallel_per_branch:
        - checkout: "git worktree add ../{branch}-worktree origin/{branch}"
        - cherry_pick: "git cherry-pick {commit}"
        - on_conflict: "resolve, rebuild, verify"
        - build: "run project build command"
        - push: "git push origin {branch}"
    - wait_for_batch: "all branches in batch complete"
    - push_delay: "30s between pushes (GitLab rate limit)"
    - cleanup: "git worktree remove ../{branch}-worktree"
    - next_batch: "repeat"

rate_limiting:
  push_delay_sec: 30
  reason: "avoid GitLab API rate limits on parallel pushes"
```

---

## 10. Python JSON Parsing Helper

glab api outputs extra text alongside JSON. Always use Python to extract:

```python
import json, sys, re
raw = sys.stdin.read()
match = re.search(r'[\[{].*[\]}]', raw, re.DOTALL)
if match:
    data = json.loads(match.group())
    # process data
```

WHY: glab API responses include headers/debug text mixed with JSON. Direct JSON parsing fails.

---

## 11. Rollback Workflow

```yaml
rollback:
  description: "Revert a bad deployment"
  steps:
    - "Find rollback job in pipeline: glab api 'projects/:id/pipelines/{id}/jobs' | filter stage=rollback"
    - "Or find previous successful deploy and re-trigger it"
    - "Jobs: rollback:gcp-test, rollback:gcp-prod (project-specific)"
  requires_confirmation: true
```

---

## 12. Error Handling Patterns

```yaml
error_handling:
  401_unauthorized:
    cause: "glab auth token expired"
    fix: "Run: glab auth login"

  no_pipeline_found:
    cause: "Push hasn't triggered pipeline yet, or used wrong ref"
    fix: "Wait 10s, retry. Check if branch was actually pushed."

  job_not_found:
    cause: "Pipeline still in earlier stages, deploy job not created yet"
    fix: "Wait for build stage to complete first"

  deploy_job_created_status:
    cause: "Manual job, needs to be 'played'"
    fix: "glab api --method POST 'projects/:id/jobs/{id}/play'"

  deploy_fails_oom:
    cause: "Container OOM killed or k8s pod crash loop"
    fix: "Show log tail, suggest: check memory limits or rollback"

  pipeline_stuck_running:
    cause: "Runner hung or network issue"
    fix: "Cancel pipeline, re-push: glab api --method POST 'projects/:id/pipelines/{id}/cancel'"

  glab_not_installed:
    fix: "brew install glab && glab auth login"
```

---

## 13. Pipeline Stages Reference

```yaml
stages_reference:
  typical_order: [lint, test, build-deps, build-static, build, push, deploy-test, production, rollback]
  note: "Exact stages vary per project. Check .gitlab-ci.yml"
```

---

## 14. Useful Commands

```yaml
useful_commands:
  list_recent: 'glab api "projects/:id/pipelines?per_page=5"'
  cancel_pipeline: 'glab api --method POST "projects/:id/pipelines/{id}/cancel"'
  get_full_log: 'glab api "projects/:id/jobs/{id}/trace"'
  list_branches: 'glab api "projects/:id/repository/branches?per_page=100"'
```
