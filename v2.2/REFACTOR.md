# v2.2 Refactor Plan

Review results from 3 parallel agents (2026-03-21). Fix by priority.

## HIGH — Must fix

- [ ] **1. `/review` conflicts with Claude Code built-in** → rename to `/code-review` or `/cr`
- [ ] **2. pipeline-coder too long (549 lines)** → extract sections 8-8e into separate skill `figma-coding-rules` or split into `pipeline-coder` (implementation) + `pipeline-coder-figma` (verify)
- [ ] **3. Verdict mismatch** → unify: plan-reviewer uses `NEEDS_CHANGES`, code-reviewer uses `CHANGES_REQUESTED`. Pick one vocabulary or document mapping in core-orchestration
- [ ] **4. Tolerance conflict** → coder 8b: ±0px, ui-reviewer: ±2px. Make ui-reviewer stricter (±0px) or document why different
- [ ] **5. Duplicate ui-ux-pro-max** → remove from coder 8c, keep only in ui-reviewer (Phase 5). Coder uses refactoring-ui only
- [ ] **6. `/progress` references `/resume`** → fix to `/continue`
- [ ] **7. `/attach` bypasses checkpoints** → delegate to pipeline-worker resume mode or add checkpoint writing
- [ ] **8. Commit strategy undefined** → add to pipeline-coder: commit per part. Worker Phase 6: final merge commit or squash
- [ ] **9. "Task tool" → "Agent tool"** → fix in pipeline-planner, pipeline-code-researcher
- [ ] **10. Duplicate section numbers in adapter-gitlab** → renumber sections 5-14 correctly

## MEDIUM — Should fix

- [ ] **11. community-sync too thick** → extract workflow logic, move branch config to project.yaml
- [ ] **12. `/scan` ambiguous** → rename to `/scan-ui`, add `/scan-all` umbrella
- [ ] **13. core-security Angular-specific** → add framework-agnostic base section, move Angular patterns to subsection
- [ ] **14. core-metrics missing fields** → add: duration_per_phase, total_duration, success/failure flag, token_usage
- [ ] **15. Workspace setup not formalized** → add as Phase 0.5 or explicit step in Phase 0
- [ ] **16. No Figma API rate limiting** → add throttle guidance in adapter-figma (max 5 calls/sec, batch where possible)
- [ ] **17. No Angular version targeting** → add `angular_version: ">=19"` to adapter-angular, skip checks for older versions
- [ ] **18. Duplicate section "10" in pipeline-coder** → renumber to 10 (Component Reuse) + 11 (Library Code)

## LOW — Nice to have

- [ ] **19. SKILLS_OVERVIEW line counts stale** → regenerate from actual file sizes
- [ ] **20. project.yaml.example says v2.1** → update to v2.2
- [ ] **21. No `/scan-all` umbrella command** → add: runs scan-ui + scan-practices + scan-qa
- [ ] **22. No rollback command** → add `/rollback` using adapter-gitlab rollback workflow
- [ ] **23. `/continue` should fallback to heuristic recovery** when no checkpoint exists
- [ ] **24. Merge STANDARD and FULL routes** → they have identical phase lists, simplify to 2 routes
- [ ] **25. Add pause/resume messaging** → worker outputs "Resume with `/continue ARGO-XXX`" after each phase
- [ ] **26. Add Figma error handling** → adapter-figma: handle invalid fileKey, access denied, node not found
- [ ] **27. core-security: add modern threats** → prototype pollution, SSRF, open redirect, CSP, CORS checks
- [ ] **28. core-metrics: add aggregation implementation** → remove "future" placeholder or implement

## ORCHESTRATION — From swarm-coordination review (2026-03-23)

- [ ] **29. Add Iron Laws to core-orchestration** — 5 rules from swarm-coordination:
  1. Never spawn workers sequentially (parallel if independent)
  2. Always detect failures (structured error reporting, not silence = ok)
  3. No cross-worker communication (everything through orchestrator)
  4. Structured handoff required (mandatory template with Context/Findings/Recommendations/Artifacts)
  5. Max 7 workers per fan-out (reduce from current max 10 in ui-reviewer)

- [ ] **30. Add task classification to core-orchestration** — classify phases as:
  - Independent (can parallel): code-review + ui-review
  - Dependent (sequential): plan → plan-review, code → code-review
  - Fan-out/Fan-in: ui-reviewer test groups
  - Pipeline: the overall planner → coder → reviewer chain

- [ ] **31. Parallelize Phase 4 + Phase 5** — code-review and ui-review are independent, can run simultaneously. Worker currently runs them sequentially.

- [ ] **32. Structured agent error reporting** — every subagent must return `{ status: success|fail, findings: [], errors: [] }`, not free text. Worker must check status before proceeding.

- [ ] **33. Aggregation template for multi-agent results** — when fan-out agents complete, merge results into: consensus points, conflicts, combined recommendations.

## Notes

- pipeline-code-researcher scored 9/10, plan-reviewer 8.5/10 — don't touch these
- Overall architecture (facade → pipeline → core → adapter) is sound, no circular deps
- feature-dev plugin disabled globally (--scope user)
- 43 skills + 14 commands currently installed
