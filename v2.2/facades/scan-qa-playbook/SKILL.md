---
name: scan-qa-playbook
description: "Generate QA playbook from project analysis: edge cases, test credentials, pre-MR checklist, known fragile areas. Use when user says 'скан QA', 'scan QA', 'сгенерируй playbook', 'generate playbook', 'обнови playbook', or when preparing for QA phase."
allowed-tools: Read, Glob, Grep, Write, Bash(git log *), Bash(find *)
---

# Scan QA Playbook

Generates `.claude/qa-playbook.md` — QA-specific knowledge base for testing.
Referenced by: pipeline-ui-reviewer (test planning), qa-test-planner (test generation).

## What to Collect

### 1. Test Credentials & Auth
```yaml
sources:
  - ".env.example / .env.development — test accounts"
  - "Grep: 'test.*user\\|test.*pass\\|demo.*account' in *.md *.json"
  - "CLAUDE.md — credentials section"
  - "Jira tasks — 'Пользователь:' / 'Логин:' patterns in recent tasks"

extract:
  accounts:
    - role: "admin / user / guest"
      login: "{email or username}"
      password: "{password or reference to vault}"
      notes: "what this account can access"
  auth_flow:
    - "Login URL: /auth/login or /login"
    - "Auth method: JWT / session / OAuth"
    - "Token storage: localStorage / cookie"
    - "nativeInputValueSetter needed: yes/no (Angular forms)"
```

### 2. Known Fragile Areas
```yaml
sources:
  - "docs/plans/*/code-review.md — HIGH/CRITICAL issues"
  - "docs/plans/*/ui-review.md — failed tests"
  - "git log --grep='fix\\|bug\\|hotfix' --oneline -30"
  - "Grep: 'flaky\\|intermittent\\|sometimes fails' in *.spec.ts"

extract:
  fragile_pages:
    - page: "/search"
      issue: "Playlists don't filter by query"
      frequency: "always"
    - page: "/profile/edit"
      issue: "Form loses data on browser back"
      frequency: "intermittent"

  fragile_features:
    - feature: "File upload"
      issue: "Fails silently over 10MB"
    - feature: "i18n"
      issue: "Some keys not translated in community variants"
```

### 3. Test Environment
```yaml
sources:
  - "package.json → scripts.serve / scripts.start"
  - "angular.json → serve.options.port"
  - ".env* files"
  - "docker-compose.yml"

extract:
  dev_server:
    command: "npx nx serve {app}"
    port: 4200
    alt_ports: [6200, 3000]
    api_proxy: "http://localhost:3001 or remote API"

  test_urls:
    local: "http://localhost:4200"
    staging: "https://test.example.com"
    production: "https://example.com"
```

### 4. Edge Cases from Project History
```yaml
sources:
  - "git log --all --oneline -50 — commit messages mentioning edge cases"
  - "*.spec.ts — existing test descriptions"
  - "docs/plans/*/ui-test-plan.md — past test plans"
  - "Grep: 'edge.*case\\|corner.*case\\|boundary' in *.ts"

extract:
  common_edge_cases:
    - category: "Input validation"
      cases: ["empty string", "very long text (1000+ chars)", "special chars: <>&\"'", "cyrillic: кириллица", "emoji: 🎉"]
    - category: "Network"
      cases: ["slow connection (3G)", "offline → online", "API timeout", "500 error from backend"]
    - category: "Browser"
      cases: ["mobile viewport (375px)", "tablet (768px)", "zoom 150%", "dark mode"]
    - category: "Auth"
      cases: ["expired token", "concurrent sessions", "back button after logout"]
```

### 5. Pre-MR Checklist
```yaml
sources:
  - ".claude/project-practices.md — rules section"
  - "CLAUDE.md — conventions"
  - "Past code reviews — recurring issues"

generate:
  checklist:
    code:
      - "Lint passes (no new warnings)"
      - "Tests pass"
      - "Build succeeds"
      - "No console.log left"
      - "No hardcoded strings (i18n)"
    ui:
      - "Matches Figma (if applicable)"
      - "Mobile responsive"
      - "Keyboard navigation works"
      - "Loading states present"
      - "Error states handled"
    project_specific:
      - "{from project-practices.md rules}"
```

## Output Format

Write to `.claude/qa-playbook.md`:
```markdown
# QA Playbook
Generated: {date}
Project: {name}

## Test Credentials
| Role | Login | Password | Access | Notes |
|------|-------|----------|--------|-------|
| admin | admin@test.com | test123 | full | — |
| user | user@test.com | test123 | limited | — |

## Auth Flow
- URL: /auth/login
- Method: JWT + interceptor
- Input trick: nativeInputValueSetter (Angular)

## Test Environment
| Env | URL | Port |
|-----|-----|------|
| Local | localhost | 4200 |
| Staging | test.example.com | — |

## Known Fragile Areas
| Page/Feature | Issue | Frequency | Last Seen |
|-------------|-------|-----------|-----------|
| /search | Playlists ignore query param | always | ARGO-10755 |
| File upload | Silent fail >10MB | sometimes | ARGO-10600 |

## Common Edge Cases
### Input
- Empty string, 1000+ chars, special chars, cyrillic, emoji

### Network
- Slow 3G, offline→online, API timeout, 500 errors

### Browser
- Mobile 375px, tablet 768px, zoom 150%, dark mode

### Auth
- Expired token, concurrent sessions, back after logout

## Pre-MR Checklist
- [ ] Lint passes
- [ ] Tests pass
- [ ] Build succeeds
- [ ] No console.log
- [ ] Matches Figma
- [ ] Mobile responsive
- [ ] Loading/error states
- [ ] {project-specific items}
```

## Integration with Pipeline

```yaml
used_by:
  pipeline-ui-reviewer:
    reads: "qa-playbook.md → credentials, fragile areas, edge cases"
    uses_for: "Generate test scenarios per task"

  pipeline-code-reviewer:
    reads: "qa-playbook.md → pre-MR checklist"
    uses_for: "Verify checklist items"

  qa-test-planner:
    reads: "qa-playbook.md → edge cases, fragile areas"
    uses_for: "Generate comprehensive test cases"
```

## Update Mode

When `.claude/qa-playbook.md` exists:
1. Read existing
2. Rescan (credentials, fragile areas from new reviews)
3. KEEP manual entries (user-added edge cases, credentials)
4. ADD new findings from latest pipeline runs
5. Show what changed

## When to Run

- First time setting up skills in a project
- After discovering new bugs in production
- After QA finds issues that pipeline missed
- Before major feature development
