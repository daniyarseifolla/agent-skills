---
name: deploy
description: Deploy branches to test or production via GitLab CI/CD. Use PROACTIVELY when user says "задеплой", "залей на тест", "залей на прод", "deploy to test", "deploy to prod", "trigger pipeline", "запусти деплой", "проверь пайплайн", "check pipeline", or mentions deploying, triggering CI jobs, checking pipeline status, or rolling back deployments. Applies to all projects — passport, community, or any GitLab-hosted repo.
---

# GitLab CI/CD Deploy

Trigger and monitor deployments via GitLab pipelines. Supports single branch, batch deploy, and tag-based production releases.

## Project Config

Detect project from git remote, then use matching config:

| Project | GitLab Path | Test Env | Test Job | Prod Job |
|---------|------------|----------|----------|----------|
| passport | `argo-media%2Fargo-media-frontend-ecosystem%2Fot4-passport-frontend` | passport.maji.la | `gcp:test` (stage: `deploy-test`) | `gcp:prod` (stage: `production`) |
| community | `argo-media%2Fargo-media-frontend-ecosystem%2Fcommunity` | per-branch domains | `gcp:test` (stage: `deploy-test`) | `gcp:prod` (stage: `production`) |

Detection:
```bash
REMOTE=$(git remote get-url origin 2>/dev/null)
[[ "$REMOTE" == *"ot4-passport-frontend"* ]] && PROJECT="argo-media%2Fargo-media-frontend-ecosystem%2Fot4-passport-frontend"
[[ "$REMOTE" == *"community"* ]] && PROJECT="argo-media%2Fargo-media-frontend-ecosystem%2Fcommunity"
```

## Core API Helpers

`glab api` sometimes outputs extra text alongside JSON. Always parse with `re.search` to extract JSON reliably:

```bash
# Find latest push pipeline for a branch
find_pipeline() {
  glab api "projects/$PROJECT/pipelines?ref=$1&source=push&per_page=1" \
    2>&1 | python3 -c "
import sys, re, json
raw = sys.stdin.read()
match = re.search(r'\[.*\]', raw, re.DOTALL)
if match:
    data = json.loads(match.group())
    if data:
        p = data[0]
        print(f'{p[\"id\"]}|{p[\"status\"]}')
    else:
        print('NO_PIPELINE')
else:
    print('PARSE_ERROR: ' + raw[:200])
"
}

# Find a specific job in a pipeline by stage and name
find_job() {
  glab api "projects/$PROJECT/pipelines/$1/jobs?per_page=50" \
    2>&1 | python3 -c "
import sys, re, json
stage, name = '$2', '$3'
raw = sys.stdin.read()
match = re.search(r'\[.*\]', raw, re.DOTALL)
if match:
    for j in json.loads(match.group()):
        if j['stage'] == stage and j['name'] == name:
            print(f'{j[\"id\"]}|{j[\"status\"]}')
            break
    else:
        print('JOB_NOT_FOUND')
else:
    print('PARSE_ERROR: ' + raw[:200])
"
}

# Trigger a manual job
trigger_job() {
  glab api --method POST "projects/$PROJECT/jobs/$1/play" \
    2>&1 | python3 -c "
import sys, re, json
raw = sys.stdin.read()
match = re.search(r'\{.*\}', raw, re.DOTALL)
if match:
    d = json.loads(match.group())
    print(f'{d.get(\"name\", \"?\")}: {d.get(\"status\", \"?\")}')
else:
    print('PARSE_ERROR: ' + raw[:200])
"
}

# Check pipeline or job status
check_status() {
  glab api "projects/$PROJECT/$1" \
    2>&1 | python3 -c "
import sys, re, json
raw = sys.stdin.read()
match = re.search(r'\{.*\}', raw, re.DOTALL)
if match:
    print(json.loads(match.group())['status'])
else:
    print('PARSE_ERROR: ' + raw[:200])
"
}
```

These are **template patterns** — copy and adapt inline for each specific call. They are NOT a sourceable bash script; each invocation should be a standalone `glab api ... | python3` one-liner.

## Workflow: Single Branch Deploy

### 1. Find Pipeline

Always use `source=push` — MR pipelines run on `refs/merge-requests/*/head` and typically lack deploy jobs.

```bash
# For branch pipelines
find_pipeline "community/alex"

# For tag pipelines (production via tags)
find_pipeline "2026.03.10-alex-profile-links"
```

### 2. Wait for Build

Poll every 30s, max 10 min. Pipeline must reach `success` before deploy jobs become available:

```bash
check_status "pipelines/{pipeline_id}"
# running/pending → poll again
# success → proceed
# failed → show failed jobs, stop
```

If failed, show which jobs failed:
```bash
glab api "projects/$PROJECT/pipelines/{pipeline_id}/jobs?per_page=50" \
  2>&1 | python3 -c "
import sys, re, json
raw = sys.stdin.read()
match = re.search(r'\[.*\]', raw, re.DOTALL)
if match:
    for j in json.loads(match.group()):
        if j['status'] == 'failed':
            print(f'{j[\"stage\"]} / {j[\"name\"]} — FAILED')
"
```

### 3. Trigger Deploy Job

```bash
# Test deploy
find_job "{pipeline_id}" "deploy-test" "gcp:test"
trigger_job "{job_id}"

# Production deploy
find_job "{pipeline_id}" "production" "gcp:prod"
trigger_job "{job_id}"
```

Production deploys require explicit user confirmation before triggering.

### 4. Verify

Poll job status every 30s, max 5 min:
```bash
check_status "jobs/{job_id}"
```

On success:
```
Deploy: gcp:test (#12345) — success
Branch: community/alex
Commit: abc1234 — feat: profile links
```

On failure — show last 30 lines of job log:
```bash
glab api "projects/$PROJECT/jobs/{job_id}/trace" 2>&1 | tail -30
```

## Workflow: Batch Deploy

For deploying multiple branches (used by community-sync):

**Test deploys — trigger all at once** (lightweight API calls):
```bash
for each branch:
  pipeline_id = find_pipeline("community/{branch}")
  job_id = find_job(pipeline_id, "deploy-test", "gcp:test")
  trigger_job(job_id)
```

**Prod deploys — one at a time** (verify each before next):
```bash
for each tag_branch:
  pipeline_id = find_pipeline("{tag_ref}")
  job_id = find_job(pipeline_id, "production", "gcp:prod")
  trigger_job(job_id)
  wait until success or failed
```

**Special case — nama:** needs BOTH test (from branch pipeline) AND prod (from tag pipeline).

After batch deploy, present summary:

| Branch | Pipeline | Test | Prod |
|--------|----------|------|------|
| community/alex | #123 | — | success |
| community/my-jokes | #456 | success | — |
| community/nama | #789 / #790 | success | success |

## Pipeline Stages Reference

Stages run in order: `lint → test → build-deps → build-static → build → push → deploy-test → production → rollback`

| Job | Stage | Type | When to use |
|-----|-------|------|-------------|
| `gcp:test` | deploy-test | Manual | Test environment |
| `gcp:prod` | production | Manual | Production — confirm with user first |
| `rollback:gcp-test` | rollback | Manual | Revert test deploy |
| `rollback:gcp-prod` | rollback | Manual | Revert prod deploy |

## Useful Commands

```bash
# List recent pipelines for a branch
glab api "projects/$PROJECT/pipelines?ref={branch}&per_page=5"

# Retry a failed job
glab api --method POST "projects/$PROJECT/jobs/{id}/retry"

# Cancel a running pipeline
glab api --method POST "projects/$PROJECT/pipelines/{id}/cancel"

# Get full job log
glab api "projects/$PROJECT/jobs/{id}/trace" 2>&1 | tail -50
```

## Error Handling

- **401 from glab** → auth expired. Tell user: `glab auth login`
- **No pipeline found** → push may not have happened yet, or ref name is wrong. Double-check branch/tag name
- **Job not found in pipeline** → pipeline may still be building. Wait for pipeline status to be `success` first
- **Deploy job status `created`** (not `manual`) → same as manual, can be triggered with `/play`
- **Deploy fails** → show job log tail, ask user. Common: OOM during deploy, k8s pod crash loop
- **Pipeline stuck on `running`** → cancel and re-push: `glab api --method POST .../pipelines/{id}/cancel`
- **glab not installed** → `brew install glab && glab auth login`

## Example

```
User: залей community/alex на тест

1. Detect project → community
2. Find pipeline: glab api ".../pipelines?ref=community/alex&source=push&per_page=1"
   → Pipeline #2375835328 — success
3. Find job: stage=deploy-test, name=gcp:test
   → Job #13430743308 — manual
4. Trigger: POST .../jobs/13430743308/play
   → gcp:test: pending
5. Poll... → success

Deploy: gcp:test (#13430743308) — success
Branch: community/alex
```
