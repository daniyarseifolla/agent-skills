#!/bin/bash
# Doc-drift check: verify SKILLS_OVERVIEW.md counts match actual files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERVIEW="$ROOT/SKILLS_OVERVIEW.md"
PASS=0; FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" -eq "$expected" ]; then
    printf "%-12s found %-3d expected %-3d \xE2\x9C\x93\n" "$label:" "$actual" "$expected"
    PASS=$((PASS + 1))
  else
    printf "%-12s found %-3d expected %-3d \xE2\x9C\x97 (drift!)\n" "$label:" "$actual" "$expected"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Agent Skills Drift Check ==="

# Count actual files
CMD_ACTUAL=$(find "$ROOT/commands" -maxdepth 1 -name '*.md' ! -iname 'readme*' | wc -l | tr -d ' ')
PIPE_ACTUAL=$(find "$ROOT/pipeline" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')
FAC_ACTUAL=$(find "$ROOT/facades" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')
ADP_ACTUAL=$(find "$ROOT/adapters" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')
CORE_ACTUAL=$(find "$ROOT/core" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')

# Expected counts from SKILLS_OVERVIEW.md (header + table rows)
CMD_EXPECTED=$(grep -oE 'Commands \([0-9]+ slash commands\)' "$OVERVIEW" | grep -oE '[0-9]+')
PIPE_EXPECTED=$(grep -cE '^\| pipeline/' "$OVERVIEW")
FAC_EXPECTED=$(grep -cE '^\| facades/' "$OVERVIEW")
ADP_EXPECTED=$(grep -cE '^\| adapters/' "$OVERVIEW")
CORE_EXPECTED=$(grep -cE '^\| core/' "$OVERVIEW")

check "Commands" "$CMD_ACTUAL" "$CMD_EXPECTED"
check "Pipeline" "$PIPE_ACTUAL" "$PIPE_EXPECTED"
check "Facades" "$FAC_ACTUAL" "$FAC_EXPECTED"
check "Adapters" "$ADP_ACTUAL" "$ADP_EXPECTED"
check "Core" "$CORE_ACTUAL" "$CORE_EXPECTED"

# Adapter frontmatter: all must have disable-model-invocation: true
ADP_DISABLED=$(grep -rl 'disable-model-invocation: true' "$ROOT/adapters" --include='SKILL.md' | wc -l | tr -d ' ')
if [ "$ADP_DISABLED" -eq "$ADP_ACTUAL" ]; then
  printf "Adapter FM:  %d/%d have disable-model-invocation \xE2\x9C\x93\n" "$ADP_DISABLED" "$ADP_ACTUAL"
  PASS=$((PASS + 1))
else
  printf "Adapter FM:  %d/%d have disable-model-invocation \xE2\x9C\x97\n" "$ADP_DISABLED" "$ADP_ACTUAL"
  FAIL=$((FAIL + 1))
fi

# Line count accuracy: compare actual wc -l to values in SKILLS_OVERVIEW.md
LINECOUNT_WARN=0
echo ""
echo "--- Line Count Check (>10% drift = WARNING) ---"
for skill_md in $(find "$ROOT" -path '*/SKILL.md' -not -path '*/node_modules/*' | sort); do
  # Derive the skill path as it appears in the table (e.g., pipeline/worker)
  rel="${skill_md#$ROOT/}"          # e.g. pipeline/worker/SKILL.md
  skill_path="${rel%/SKILL.md}"     # e.g. pipeline/worker
  actual=$(wc -l < "$skill_md" | tr -d ' ')

  # Extract documented count from the overview table: "| pipeline/worker | 525 |"
  documented=$(grep -E "^\| ${skill_path} \|" "$OVERVIEW" | head -1 | awk -F'|' '{print $3}' | tr -d ' ' || true)
  if [ -z "$documented" ]; then
    printf "  %-35s actual %-4d  (not in SKILLS_OVERVIEW.md) \xe2\x9a\xa0\n" "$skill_path" "$actual"
    LINECOUNT_WARN=$((LINECOUNT_WARN + 1))
    continue
  fi

  # Calculate percentage difference
  if [ "$documented" -eq 0 ]; then
    pct_diff=100
  else
    diff=$((actual - documented))
    if [ "$diff" -lt 0 ]; then diff=$(( -diff )); fi
    pct_diff=$(( diff * 100 / documented ))
  fi

  if [ "$pct_diff" -gt 10 ]; then
    printf "  %-35s actual %-4d documented %-4d (%d%% drift) \xe2\x9a\xa0\n" "$skill_path" "$actual" "$documented" "$pct_diff"
    LINECOUNT_WARN=$((LINECOUNT_WARN + 1))
  fi
done

# Also check command files
for cmd_md in $(find "$ROOT/commands" -maxdepth 1 -name '*.md' ! -iname 'readme*' | sort); do
  cmd_name="/$(basename "$cmd_md" .md)"
  actual=$(wc -l < "$cmd_md" | tr -d ' ')

  documented=$(grep -E "^\| ${cmd_name} \|" "$OVERVIEW" | head -1 | awk -F'|' '{print $3}' | tr -d ' ' || true)
  if [ -z "$documented" ]; then
    printf "  %-35s actual %-4d  (not in SKILLS_OVERVIEW.md) \xe2\x9a\xa0\n" "commands${cmd_name}" "$actual"
    LINECOUNT_WARN=$((LINECOUNT_WARN + 1))
    continue
  fi

  if [ "$documented" -eq 0 ]; then
    pct_diff=100
  else
    diff=$((actual - documented))
    if [ "$diff" -lt 0 ]; then diff=$(( -diff )); fi
    pct_diff=$(( diff * 100 / documented ))
  fi

  if [ "$pct_diff" -gt 10 ]; then
    printf "  %-35s actual %-4d documented %-4d (%d%% drift) \xe2\x9a\xa0\n" "commands${cmd_name}" "$actual" "$documented" "$pct_diff"
    LINECOUNT_WARN=$((LINECOUNT_WARN + 1))
  fi
done

if [ "$LINECOUNT_WARN" -eq 0 ]; then
  printf "Line counts: all within 10%% tolerance \xE2\x9C\x93\n"
else
  printf "Line counts: %d file(s) drifted >10%% (WARNING, not a failure)\n" "$LINECOUNT_WARN"
fi
echo ""

# Stale directory references in top-level docs
DOCS="$ROOT/AGENT.md $ROOT/README.md $ROOT/SKILLS_OVERVIEW.md $ROOT/CLAUDE.md"
STALE=""
for dir in ports modules plugins extensions; do
  for doc in $DOCS; do
    [ -f "$doc" ] || continue
    if grep -q "\b${dir}/" "$doc" 2>/dev/null; then
      [ ! -d "$ROOT/$dir" ] && STALE="$STALE  $(basename "$doc") references $dir/ (missing)\n"
    fi
  done
done
if [ -z "$STALE" ]; then
  printf "Stale refs:  none found \xE2\x9C\x93\n"
  PASS=$((PASS + 1))
else
  printf "Stale refs:  \xE2\x9C\x97\n%b" "$STALE"
  FAIL=$((FAIL + 1))
fi

# Summary
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All $PASS checks passed."
else
  echo "$FAIL check(s) failed, $PASS passed."
  exit 1
fi
