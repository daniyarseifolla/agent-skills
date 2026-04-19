---
description: "Commit, push, and deploy. Usage: /ship [prod] [--mr] [--sync]"
human_description: "Commit + push + deploy в одну команду."
---

# Ship

Arguments: $ARGUMENTS

1. Load Skill: ship
2. Parse arguments:
   - `prod` → enable production deploy
   - `--mr` → create MR instead of direct push
   - `--sync` → run community sync after deploy
   - No args → commit + push + deploy test
3. Execute ship workflow with parsed flags
