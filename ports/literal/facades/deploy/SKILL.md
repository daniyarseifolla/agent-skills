---
name: literal-facade-deploy
description: "Deploy branches to test or production via CI/CD. Use PROACTIVELY when user says \"задеплой\", \"залей на тест\", \"залей на прод\", \"deploy to test\", \"deploy to prod\", \"trigger pipeline\", \"запусти деплой\", \"проверь пайплайн\", \"check pipeline\", or mentions deploying, triggering CI jobs, checking pipeline status, or rolling back deployments."
allowed-tools: Bash(glab *), Bash(git *), Read, Glob, Grep
---

# Deploy — Facade

Standalone deployment trigger. Delegates to CI/CD adapter directly (no full pipeline needed).

## Activation

Triggers on deploy-related phrases in any language (RU/EN).

## Delegation

1. Read .claude/project.yaml for ci-cd adapter type and deploy config
2. If no config → autodetect from .gitlab-ci.yml or .github/workflows/
3. Load appropriate ci-cd adapter (e.g., literal-adapter-gitlab)

## Modes

| User says | Action |
|-----------|--------|
| "deploy to test", "залей на тест" | adapter.deploy(current_branch, "test") |
| "deploy to prod", "залей на прод" | adapter.deploy(current_branch, "prod") — REQUIRES confirmation |
| "check pipeline", "проверь пайплайн" | adapter.get_pipeline(current_branch) → show status |
| "retry", "перезапусти" | adapter.retry_job(failed_job_id) |

## Safety

- Deploy to production ALWAYS requires explicit user confirmation
- Show pipeline URL after triggering
- Monitor until completion or timeout (15 min)
