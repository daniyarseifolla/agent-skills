#!/bin/bash
# Dependency resolver: validates all "Load Skill: X" references resolve to real skills.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

fail() { printf "  FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }
pass() { PASS=$((PASS + 1)); }

echo "=== Dependency Resolution ==="

# Build index of all known skill names (one per line in a temp file)
KNOWN=$(mktemp)
trap "rm -f $KNOWN" EXIT

for skill_md in $(find "$ROOT" -path '*/SKILL.md' -not -path '*/node_modules/*' -not -path '*/.tmp/*'); do
  name=$(sed -n '/^---$/,/^---$/p' "$skill_md" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' || true)
  if [ -n "$name" ]; then
    echo "$name" >> "$KNOWN"
  fi
done

skill_count=$(wc -l < "$KNOWN" | tr -d ' ')
echo "  Known skills: $skill_count"
echo ""

# Find all "Load Skill: X" references and check they resolve
found_refs=0
for skill_md in $(find "$ROOT" -path '*/SKILL.md' -not -path '*/node_modules/*' -not -path '*/.tmp/*' | sort); do
  rel="${skill_md#$ROOT/}"
  skill_path="${rel%/SKILL.md}"

  while IFS= read -r ref; do
    if [ -z "$ref" ]; then continue; fi
    found_refs=$((found_refs + 1))

    if grep -qx "$ref" "$KNOWN"; then
      pass
    else
      fail "$skill_path → Load Skill: $ref (not found in repo)"
    fi
  done < <(grep -oE 'Load Skill: [a-z0-9-]+' "$skill_md" 2>/dev/null | sed 's/Load Skill: //' || true)
done

echo ""
echo "  References found: $found_refs"
TOTAL=$((PASS + FAIL))
echo "=== Dependencies: $PASS/$TOTAL resolved ==="
if [ "$FAIL" -gt 0 ]; then
  echo "$FAIL unresolved reference(s)."
  exit 1
fi
