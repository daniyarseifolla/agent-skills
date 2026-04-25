#!/bin/bash
# Sync repo skills → ~/.claude/skills/ as symlinks.
# Replaces stale copies with symlinks; never touches external symlinks.
# Run: bash scripts/install.sh

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$HOME/.claude/skills"
SYNCED=0; SKIPPED=0; CREATED=0

mkdir -p "$TARGET"

sync_skill() {
  local src="$1" dest_name="$2"
  local dest="$TARGET/$dest_name"

  # If symlink already exists
  if [ -L "$dest" ]; then
    local current_target
    current_target="$(readlink "$dest")"
    # Resolve to absolute for comparison
    local abs_current abs_src
    abs_current="$(cd "$TARGET" && cd "$(dirname "$current_target")" 2>/dev/null && pwd)/$(basename "$current_target")" 2>/dev/null || abs_current=""
    abs_src="$(cd "$src" && pwd)"

    if [ "$abs_current" = "$abs_src" ]; then
      SKIPPED=$((SKIPPED + 1))
      return
    fi

    # Symlink exists but points elsewhere (external skill) — don't touch
    if [[ "$current_target" == *".agents/skills/"* ]]; then
      SKIPPED=$((SKIPPED + 1))
      return
    fi

    # Symlink to different repo location — update
    rm "$dest"
    ln -s "$src" "$dest"
    printf "  updated  %-35s → %s\n" "$dest_name" "$src"
    SYNCED=$((SYNCED + 1))
    return
  fi

  # If directory exists (stale copy) — replace with symlink
  if [ -d "$dest" ]; then
    rm -rf "$dest"
    ln -s "$src" "$dest"
    printf "  replaced %-35s → %s\n" "$dest_name" "$src"
    SYNCED=$((SYNCED + 1))
    return
  fi

  # Nothing exists — create symlink
  ln -s "$src" "$dest"
  printf "  created  %-35s → %s\n" "$dest_name" "$src"
  CREATED=$((CREATED + 1))
}

echo "=== Syncing agent-skills → ~/.claude/skills/ ==="
echo ""

# Adapters: adapter-{name}
for skill in "$REPO"/adapters/*/SKILL.md; do
  dir="$(dirname "$skill")"
  name="$(basename "$dir")"
  sync_skill "$dir" "adapter-$name"
done

# Pipeline: pipeline-{name}
for skill in "$REPO"/pipeline/*/SKILL.md; do
  dir="$(dirname "$skill")"
  name="$(basename "$dir")"
  sync_skill "$dir" "pipeline-$name"
done

# Core: {name} (no prefix)
for skill in "$REPO"/core/*/SKILL.md; do
  dir="$(dirname "$skill")"
  name="$(basename "$dir")"
  sync_skill "$dir" "$name"
done

# Facades: {name} (no prefix)
for skill in "$REPO"/facades/*/SKILL.md; do
  dir="$(dirname "$skill")"
  name="$(basename "$dir")"
  sync_skill "$dir" "$name"
done

echo ""
echo "Done: $SYNCED replaced, $CREATED new, $SKIPPED unchanged."
