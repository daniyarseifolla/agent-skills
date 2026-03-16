---
name: scan-ui-inventory
description: Scans project for reusable UI components, SCSS mixins, and design tokens, then generates or updates .claude/ui-inventory.md. Use when user says "скан UI", "scan UI", "обнови инвентарь", "update inventory", "scan components", "сканируй компоненты", or when starting work on a new project that has no .claude/ui-inventory.md yet.
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent
---

# Scan UI Inventory

Scans the project for shared UI components, SCSS mixins, design tokens, and UI libraries, then generates `.claude/ui-inventory.md`.

## When to Run

- First time working on a project (no `.claude/ui-inventory.md` exists)
- After adding new shared components or SCSS mixins
- User says "скан UI" / "scan components" / "обнови инвентарь"
- Called by jira-planner if no inventory file found (fallback)

## Step 1 — Detect Project Structure

```bash
# Find app directories
ls apps/*/src/app/ 2>/dev/null

# Find library directories
ls libs/*/src/lib/ 2>/dev/null

# Check package.json for UI libraries
cat package.json | grep -E '"@angular/material"|"primeng"|"@angular/cdk"|"ngx-|"swiper"' 2>/dev/null
```

## Step 2 — Scan Shared Components

```bash
# Find all component directories in shared/
find apps/*/src/app/shared -type d -name "*.component" -o -type f -name "*.component.ts" 2>/dev/null

# Find UI subdirectory components
find apps/*/src/app/shared/ui -type f -name "*.component.ts" 2>/dev/null

# Find dialog components
find apps/*/src/app/shared/dialogs -type f -name "*.component.ts" 2>/dev/null

# Find button components
find apps/*/src/app/shared/buttons -type f -name "*.component.ts" 2>/dev/null

# Find directives
find apps/*/src/app/shared -type f -name "*.directive.ts" 2>/dev/null

# Find services relevant to UI
find apps/*/src/app/shared -type f -name "*.service.ts" 2>/dev/null
```

For each component found:
1. Read the `.component.ts` file (class name, selector, inputs/outputs)
2. Briefly read the template to understand purpose
3. Categorize: Form / Dialog / Button / Feedback / Navigation / Other

## Step 3 — Scan Library Components

```bash
# Find library components
find libs/*/src/lib/components -type f -name "*.component.ts" 2>/dev/null

# Check what's exported from library public API
cat libs/*/src/index.ts libs/*/src/public-api.ts 2>/dev/null | grep -i "export"
```

For each exported component:
1. Read class name and selector
2. Note key inputs/outputs
3. Categorize

## Step 4 — Scan SCSS

### Mixins
```bash
# Find all mixin files
find apps/*/src/scss/mixins -type f -name "*.scss" 2>/dev/null

# Extract mixin names
grep -rn "@mixin " apps/*/src/scss/mixins/ 2>/dev/null
```

For each mixin: name, parameters, brief description of what it styles.

### Variables / Design Tokens
```bash
# Find color variables
find apps/*/src/scss/variables -type f -name "*.scss" 2>/dev/null

# Extract variable definitions
grep -rn '^\$' apps/*/src/scss/variables/ 2>/dev/null
```

Categorize: Colors (dynamic/theme-aware vs static), Sizes, Shadows, Typography.

### Themes
```bash
# Find theme files
find apps/*/src/scss/themes -type f -name "*.scss" 2>/dev/null
find apps/*/src/themes -type f -name "*.scss" 2>/dev/null

# Extract CSS custom properties
grep -rn '\-\-' apps/*/src/scss/themes/ 2>/dev/null | head -30
```

## Step 5 — Generate Inventory File

Write `.claude/ui-inventory.md` with this structure:

```markdown
# UI Inventory — {Project Name}

Reusable components, SCSS mixins, and design tokens available in this project.
Skills (jira-planner, jira-code-reviewer, jira-ui-reviewer) reference this file
to determine what to reuse vs create new.

## Shared Components

### {Category}
| Component | Path | Use for |
|-----------|------|---------|
| `{Name}` | `{path}` | {brief description} |

## Library Components ({library name})

| Component | Use for |
|-----------|---------|
| `{Name}` | {brief description} |

## SCSS Mixins

### {Category} (`{file path}`)
| Mixin | Use for |
|-------|---------|
| `@include mixins.{name}` | {description} |

## Design Tokens

### Colors (`{file path}`)
| Variable | Value | Use for |
|----------|-------|---------|
| `${name}` | {value or "theme-aware"} | {description} |

### Sizes
| Variable | Value | Use for |
|----------|-------|---------|

### Shadows
| Variable | Value |
|----------|-------|

## Rules

1. Always prefer existing components over creating new ones
2. Always use SCSS variables for colors — never hardcode hex or named colors
3. Always use button/typography mixins for consistent styling
4. Library code (libs/) is read-only — use output events, handle in app layer
```

## Step 6 — Report

Print summary:
```
UI Inventory generated: .claude/ui-inventory.md

Shared components: {N}
Library components: {N}
SCSS mixins: {N}
Design tokens: {N} colors, {N} sizes, {N} shadows
UI libraries: {list}
```

If `.claude/ui-inventory.md` already existed, show what changed (new/removed/updated entries).
