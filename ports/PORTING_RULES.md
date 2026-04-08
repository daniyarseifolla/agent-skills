# Porting Rules

## Scope

This directory contains two parallel port lines for `v2.2` skills:

- `ports/literal/` — strict-copy port with minimal mechanical adaptation
- `ports/codex-native/` — reserved for a future Codex-native rewrite

## Literal Port Rules

The literal port is intentionally conservative. It preserves:

- original folder structure
- original section order and body text
- original contracts, artifacts, checkpoints, and phase boundaries
- original frontmatter keys other than `name`

The literal port applies only these mechanical changes:

1. Rewrite `name:` to a unique Codex-safe namespace.
2. Rewrite explicit cross-skill references to the new literal names where those references point to other ported skills.

## Naming Scheme

Source skill names are rewritten as:

- `core/*` -> `literal-core-*`
- `pipeline/*` -> `literal-pipeline-*`
- `adapters/*` -> `literal-adapter-*`
- `facades/*` -> `literal-facade-*`

Examples:

- `core-orchestration` -> `literal-core-orchestration`
- `pipeline-worker` -> `literal-pipeline-worker`
- `adapter-jira` -> `literal-adapter-jira`
- `deploy` -> `literal-facade-deploy`

## Intentional Non-Changes

The literal port does not yet normalize:

- Claude-specific tool naming in prose/frontmatter
- model labels such as `opus`, `sonnet`, `haiku`
- `.claude/*` paths
- Claude-oriented operational assumptions

Those belong to the future `codex-native` rewrite.

## Validation Standard

Literal port acceptance criteria:

- every `v2.2` skill has a mirrored `ports/literal/.../SKILL.md`
- every mirrored file has a unique literal `name:`
- obvious cross-skill references use the literal names
- no structural or behavioral rewrite is introduced beyond mechanical adaptation
