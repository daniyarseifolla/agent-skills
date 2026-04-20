#!/bin/bash
# Contract validation: checks adapter SKILL.md files for required methods
# and core/orchestration/SKILL.md for checkpoint schema fields.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local file="$ROOT/$1" method="$2"
  local alt; alt=$(echo "$method" | sed 's/_/ /g')
  if grep -qi "$method" "$file" 2>/dev/null || grep -qi "$alt" "$file" 2>/dev/null; then
    printf "  %-24s \xe2\x9c\x93\n" "$method"
    PASS=$((PASS + 1))
  else
    printf "  %-24s FAIL\n" "$method"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Contract Validation ==="
echo ""

# --- task-source ---
echo "adapter-jira (task-source):"
for m in fetch_task fetch_attachments parse_ac get_complexity_hints transition format_mr_description; do
  check adapters/jira/SKILL.md "$m"
done
echo ""

# --- ci-cd ---
echo "adapter-gitlab (ci-cd):"
for m in create_mr get_pipeline wait_for_stage deploy retry_job create_tag; do
  check adapters/gitlab/SKILL.md "$m"
done
echo ""

# --- tech-stack ---
echo "adapter-angular (tech-stack):"
for m in commands quality_checks security_checks api_discovery patterns module_lookup; do
  check adapters/angular/SKILL.md "$m"
done
echo ""

# --- design ---
echo "adapter-figma (design):"
for m in parse_urls get_design get_screenshot compare_visual extract_tokens; do
  check adapters/figma/SKILL.md "$m"
done
echo ""

# --- architect-roles ---
echo "adapter-architect-roles (architect-roles):"
for m in roles stack_constraints generated_context; do
  check adapters/architect-roles/SKILL.md "$m"
done
echo ""

# --- notification ---
echo "adapter-slack (notification):"
for m in notify_deploy; do
  check adapters/slack/SKILL.md "$m"
done
echo ""

# --- checkpoint schema ---
echo "checkpoint schema:"
for f in task_key completed resume phase_name iteration verdict complexity route timestamp; do
  check core/orchestration/SKILL.md "$f"
done
echo ""

# --- summary ---
TOTAL=$((PASS + FAIL))
echo "=== Summary: $PASS/$TOTAL passed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "$FAIL method(s) missing — check output above."
  exit 1
fi
echo "All contracts satisfied."
