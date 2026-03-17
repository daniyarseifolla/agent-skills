---
name: scan-ui-inventory
description: "Scan project for reusable UI components, SCSS mixins, and design tokens. Generates or updates .claude/ui-inventory.md. Use when user says \"скан UI\", \"scan UI\", \"обнови инвентарь\", \"update inventory\", \"scan components\", \"сканируй компоненты\", or when starting work on a new project."
allowed-tools: Read, Glob, Grep, Write, Bash(find *), Bash(wc *)
---

# Scan UI Inventory — Facade

Standalone skill. Scans project for shared components → generates .claude/ui-inventory.md.
Referenced by pipeline/planner, pipeline/code-reviewer, pipeline/ui-reviewer.

## Project Structure Detection

Before scanning, detect project structure:
```bash
# Find app directories
find . -name "app.module.ts" -o -name "app.config.ts" -o -name "app.component.ts" | head -5

# Find library directories
find . -path "*/libs/*" -name "public-api.ts" | head -10

# Check for UI libraries
grep -E "(angular/material|primeng|angular/cdk|ngx-|swiper)" package.json
```

Adapt scan paths based on detected structure.

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

  themes:
    - "**/theme.scss"
    - "**/themes/**/*.scss"
    - "**/*-theme.scss"

  css_custom_properties:
    command: "grep -rn '--[a-z]' **/*.scss | grep 'var(--' | sort -u"
    description: "CSS custom properties used across the project"
```

## Component Analysis

For each discovered component:
1. Read .component.ts → extract: class name, selector, inputs (signal-based or @Input), outputs
2. Read template (.html) → determine type: Form / Dialog / Button / Feedback / Navigation / Layout / Other
3. Count usage: grep selector across templates

Output per component:
| Name | Selector | Path | Type | Inputs | Outputs | Usage Count |

## Library Components

For each library in libs/:
1. Read public-api.ts (or index.ts)
2. List exported components, services, pipes, directives
3. Note: these are the ONLY importable items from each library

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

## Rules
- MUST reuse components from Shared Components before creating custom
- MUST use SCSS mixins for spacing, layout, typography
- MUST use design tokens (variables) for colors, font sizes, shadows
- NEVER hardcode hex colors — use CSS variables or SCSS variables
- When a shared component covers ≥80% of the need, extend it rather than create new

## Update Mode

When inventory already exists (.claude/ui-inventory.md):
1. Read existing inventory
2. Scan project
3. Compare: show NEW, REMOVED, UPDATED entries
4. Ask user: apply changes? (show diff)
5. Update file

## Report

After scan completes, show:
```
Scan complete:
- Shared components: {n}
- Library components: {n}
- SCSS mixins: {n}
- Design tokens: {n}
- UI libraries: {list}
```

## When to Run

- First time setting up skills in a project
- After adding new shared components
- Before starting a large feature (refresh inventory)
