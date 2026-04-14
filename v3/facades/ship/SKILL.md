---
name: ship
description: "Standalone commit+push+deploy command. Standalone Phase 6 for quick fixes. Supports direct push (default) or MR, test/prod deploy. Use when user says /ship, \"закоммить и задеплой\", \"ship it\", \"запуши и задеплой\"."
allowed-tools: Bash(glab *), Bash(git *), Read, Glob, Grep
---

# Ship — Facade

Standalone deployment pipeline: commit → push → deploy.
Extracted from Phase 6 for independent use when making quick fixes outside the full worker pipeline.

## Syntax

```
/ship [prod] [--mr] [--slack]
```

| Flag | Default | Effect |
|------|---------|--------|
| (no flags) | — | commit + push to target branch + deploy test |
| `prod` | off | Also deploy to production after test |
| `--mr` | off | Create MR instead of direct push. MR → merge → then deploy |
| `--slack` | off | Send Slack notification after each deploy |

Flags combine: `/ship prod --mr --slack` = MR + test + prod + notify.

---

## Delegation

1. Read `.claude/project.yaml` for ci-cd adapter type, target branch, deploy config
2. Load CI/CD adapter (e.g., `adapter-gitlab`)
3. If `--slack` → load notification adapter (e.g., `adapter-slack`)

---

## Target Branch Resolution

```yaml
target_branch: "project.yaml → project.branches.main (fallback: develop)"
```

- If currently ON target branch → push directly
- If on feature branch + no `--mr` → merge locally into target branch, push target branch
- If on feature branch + `--mr` → create MR from feature branch to target branch

---

## Workflow

### Step 1: Commit

```yaml
action: "Commit uncommitted changes if any exist"
skip_if: "Working tree is clean (nothing to commit)"
message_format: "fix: {brief description from staged diff}"
```

### Step 2: Push

```yaml
mode_direct: # default (no --mr)
  action: |
    If on target_branch:
      git push
    If on feature branch:
      git checkout {target_branch}
      git merge {feature_branch} --no-edit
      git push
  note: "Direct push — no MR overhead for quick fixes"

mode_mr: # --mr flag
  action: |
    git push -u origin {current_branch}
  note: "Push feature branch, MR created in step 3"
```

### Step 3: Create MR (only with --mr)

```yaml
skip_if: "No --mr flag"
action: |
  ci-cd adapter create_mr(
    branch: current_branch,
    title: auto-generate from latest commits,
    description: auto-generate from git diff,
    target_branch: target_branch
  )
  Output: mr_url, mr_iid
```

### Step 4: Merge MR (only with --mr)

```yaml
skip_if: "No --mr flag"
steps:
  - wait_pipeline: "ci-cd adapter wait_for_stage(mr_pipeline, 'build', timeout=15min)"
  - merge: "glab mr merge {mr_iid} --auto-merge"
  - wait_merge: "Poll MR state until 'merged' (30s polls, 10min timeout)"
```

### Step 5: Deploy Test

```yaml
steps:
  - find_pipeline: "ci-cd adapter get_pipeline(target_branch)"
  - wait_build: "ci-cd adapter wait_for_stage(pipeline, 'build', timeout=15min)"
  - deploy: "ci-cd adapter deploy(target_branch, 'test')"
  - wait_deploy: "Poll deploy job until success (timeout: 10min)"
  - transition: |
      If task_key resolved:
        task_source_adapter.transition(task_key, 'Ready for Test')
        skip_if: no task_source adapter
  - notify: |
      If --slack → MUST load adapter-slack skill and follow its template EXACTLY.
      task_key: from branch name (feat/ARGO-XXX) or commit message
      Template (4 lines, no extras):
        {mention}
        <{$JIRA_BASE_URL}/browse/{task_key}|{task_key}> задеплоен на test
        {summary — импакт для пользователя, НЕ тех. термины}
        <{env_url from CLAUDE.md}|Тест>
      NEVER add: MR link, pipeline link, branch name, raw URLs, verification steps.
report: "Deploy test: SUCCESS | {pipeline_url}"
```

### Step 6: Deploy Prod (only with `prod`)

```yaml
skip_if: "No prod flag"
confirmation: REQUIRED — "Deploy to production? (y/n)"
steps:
  - deploy: "ci-cd adapter deploy(target_branch, 'prod')"
  - wait_deploy: "Poll deploy job until success (timeout: 15min)"
  - notify: |
      If --slack → MUST load adapter-slack skill and follow its template EXACTLY.
      Template (4 lines, no extras):
        {mention}
        <{$JIRA_BASE_URL}/browse/{task_key}|{task_key}> задеплоен на prod
        {summary — импакт для пользователя, НЕ тех. термины}
        <{env_url from CLAUDE.md}|Прод>
      NEVER add: MR link, pipeline link, branch name, raw URLs, verification steps.
report: "Deploy prod: SUCCESS | {pipeline_url}"
```

### Step 7: Report

```yaml
action: "Show summary table of everything that happened"
format: |
  Ship complete:
  | Step | Status | Details |
  |------|--------|---------|
  | Commit | {status} | {commit_hash} |
  | Push | {status} | {method: direct/MR} → {target_branch} |
  | MR | {status or skipped} | {mr_url} |
  | Deploy test | {status} | {pipeline_url} |
  | Deploy prod | {status or skipped} | {pipeline_url} |
  | Jira | {status or skipped} | {task_key} → Ready for Test |
  | Slack | {status or skipped} | notified #{channel} |
```

---

## Error Handling

```yaml
errors:
  push_rejected:
    cause: "Remote has changes not in local"
    fix: "git pull --rebase, then retry push"

  merge_conflict:
    cause: "Feature branch conflicts with target"
    fix: "STOP. Show conflicts. User resolves manually, then re-run /ship"

  build_fail:
    fix: "Show job log tail. Ask: retry / abort"

  deploy_fail:
    fix: "Show deploy log. Offer: retry / rollback / abort"

  mr_merge_fail:
    fix: "Show MR URL + error. Ask user to resolve manually"
```

---

## Examples

```yaml
examples:
  quick_fix:
    command: "/ship"
    flow: "commit → push develop → deploy test"
    use_case: "Small fix, push directly to develop, deploy to test"

  release:
    command: "/ship prod"
    flow: "commit → push develop → deploy test → deploy prod"
    use_case: "Fix ready for production"

  with_review:
    command: "/ship --mr"
    flow: "commit → push feature → MR → merge → deploy test"
    use_case: "Want code review before deploy"

  notify_team:
    command: "/ship prod --slack"
    flow: "commit → push develop → deploy test → deploy prod → slack"
    use_case: "Release with team notification"

  formal_release:
    command: "/ship prod --mr --slack"
    flow: "commit → MR → merge → deploy test → deploy prod → slack"
    use_case: "Formal release with MR and notification"
```
