---
name: community-sync
description: "Distribute commits across community branches with parallel cherry-pick, build verification, and deployment. Use PROACTIVELY when user says \"обновить ветки\", \"sync branches\", \"распространить коммит\", \"cherry-pick в ветки\", \"обновить community ветки\", \"раскатить на все ветки\", \"distribute commit\", \"update all branches\", \"deploy everywhere\"."
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent
---

# Community Sync — Facade

Distributes commits across multiple community/* branches. Uses CI/CD adapter for push/deploy.

## Activation

Triggers on branch sync phrases. Specific to projects with community/* branch pattern.

## Delegation

1. Read .claude/project.yaml for ci-cd adapter
2. Load adapter-gitlab (or detected ci-cd adapter)

## Workflow

1. **Identify** — determine commit(s) to distribute and target branches
   ```bash
   git branch -r | grep 'origin/community/' | sed 's|origin/||'
   ```

2. **Plan** — show user which commits go to which branches, ask confirmation

3. **Execute** — cherry-pick in parallel batches (batch_size from adapter config, default 3)
   - Each batch: spawn parallel Agent(worktree) per branch
   - Each agent: checkout → cherry-pick → resolve conflicts → build → push
   - Wait for batch → next batch

4. **Verify** — check each branch builds after cherry-pick

5. **Deploy** (optional, ask user)
   - For production branches: create tags via ci-cd adapter
   - Trigger deploy jobs

## Conflict Resolution

If cherry-pick conflicts:
1. Try auto-resolve common patterns (import conflicts, version bumps)
2. If auto-resolve fails → skip branch, report to user
3. User can manually resolve and re-run for failed branches

## Safety

- Always show plan before executing
- Push sequentially with delay (rate limit protection)
- Never force-push

---

## Configuration

Config block the facade provides to the adapter:

```yaml
config_source: |
  These values are DEFAULTS. Override in .claude/project.yaml:
  ```yaml
  community-sync:
    tag_branches: [alex, avi, arcadiy, nama]
    exclude_branches: [calling-in]
    active_period_days: 30
    push_delay_seconds: 30
    batch_size: 3
  ```
  If project.yaml has community-sync section, use those values.
  If not, use defaults below.

config:
  tag_branches: [alex, avi, arcadiy, nama]     # branches that get production tags
  exclude_branches: [calling-in]                # branches to skip
  active_period_days: 30                        # only sync branches with commits in last N days
  push_delay_seconds: 30                        # delay between sequential pushes
  tag_format: "{branch}-{date}"                 # e.g., alex-2026-03-17
  batch_size: 3                                 # parallel cherry-pick batch size
```

---

## Branch Integrity Verification (Step 4b)

CRITICAL: After all cherry-picks complete, BEFORE pushing, verify every target branch actually contains the expected commit:

```bash
for branch in "${TARGET_BRANCHES[@]}"; do
  if ! git log "$branch" --oneline -20 | grep -q "${COMMIT_HASH:0:7}"; then
    echo "WARNING: $branch does NOT contain commit $COMMIT_HASH"
    # Manual cherry-pick for this branch
  fi
done
```

WHY: Worktree agents can silently lose commits. This happened in production — branches appeared updated but lacked the commit. Always verify before push.

---

## "When Commit Removes Code" Warning

When the commit being distributed REMOVES code (deleting features, removing imports):
- Sub-agents tend to "keep both sides" during conflict resolution
- This defeats the purpose of the commit
- After conflict resolution, VERIFY the removed patterns don't exist:

```bash
# If commit removes function X, verify it's gone
grep -r "functionX" path/to/file && echo "CONFLICT RESOLUTION FAILED — code still present"
```

---

## Build Fix Strategy (Angular-specific)

```yaml
build_fixes:
  reference: "See adapter-angular for Angular-specific build fix patterns"
  common: [TS2559, NG8002, NG5002]
```

---

## node_modules Symlink

Worktree builds need node_modules from the main repo:

```bash
ln -sf "$(pwd)/node_modules" "/path/to/worktree/node_modules"
```

WHY: Installing fresh node_modules per worktree is slow and wasteful. Symlink from main repo.

---

## Lessons Learned

```yaml
lessons:
  - lesson: "Worktree isolation is mandatory"
    why: "Without worktrees, parallel cherry-picks corrupt each other's git state"

  - lesson: "Shell variable expansion in refspec is fragile"
    why: "'community/$branch:community/$branch' concatenates wrong. Use simple form: git push origin community/branch"

  - lesson: "Build verification catches 90% of CI failures"
    why: "Much cheaper to catch locally than wait for 20-minute CI pipeline"

  - lesson: "Tag pipelines use tag name as ref, not branch name"
    why: "glab api filter by ref must use the tag name to find the pipeline"

  - lesson: "Worktree agents can silently lose commits"
    why: "Agent completes successfully but commit wasn't actually applied. Always verify with git log check (Step 4b)"
    mitigation: "Branch integrity verification before push"
```

---

## Report Format

After sync completes, show summary:

```
| # | Branch | Cherry-pick | Build | Push | Deploy | Tag |
|---|--------|-------------|-------|------|--------|-----|
| 1 | community/alex | OK | OK | OK | test+prod | alex-2026-03-17 |
| 2 | community/avi  | OK | FIXED(TS2559) | OK | test+prod | avi-2026-03-17 |
| 3 | community/foo  | CONFLICT | — | — | — | — |
```

---

## Deploy Strategy per Branch Type

```yaml
deploy_strategy:
  regular_branches: "test only"
  tag_branches: "test + prod (create tag first)"
  nama: "BOTH test AND prod (special case — needs both environments)"
```
