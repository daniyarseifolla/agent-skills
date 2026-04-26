#!/bin/bash
# Trigger-eval validator: checks structure and coverage of trigger-eval.json files.
# Each facade must have ≥20 queries, balanced true/false, valid JSON.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

fail() { printf "  FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }
pass() { PASS=$((PASS + 1)); }

echo "=== Trigger Eval Validation ==="

for eval_file in $(find "$ROOT/facades" "$ROOT/adapters" -name 'trigger-eval.json' -not -path '*/.tmp/*' 2>/dev/null | sort); do
  rel="${eval_file#$ROOT/}"
  skill_dir="$(dirname "$(dirname "$eval_file")")"
  skill_name="$(basename "$skill_dir")"

  # --- Valid JSON ---
  if ! jq empty "$eval_file" 2>/dev/null; then
    fail "$rel: invalid JSON"
    continue
  else
    pass
  fi

  # --- Must be array ---
  is_array=$(jq 'type' "$eval_file" 2>/dev/null | tr -d '"')
  if [ "$is_array" != "array" ]; then
    fail "$rel: root must be JSON array, got '$is_array'"
    continue
  else
    pass
  fi

  # --- Entry count ≥ 20 ---
  total=$(jq 'length' "$eval_file")
  if [ "$total" -lt 20 ]; then
    fail "$rel: $total entries (need ≥20)"
  else
    pass
  fi

  # --- Each entry has query (string) + should_trigger (boolean) ---
  bad_entries=$(jq '[.[] | select((.query | type) != "string" or (.should_trigger | type) != "boolean")] | length' "$eval_file")
  if [ "$bad_entries" -gt 0 ]; then
    fail "$rel: $bad_entries entries missing query/should_trigger"
  else
    pass
  fi

  # --- Balance: at least 5 true and 5 false ---
  true_count=$(jq '[.[] | select(.should_trigger == true)] | length' "$eval_file")
  false_count=$(jq '[.[] | select(.should_trigger == false)] | length' "$eval_file")
  if [ "$true_count" -lt 5 ]; then
    fail "$rel: only $true_count positive cases (need ≥5)"
  else
    pass
  fi
  if [ "$false_count" -lt 5 ]; then
    fail "$rel: only $false_count negative cases (need ≥5)"
  else
    pass
  fi

  printf "  %-30s %d entries (%d true, %d false) \xe2\x9c\x93\n" "$skill_name" "$total" "$true_count" "$false_count"
done

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Triggers: $PASS/$TOTAL passed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "$FAIL issue(s) found."
  exit 1
fi
