# Agent Skills v2.2

Reusable development pipeline skills for Claude Code with swappable adapters.

## Install

```bash
cd ~/Desktop/pet/agent-skills

# Skills → global
for dir in v2.2/core/*/; do mkdir -p ~/.claude/skills/$(basename $dir) && cp "$dir/SKILL.md" ~/.claude/skills/$(basename $dir)/SKILL.md; done
for dir in v2.2/pipeline/*/; do
  name=$(basename $dir)
  [ "$name" = "figma-coding-rules" ] && target=$name || target="pipeline-$name"
  mkdir -p ~/.claude/skills/$target && cp "$dir/SKILL.md" ~/.claude/skills/$target/SKILL.md
done
for dir in v2.2/adapters/*/; do mkdir -p ~/.claude/skills/adapter-$(basename $dir) && cp "$dir/SKILL.md" ~/.claude/skills/adapter-$(basename $dir)/SKILL.md; done
for dir in v2.2/facades/*/; do mkdir -p ~/.claude/skills/$(basename $dir) && cp "$dir/SKILL.md" ~/.claude/skills/$(basename $dir)/SKILL.md; done

# Commands → global
cp v2.2/commands/*.md ~/.claude/commands/

# Hook
cp v2.2/scripts/figma-verify-reminder.sh ~/.claude/scripts/
```

## Configure

```yaml
# .claude/project.yaml
version: "2.2"
task-source: jira
ci-cd: gitlab
tech-stack: angular
design: figma
api:
  swagger_url: "https://api.dev.project.com/swagger/v1/swagger.json"
```

Or skip — worker autodetects from project files.

## Use

```
/worker ARGO-12345              # full pipeline
/figma <figma-url> [app-url]   # figma audit + fix
/deploy test                    # deploy
/sync                           # sync community branches
```

## Source of Truth

**This repository is canonical.** `~/.claude/skills/` is the install target, not the source. All edits should be made in `v2.2/` and synced to global.

See [SKILLS_OVERVIEW.md](SKILLS_OVERVIEW.md) for full architecture and catalog.
