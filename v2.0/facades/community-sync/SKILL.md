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
2. Load adapters/gitlab (or detected ci-cd adapter)

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
