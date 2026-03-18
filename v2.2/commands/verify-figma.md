---
description: "Verify ALL CSS properties against Figma for current branch. Usage: /verify-figma [figma-url]"
---

# Figma Verification

Arguments: $ARGUMENTS

## What this does

Compares EVERY CSS property of EVERY UI element against Figma design. Zero tolerance.

## Steps

1. Find Figma URLs:
   - If argument provided → use it
   - Else check docs/plans/*/plan.md for Figma Node Map
   - Else check Jira task for Figma URLs
   - Else ask user

2. For EACH Figma node in the design:
   - Call get_design_context(fileKey, nodeId)
   - Extract ALL CSS properties from code hints
   - Find corresponding element in code (by selector/class)
   - Read actual CSS from .scss/.css file
   - Compare property by property

3. Properties to check (EVERY element):
   - font-family, font-size, font-weight, line-height, letter-spacing, color
   - padding (top, right, bottom, left), margin, gap
   - width, height, min/max dimensions
   - background-color, border, border-radius, box-shadow, opacity
   - display, flex-direction, justify-content, align-items
   - ALL icons: correct icon, size, color

4. Output table:
   | Element | Property | Figma | Code | Match? |
   Fix ALL mismatches immediately.

5. Save results to docs/plans/{task-key}/figma-verify.md

## Tolerance
- Spacing/padding/margin: ±0px (exact)
- Font-weight: exact (700 ≠ 600)
- Colors: exact hex match
- Border-radius: exact
- Font-size: ±0px
- Layout direction: exact (row ≠ column)

## After verification
- Show summary: total elements, matches, mismatches fixed
- If all match → "Figma verification PASSED"
- If unfixable mismatches → list them and ask user
