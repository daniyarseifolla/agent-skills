# v2.2 Refactor Plan

Review results from 3 parallel agents (2026-03-21). Fix by priority.

## HIGH — Must fix

- [x] **1. `/review` conflicts with Claude Code built-in** → renamed to `/cr` with `/code-review` alias
- [x] **2. pipeline-coder too long (549 lines)** → extracted sections 8-8e into `figma-coding-rules` skill. Coder has reference block in section 8.
- [x] **3. Verdict mismatch** → documented verdict vocabulary mapping in core-orchestration section 3
- [x] **4. Tolerance conflict** → coder 8b: ±0px, ui-reviewer: ±2px. Make ui-reviewer stricter (±0px) or document why different
- [x] **5. Duplicate ui-ux-pro-max** → remove from coder 8c, keep only in ui-reviewer (Phase 5). Coder uses refactoring-ui only
- [x] **6. `/progress` references `/resume`** → fixed to `/continue`
- [x] **7. `/attach` bypasses checkpoints** → added checkpoint writing after each phase dispatch + initial checkpoint in Phase 0
- [x] **8. Commit strategy undefined** → add to pipeline-coder: commit per part. Worker Phase 6: final merge commit or squash
- [ ] **9. "Task tool" → "Agent tool"** → fix in pipeline-planner, pipeline-code-researcher
- [ ] **10. Duplicate section numbers in adapter-gitlab** → renumber sections 5-14 correctly

## MEDIUM — Should fix

- [x] **11. community-sync too thick** → added config_source with project.yaml override note, moved Angular build fixes to adapter-angular section 8
- [x] **12. `/scan` ambiguous** → renamed to `/scan-ui`
- [x] **13. core-security Angular-specific** → add framework-agnostic base section, move Angular patterns to subsection
- [x] **14. core-metrics missing fields** → add: duration_per_phase, total_duration, success/failure flag, token_usage
- [x] **15. Workspace setup not formalized** → added as Phase 0.5 (workspace-setup) in pipeline-worker
- [x] **16. No Figma API rate limiting** → add throttle guidance in adapter-figma (max 5 calls/sec, batch where possible)
- [x] **17. No Angular version targeting** → add `angular_version: ">=19"` to adapter-angular, skip checks for older versions
- [ ] **18. Duplicate section "10" in pipeline-coder** → renumber to 10 (Component Reuse) + 11 (Library Code)

## LOW — Nice to have

- [ ] **19. SKILLS_OVERVIEW line counts stale** → regenerate from actual file sizes
- [x] **20. project.yaml.example says v2.1** → updated to v2.2
- [ ] **21. No `/scan-all` umbrella command** → add: runs scan-ui + scan-practices + scan-qa
- [ ] **22. No rollback command** → add `/rollback` using adapter-gitlab rollback workflow
- [x] **23. `/continue` should fallback to heuristic recovery** → added recovery table (Plan/Code/Tests/Reviews → resume phase)
- [ ] **24. Merge STANDARD and FULL routes** → they have identical phase lists, simplify to 2 routes
- [x] **25. Add pause/resume messaging** → added message block to after_phase in worker dispatch
- [x] **26. Add Figma error handling** → adapter-figma: handle invalid fileKey, access denied, node not found
- [x] **27. core-security: add modern threats** → prototype pollution, SSRF, open redirect, CSP, CORS checks
- [ ] **28. core-metrics: add aggregation implementation** → remove "future" placeholder or implement

## ORCHESTRATION — From swarm-coordination review (2026-03-23)

- [x] **29. Add Iron Laws to core-orchestration** — 5 rules from swarm-coordination:
  1. Never spawn workers sequentially (parallel if independent)
  2. Always detect failures (structured error reporting, not silence = ok)
  3. No cross-worker communication (everything through orchestrator)
  4. Structured handoff required (mandatory template with Context/Findings/Recommendations/Artifacts)
  5. Max 7 workers per fan-out (reduce from current max 10 in ui-reviewer)

- [x] **30. Add task classification to core-orchestration** — classify phases as:
  - Independent (can parallel): code-review + ui-review
  - Dependent (sequential): plan → plan-review, code → code-review
  - Fan-out/Fan-in: ui-reviewer test groups
  - Pipeline: the overall planner → coder → reviewer chain

- [x] **31. Parallelize Phase 4 + Phase 5** — merged into Phase 4+5 with parallel block, after_parallel logic, and loop back to coder on CHANGES_REQUESTED.

- [x] **32. Structured agent error reporting** — rewritten as verdict parsing protocol (keyword-based, not structured JSON). Added as section 12 in core-orchestration.

- [ ] **33. Aggregation template for multi-agent results** — when fan-out agents complete, merge results into: consensus points, conflicts, combined recommendations.

## CROSS-AGENT — Portability to other agents (Gemini, Codex, Kimi)

- [ ] **34. Share adapter-gitlab to ~/.agents/skills/** — symlink or copy adapter-gitlab for Gemini/Codex/Kimi. These agents only have `glab` CLI but no knowledge of: correct `glab api` syntax, JSON parsing workarounds, rate limits (30s between pushes), troubleshooting patterns. Adapter-gitlab solves this. Same applies to adapter-jira.

- [ ] **35. Share adapter-jira to ~/.agents/skills/** — same rationale. Other agents call Jira MCP but lack workflow knowledge (transitions, AC parsing, MR description generation).

- [ ] **36. Create lightweight adapter variants for non-Claude agents** — current adapters use Claude-specific features (allowed-tools, Skill tool). Strip those for a universal SKILL.md version that works everywhere.

- [ ] **37. MCP servers centralized in ~/.claude/.mcp.json** — context7, atlassian, figma already configured globally. Consider creating a shared `.mcp.json` at project level for team sync.

## Notes

- pipeline-code-researcher scored 9/10, plan-reviewer 8.5/10 — don't touch these
- Overall architecture (facade → pipeline → core → adapter) is sound, no circular deps
- feature-dev plugin disabled globally (--scope user)
- 43 skills + 14 commands currently installed
