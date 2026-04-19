---
description: "Figma audit & implementation pipeline: consensus node map, visual + property comparison, subagent implementation. Usage: /figma <figma-url> [app-url]"
human_description: "Аудит вёрстки по Figma-макету."
---

# Figma Audit Pipeline

Arguments: $ARGUMENTS

## What this does

Loads the `figma-audit` skill to:
1. Build consensus node map from Figma design
2. Compare visual properties and layout against app
3. Spawn subagent for implementation of fixes

## Arguments

- `figma_url` (required): Figma design URL (figma.com/design/...)
- `app_url` (optional): Live app URL for comparison

## Skill

Load skill: `figma-audit`

If no arguments provided, ask user for Figma URL.
