---
name: ship
description: "Standalone commit+push+deploy command. Standalone Phase 9: ship for quick fixes. Supports direct push (default) or MR, test/prod deploy. Use when user says /ship, \"закоммить и задеплой\", \"ship it\", \"запуши и задеплой\"."
human_description: "Быстрый деплой: commit -> push -> deploy в одну команду. Для hotfix-ов без полного pipeline."
allowed-tools: Bash(glab *), Bash(git *), Read, Glob, Grep
---

# Ship — Facade

Standalone deployment pipeline: commit → push → deploy.
Extracted from Phase 9: ship for independent use when making quick fixes outside the full worker pipeline.

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

### Step 3: Deploy (both paths delegate to core-ship-protocol)

```yaml
resolve_task_key: |
  Before delegating, resolve task_key for protocol:
    branch name feat/{TASK_KEY} → {TASK_KEY}, or parse from commit messages.
    If truly unresolvable → pass empty, protocol will WARN and continue.

mr_path: # --mr flag
  action: |
    Load core-ship-protocol. Execute with inputs:
      task_key: {resolved_task_key}
      mr_title: auto-generate from latest commits
      mr_description: auto-generate from git diff
      target_branch: target_branch
      environment: 'test'
      skip_after_mr: false
      skip_mr: false
      skip_merge: false
    If --slack → ensure notification adapter is loaded before protocol runs.
    Error handling defined in core-ship-protocol.

direct_path: # no --mr (default)
  action: |
    Load core-ship-protocol. Execute with inputs:
      task_key: {resolved_task_key}
      target_branch: target_branch
      environment: 'test'
      skip_mr: true
      skip_merge: true
    Protocol handles: find pipeline → wait build → deploy → wait deploy → Jira transition → Slack notify.
    If --slack → ensure notification adapter is loaded before protocol runs.
    Error handling defined in core-ship-protocol.
```

### Step 4: Deploy Prod (only with `prod`)

```yaml
skip_if: "No prod flag"
confirmation: REQUIRED — "Deploy to production? (y/n)"
action: |
  Re-invoke core-ship-protocol with inputs:
    task_key: {resolved_task_key}
    target_branch: target_branch
    environment: 'prod'
    skip_mr: true
    skip_merge: true
  Protocol handles: find pipeline → wait build → deploy → wait deploy → Jira transition → Slack notify.
  Slack notification uses adapter-slack template (defined in adapter, not here).
```

### Step 5: Report

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
