#!/bin/bash
# Frontmatter linter: validates SKILL.md frontmatter across all layers.
# Rules from docs/SKILL_AUTHORING.md.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

fail() { printf "  FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }
pass() { PASS=$((PASS + 1)); }

# Extract frontmatter field value from a SKILL.md file
get_field() {
  local file="$1" field="$2"
  (sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//') || true
}

echo "=== Frontmatter Lint ==="

for skill_md in $(find "$ROOT" -path '*/SKILL.md' -not -path '*/node_modules/*' -not -path '*/.tmp/*' | sort); do
  rel="${skill_md#$ROOT/}"
  skill_path="${rel%/SKILL.md}"
  layer="${skill_path%%/*}"  # adapters, pipeline, core, facades

  # --- name: must exist, kebab-case ---
  name=$(get_field "$skill_md" "name")
  if [ -z "$name" ]; then
    fail "$skill_path: missing 'name' field"
  elif ! echo "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    fail "$skill_path: name '$name' is not kebab-case"
  else
    pass
  fi

  # --- description: must exist, start with "Use when" ---
  desc=$(get_field "$skill_md" "description")
  if [ -z "$desc" ]; then
    fail "$skill_path: missing 'description' field"
  elif ! echo "$desc" | grep -qiE '^Use (when|PROACTIVELY|this)'; then
    # Allow "Use when", "Use PROACTIVELY when", "Use this skill"
    # Also check for common valid patterns in the raw frontmatter
    raw_desc=$(sed -n '/^---$/,/^---$/p' "$skill_md" | grep -E "^description:" | head -1 || true)
    if ! echo "$raw_desc" | grep -qiE 'Use (when|PROACTIVELY|this)'; then
      fail "$skill_path: description must start with 'Use when...'"
    else
      pass
    fi
  else
    pass
  fi

  # --- layer-specific rules ---
  case "$layer" in
    adapters|core)
      # Must have disable-model-invocation: true
      dmi=$(get_field "$skill_md" "disable-model-invocation")
      if [ "$dmi" != "true" ]; then
        fail "$skill_path: $layer skill missing 'disable-model-invocation: true'"
      else
        pass
      fi
      ;;
    pipeline)
      # Should have model field (unless disable-model-invocation: true — reference skills)
      dmi=$(get_field "$skill_md" "disable-model-invocation")
      model=$(get_field "$skill_md" "model")
      if [ "$dmi" = "true" ]; then
        pass  # reference skill, model not needed
      elif [ -z "$model" ]; then
        fail "$skill_path: pipeline skill missing 'model' field"
      elif ! echo "$model" | grep -qE '^(opus|sonnet|haiku)$'; then
        fail "$skill_path: model '$model' must be opus|sonnet|haiku"
      else
        pass
      fi
      ;;
    facades)
      # Should have trigger-eval.json
      eval_file="$(dirname "$skill_md")/evals/trigger-eval.json"
      if [ ! -f "$eval_file" ]; then
        fail "$skill_path: facade missing evals/trigger-eval.json"
      else
        pass
      fi
      ;;
  esac
done

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Frontmatter: $PASS/$TOTAL passed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "$FAIL issue(s) found."
  exit 1
fi
