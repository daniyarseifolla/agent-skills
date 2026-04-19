---
name: scan-practices
description: "Scan project for conventions, known bugs, lessons learned, and generate .claude/project-practices.md. Use when user says 'скан практик', 'scan practices', 'обнови практики', 'update practices', 'собери грабли', or when starting work on a new project."
human_description: "Сканирует проект на конвенции, известные баги, lessons learned -> .claude/project-practices.md."
allowed-tools: Read, Glob, Grep, Write, Bash(git log *), Bash(find *)
---

# Scan Project Practices

Generates `.claude/project-practices.md` — project-specific knowledge base for pipeline skills.
Referenced by: pipeline-planner (research), pipeline-coder (rules), pipeline-code-reviewer (checks).

## What to Collect

### 1. Architecture Rules
Scan for patterns that define project structure:
```yaml
sources:
  - "CLAUDE.md — project conventions section"
  - ".claude/rules/*.md — existing rules"
  - "tsconfig.json → paths (path aliases)"
  - "angular.json / project.json → project config"
  - "package.json → scripts, dependencies"
  - ".eslintrc / .prettierrc — code style"

extract:
  path_aliases: "tsconfig.json → compilerOptions.paths"
  build_commands: "package.json → scripts (build, lint, test, serve)"
  project_type: "Nx monorepo / standalone Angular / other"
  style_config: "SCSS / CSS / Tailwind + preprocessor config"
```

### 2. Known Bugs & Workarounds
Scan git history and comments for known issues:
```yaml
sources:
  - "git log --all --oneline --grep='workaround\\|hack\\|fixme\\|todo\\|known issue' | head -20"
  - "Grep: 'FIXME\\|HACK\\|WORKAROUND\\|TODO.*bug\\|KNOWN ISSUE' across *.ts *.html *.scss"
  - "docs/plans/*/code-review.md — recurring issues from past reviews"

extract:
  - pattern: "description of bug/workaround"
  - location: "file:line"
  - severity: "critical / annoying / cosmetic"
```

### 3. Project-Specific Patterns
Detect patterns unique to this project:
```yaml
detect:
  services:
    - "Grep: 'SnackbarService\\|NotificationService\\|ToastService' → which notification pattern?"
    - "Grep: 'ClipboardService\\|Clipboard' → clipboard workaround?"
    - "Grep: 'AuthService\\|AuthGuard' → auth pattern?"

  state_management:
    - "Grep: '@ngrx\\|NgRx\\|createAction' → NgRx store?"
    - "Grep: 'BehaviorSubject.*service' → service-based state?"
    - "Grep: 'signal\\(' in services → signal-based state?"

  api_patterns:
    - "Grep: 'HttpClient\\|httpResource\\|resource\\(' → HTTP approach?"
    - "Grep: 'interceptor' → interceptors in use?"
    - "Grep: 'environment\\.' → environment config pattern?"

  css_patterns:
    - "Grep: 'var(--' → CSS custom properties?"
    - "Grep: '@mixin\\|@include' → SCSS mixins active?"
    - "Grep: 'ViewEncapsulation.None' → global styles leak?"
```

### 4. Lessons Learned
Collect from past pipeline runs:
```yaml
sources:
  - "docs/plans/*/code-review.md — issues found"
  - "docs/plans/*/evaluate.md — deviations documented"
  - "docs/plans/*/metrics.yaml — recurring patterns"
  - ".claude/agent-memory/ — if exists"
  - "git log --oneline -50 — recent commit patterns"

extract:
  - "Recurring code review issues (same issue in multiple reviews)"
  - "Common build failures"
  - "Patterns that caused regressions"
```

## Output Format

Write to `.claude/project-practices.md`:
```markdown
# Project Practices
Generated: {date}
Project: {name}

## Architecture
- Type: {Nx monorepo / standalone / etc}
- Style: {SCSS / Tailwind / etc}
- State: {NgRx / signals / services}
- HTTP: {httpResource / HttpClient / etc}

## Path Aliases
| Alias | Path |
|-------|------|
| @app/* | src/app/* |

## Build Commands
| Command | Script |
|---------|--------|
| lint | npx nx lint {app} |
| test | npx nx test {app} |
| build | npx nx build {app} |

## Project-Specific Patterns
| Pattern | How | Where |
|---------|-----|-------|
| Notifications | SnackbarService.show() | shared/services |
| Auth | AuthGuard + JWT interceptor | core/auth |
| Clipboard | navigator.clipboard (no service) | — |

## Known Bugs & Workarounds
| Bug | Workaround | File |
|-----|-----------|------|
| {description} | {workaround} | {location} |

## Lessons Learned
| Lesson | Source | Impact |
|--------|--------|--------|
| SVG icons: never draw manually | ARGO-10743 code-review | HIGH |
| CI disabled on feature branches | developer workflow | MED |

## Rules
- {rule from CLAUDE.md or .claude/rules/}
- {rule from detected patterns}
```

## Update Mode

When `.claude/project-practices.md` exists:
1. Read existing
2. Rescan
3. Show diff: NEW / CHANGED / REMOVED entries
4. Merge (keep manual entries, update auto-detected)

## When to Run

- First time setting up skills in a project
- After major refactoring
- Monthly refresh
- When pipeline keeps hitting the same issues
