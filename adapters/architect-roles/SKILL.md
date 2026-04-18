---
name: adapter-architect-roles
description: "Architect role adapter. Provides stack-specific lenses for architect agents. Loaded by planner when architect step runs."
disable-model-invocation: true
---

# Architect Roles Adapter

Defines 3 lenses per tech stack for architect agents. Each lens has a name, focus area, and codebase research method.

## Contract

```yaml
type: architect-roles

provides:
  roles:
    lens_1: { name: string, focus: string, codebase_research: string }
    lens_2: { name: string, focus: string, codebase_research: string }
    lens_3: { name: string, focus: string, codebase_research: string }
  stack_constraints: string[]
  generated_context: string[]

consumes:
  tech_stack_adapter: "for codebase research methods referenced in codebase_research"

loading:
  method: "Read YAML file matching detected stack"
  lookup: "adapters/architect-roles/{stack}.yaml"
  fallback: "adapters/architect-roles/generic.yaml"
  override: "--stack flag from /arch or pipeline"
```

## Adapter Files

| File | Stack | Lenses |
|------|-------|--------|
| angular.yaml | Angular/Nx | Component, State & Data, Integration |
| generic.yaml | Any (fallback) | Structure, Data, Quality |
