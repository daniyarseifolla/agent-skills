#!/bin/bash
# PostToolUse hook: reminds agent to run Figma Self-Verify after SCSS/CSS edits
# Triggered on: Write/Edit of *.scss, *.css, *.component.html files
# Input: JSON via stdin from Claude Code PostToolUse hook

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger for style and template files
case "$FILE" in
  *.scss|*.css|*.component.html)
    echo ""
    echo "FIGMA SELF-VERIFY REQUIRED"
    echo "You just modified: $FILE"
    echo ""
    echo "BEFORE moving to the next file, you MUST:"
    echo "1. Call get_design_context for EVERY element you changed"
    echo "2. Compare each CSS property: font-size, font-weight, padding, margin, gap, color, border-radius"
    echo "3. Fix any mismatch — use Figma value, not your approximation"
    echo "4. Tolerance: ±0px for spacing, exact match for font-weight and colors"
    echo ""
    echo "If you skip this step, the designer WILL find the errors."
    ;;
esac

exit 0
