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
