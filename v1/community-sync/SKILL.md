---
name: community-sync
description: Distribute commits across community branches with parallel cherry-pick, build verification, and deployment. Use PROACTIVELY when user says "обновить ветки", "sync branches", "распространить коммит", "cherry-pick в ветки", "обновить community ветки", "раскатить на все ветки", "distribute commit", "update all branches", "deploy everywhere", or mentions syncing, distributing, or propagating changes across multiple community/* branches.
---

# Sync Community Branches

Distribute a commit from the current branch into all active `community/*` branches using parallel sub-agents with automatic conflict resolution, build verification, and deployment.

## Configuration

```
TAG_BRANCHES: alex, avi, arcadiy, nama
EXCLUDE_BRANCHES: calling-in
BRANCH_PATTERN: community/*
ACTIVE_PERIOD: 30 days
PUSH_DELAY: 30 seconds
TAG_FORMAT: YYYY.MM.DD-{branch}-{description}
GITLAB_PROJECT: argo-media%2Fargo-media-frontend-ecosystem%2Fcommunity
```

Branches in `TAG_BRANCHES` get a git tag after push → triggers production pipeline. All other branches are updated without tags → test deploy only.

## Batching Strategy

Each step has a different bottleneck — batch sizes are tuned to avoid the specific constraint:

| Step | Batch size | Why this size |
|------|-----------|---------------|
| Cherry-pick + Build | 3 | Angular build uses ~2GB RAM. More than 3 simultaneous builds risk OOM on a 16GB machine |
| Push | Sequential, 30s gap | Each push triggers a GitLab CI pipeline. Flooding 20 pushes at once overwhelms the runner queue |
| Deploy test triggers | All at once | Just HTTP POST calls to GitLab API — no local resource cost |
| Deploy prod triggers | 1 at a time | Production deploys need verification between each. A bad deploy should stop the chain |

## Workflow

### Step 1: Identify Commit

Determine which commit to distribute:
- If the user specifies a hash, use it
- If "latest" or no specification, use: `git log --oneline -1`

Store the commit hash. Also run `git diff-tree --no-commit-id --name-status -r {commit_hash}` to understand what changed — this context is critical for writing conflict resolution instructions for sub-agents.

### Step 2: Fetch and List Target Branches

```bash
git fetch --all --prune

# Calculate 30 days ago
SINCE=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)

git for-each-ref --sort=-committerdate \
  --format='%(committerdate:short) %(refname:short)' \
  refs/remotes/origin/community/ | awk -v since="$SINCE" '$1 >= since'
```

Exclude the current branch and `EXCLUDE_BRANCHES`. Present the list with count and ask for confirmation.

### Step 3: Cherry-pick + Build Verification (Parallel, batches of 3)

For each target branch, launch a sub-agent with worktree isolation. This ensures agents don't interfere with each other's branch checkouts — running multiple agents on the same repo without worktree isolation causes them to clobber each other's state.

```
Agent(
  subagent_type: "general-purpose",
  isolation: "worktree",
  run_in_background: true
)
```

#### 3a. Cherry-pick

Sub-agent instructions for cherry-pick:
1. `git checkout -b {branch} origin/{branch}`
2. `git cherry-pick {commit_hash}`
3. If clean → proceed to build (3b)
4. If conflicts:
   - `git diff --name-only --diff-filter=U` to list conflicting files
   - For `libs` submodule: `git checkout --theirs libs && git add libs`
   - For other files: accept incoming changes for files the branch didn't independently modify. Keep branch-specific features (e.g., `profileBackgroundGradient`, widgets) but apply what the commit changes.
   - After resolving: `git add -A && git cherry-pick --continue --no-edit`
5. If conflicts are too complex (both sides meaningfully changed the same lines):
   - `git cherry-pick --abort`
   - Respond: `CONFLICT — [detailed explanation]`
   - Skip build.

**When the commit removes code** (deleting a feature flag, removing a binding): sub-agents have a strong tendency to "keep both sides" during conflict resolution, which defeats the purpose. The commit's deletion IS the feature — explicitly instruct the agent: "The following patterns must NOT exist after resolution: `{pattern}`. Run `grep -r '{pattern}' apps/web/src/` to verify — output should be empty."

#### 3b. Build Verification

Only if cherry-pick succeeded. Symlink `node_modules` from the main repo (use the working directory from before worktree creation, e.g., `/Users/dannywayne/Desktop/projects/argo/community`):
```bash
ln -s /absolute/path/to/main/repo/node_modules ./node_modules
yarn build 2>&1 | tail -50
```

If build fails, attempt auto-fix based on error type (see Build Fix Strategy below), rebuild, and report.

#### 3c. Response Format

Each agent responds with:
```
CHERRY-PICK: SUCCESS | BUILD: SUCCESS
```
or:
```
CHERRY-PICK: SUCCESS (resolved conflicts in [files]) | BUILD: FAIL
Error: TS2559 — Type 'true' has no properties in common with '{ isFirstLoad?: boolean }'
File: apps/web/src/app/community/community/community.component.ts:145
```
or:
```
CHERRY-PICK: CONFLICT — Both sides modified fetchUserFeed() with different logic
BUILD: SKIPPED
```

Launch in **batches of 3**. Wait for each batch to complete before launching the next.

### Step 4: Review Build Results

After all agents complete, present a summary:

```
Build Results:
  Passed: 17 branches
  Failed: 2 branches (hotel-cafe, yasmine)
  Conflicts: 0 branches
```

For failed builds, show the errors and ask user:
- **Auto-fix**: launch fix agents for known error patterns
- **Skip**: exclude from push, handle manually later
- **Abort**: stop entire sync

Only proceed to push with branches that passed both cherry-pick AND build.

### Step 4b: Verify Branch Integrity

**Critical step.** Worktree agents may cherry-pick onto a temporary worktree branch instead of the actual `community/{branch}`. After all agents complete and before pushing, verify every target branch contains the expected commit:

```bash
COMMIT_MSG="short commit message or unique pattern"
MISSING=""
for branch in $ALL_TARGET_BRANCHES; do
  latest=$(git log --oneline -1 community/$branch)
  if ! echo "$latest" | grep -q "$COMMIT_MSG"; then
    echo "MISSING: community/$branch — latest: $latest"
    MISSING="$MISSING $branch"
  fi
done
```

If any branches are missing the commit:
1. Cherry-pick manually: `git checkout community/{branch} && git cherry-pick {hash}`
2. Verify build: `yarn build`
3. Add to push list

**Why this happens:** worktree isolation creates a separate working directory. If the agent runs `git checkout -b community/grandaddy origin/community/grandaddy` but the worktree's HEAD is detached, the commit lands on a temporary branch that gets cleaned up with the worktree. The fix is to ensure agents checkout the existing local branch (`git checkout community/{branch}`) not create a new one from remote.

### Step 5: Sequential Push

Push branches that passed, one at a time with 30s delay:

```bash
# Build the list from Step 4 results
git push origin community/my-jokes && sleep 30 && \
git push origin community/alex && sleep 30 && \
git push origin community/avi
# ... etc
```

Use `git push origin community/{branch}` — do NOT use the `source:destination` refspec format in loops. Shell variable expansion inside `"community/$branch:community/$branch"` causes refspec concatenation bugs like `community/my-jokesommunity/my-jokes`.

### Step 6: Create Tags

For TAG_BRANCHES (alex, avi, arcadiy, nama):

1. Ask user for tag description suffix (e.g., `profile-links`)
2. Delete existing tags with same name if they exist (remote + local)
3. Create and push:
```bash
git tag 2026.03.10-alex-profile-links community/alex
git tag 2026.03.10-avi-profile-links community/avi
git tag 2026.03.10-arcadiy-profile-links community/arcadiy
git tag 2026.03.10-nama-profile-links community/nama
git push origin 2026.03.10-alex-profile-links 2026.03.10-avi-profile-links 2026.03.10-arcadiy-profile-links 2026.03.10-nama-profile-links
```

### Step 7: Deploy

Use the **deploy** skill for all deployments. Provide context:

- **Regular branches**: deploy to test only (`gcp:test`). Find push pipeline by `ref=community/{branch}`, source=push.
- **TAG_BRANCHES**: deploy to production (`gcp:prod`). Find tag pipeline by `ref={tag_name}`.
- **nama**: needs BOTH test and prod.

Trigger all test deploys at once, prod deploys one at a time. See deploy skill for full API patterns.

### Step 8: Report

Present a summary table:

| # | Branch | Cherry-pick | Build | Push | Deploy | Tag |
|---|--------|-------------|-------|------|--------|-----|
| 1 | community/alex | SUCCESS | OK | OK | PROD | 2026.03.10-alex-... |
| 2 | community/avi | SUCCESS | OK | OK | PROD | 2026.03.10-avi-... |
| 3 | community/nama | SUCCESS | OK | OK | PROD+TEST | 2026.03.10-nama-... |
| 4 | community/my-jokes | SUCCESS | OK | OK | TEST | — |

List CONFLICT and BUILD FAIL branches separately with full explanations.

## Conflict Resolution Strategy

**Auto-resolve (safe):**
- Unused import conflicts (e.g., `IconName` declared but not used)
- Files modified only by the incoming commit, not by the target branch
- Submodule pointer updates (`libs`)

**Return to user (unsafe):**
- Both sides modified the same function/method with different logic
- Structural HTML template changes where both sides restructured the same section
- SCSS conflicts where both sides changed the same selectors with different values

## Build Fix Strategy

**Auto-fix (known patterns):**

| Error | Cause | Fix |
|-------|-------|-----|
| `TS2559` type mismatch | API signature changed (e.g., `boolean` → `{ isFirstLoad: boolean }`) | Update call sites to new signature |
| `NG8002` unknown binding | Template uses removed property (e.g., `[enableProfileLink]`) | Remove or replace with new API |
| `NG5002` template syntax | Broken structure (mismatched `}` / `</div>`) | Fix block/tag nesting |

**Return to user:** errors unrelated to the cherry-picked changes, dependency conflicts, cascading errors.

## Error Recovery

- Sub-agent fails → don't retry, include in report
- Build fails and auto-fix doesn't work → exclude from push, report for manual fix
- Push fails → continue with remaining branches, report failure
- Tag creation fails → report and continue
- Deploy fails → see deploy skill error handling
- Clean up worktrees after all operations complete

## Lessons Learned

These patterns are from real production incidents during sync operations:

- **Worktree isolation is mandatory.** Without it, concurrent agents checkout different branches in the same repo and overwrite each other's state. One agent's `git checkout community/alex` clobbers another's `community/avi` working tree.
- **Shell variable expansion in refspecs is fragile.** `"community/$branch:community/$branch"` inside a loop concatenates wrong. Always use the simple form: `git push origin community/{branch}`.
- **Build verification catches 90% of CI failures early.** The three most common: API signature changes (TS2559), removed template bindings (NG8002), broken HTML structure (NG5002). All are auto-fixable.
- **Tag pipelines use the tag name as ref**, not the branch name. To find pipeline for tag `2026.03.10-alex-profile-links`, query with that exact string as ref.
- **Worktree agents can silently lose commits.** Agent reports SUCCESS but the commit lands on a temporary worktree branch (e.g., `worktree-agent-aa23eea5`) instead of the actual `community/{branch}`. When the worktree is cleaned up, the commit is gone. Always run Step 4b verification before pushing. Root cause: agent creates a new branch from remote (`git checkout -b community/X origin/community/X`) in the worktree, but the worktree's git state doesn't propagate back to the main repo's branch pointer. Mitigation: instruct agents to `git checkout community/{branch}` (existing local branch) rather than creating new ones, or always verify after.

## Example Run

```
User: раскатай последний коммит на все ветки

→ Step 1: git log --oneline -1 → 41c927e3 feat: always-on profile links
→ Step 2: 19 active branches found (excluding calling-in)
   ASK: "Distribute 41c927e3 to 19 branches?"
→ Step 3: Launch batches of 3
   Batch 1: my-jokes ✓, alex ✓, avi ✓
   Batch 2: arcadiy ✓, nama (conflict in libs, auto-resolved) ✓, katrina ✓
   ...
   Batch 7: yasmine ✓
   Results: 19/19 cherry-pick OK, 17/19 build OK
   Failed builds: hotel-cafe (NG8002), yasmine (NG5002) → auto-fixed → rebuild OK
→ Step 4: All 19 passed. Proceed?
→ Step 5: Sequential push with 30s delays
→ Step 6: Tags for alex, avi, arcadiy, nama → pushed
→ Step 7: Deploy (via deploy skill) — 15 test + 4 prod
→ Step 8: Summary table with all 19 branches
```
