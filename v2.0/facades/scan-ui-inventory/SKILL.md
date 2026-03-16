---
name: scan-ui-inventory
description: "Scan project for reusable UI components, SCSS mixins, and design tokens. Generates or updates .claude/ui-inventory.md. Use when user says \"скан UI\", \"scan UI\", \"обнови инвентарь\", \"update inventory\", \"scan components\", \"сканируй компоненты\", or when starting work on a new project."
allowed-tools: Read, Glob, Grep, Write, Bash(find *), Bash(wc *)
---

# Scan UI Inventory — Facade

Standalone skill. Scans project for shared components → generates .claude/ui-inventory.md.
Referenced by pipeline/planner, pipeline/code-reviewer, pipeline/ui-reviewer.

## Scan Targets

Scan these directories (adapt to actual project structure):
```yaml
targets:
  components:
    - "libs/shared/ui/**/*.component.ts"
    - "libs/shared/components/**/*.component.ts"
    - "libs/shared/dialogs/**/*.component.ts"
    - "src/app/shared/**/*.component.ts"

  mixins:
    - "**/*.mixins.scss"
    - "**/mixins/**/*.scss"

  tokens:
    - "**/variables.scss"
    - "**/tokens.scss"
    - "**/_variables.scss"
    - "**/design-tokens/**"

  pipes_directives:
    - "libs/shared/**/*.pipe.ts"
    - "libs/shared/**/*.directive.ts"
```

## Output Format

Write to `.claude/ui-inventory.md`:
```markdown
# UI Inventory
Generated: {date}

## Components
| Name | Path | Selector | Inputs | Usage |

## Mixins
| Name | File | Parameters | Usage |

## Design Tokens
| Token | File | Value | Usage |

## Pipes & Directives
| Name | Path | Type | Usage |
```

## When to Run

- First time setting up skills in a project
- After adding new shared components
- Before starting a large feature (refresh inventory)
