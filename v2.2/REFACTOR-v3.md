# v2.2 Refactor Plan v3

Consolidated refactor backlog for `v2.2/`.

Source inputs:
- legacy backlog from former `REFACTOR.md`
- consensus backlog from former `REFACTOR-v2.md`
- 3x3 audit refresh from `2026-03-30`

Rule for this file:
- keep only items that are still actionable or still important as design constraints
- drop stale completed checklist noise
- treat this file as the single source of truth for current refactor work

## Snapshot

- Current audit snapshot: architecture `5.3/10`, skill quality `5.9/10`, operability `4.8/10`, overall `~5.3/10`
- Main problem areas: contracts/recovery, layer purity, consensus drift, installability, cost control
- Target state after this refactor pass: `8.0+`

## Preserved Design Constraints

These are still valid and should not be lost during refactor:

- Keep `facade -> pipeline -> core -> adapters` as the intended architecture, but stop calling the pipeline `project-agnostic` until leakage is removed
- Keep verdict vocabulary centralized in `core-orchestration`
- Keep consensus review as an optional quality multiplier, not an unconditional default everywhere
- Keep intermediate `.tmp/` files as the preferred multi-agent coordination mechanism
- Keep WARN/install/skip/abort behavior for unavailable external skills instead of silent fallback

## P1: Contracts, Recovery, Phase Semantics (CRITICAL)

- [x] **1. Replace `max(completed_phases)` recovery with explicit resume state**
  Added `resume_phase`, `invalidated_phases`, `terminal_status` to checkpoint schema. `max()` is fallback only.

- [x] **2. Fix metrics phase normalization**
  Clean integer 0-8 mapping. Removed 1.5 contradiction. Synced core/orchestration + core/metrics.

- [x] **3. Align `/continue` with checkpoint schema**
  Added validation step (required/recommended fields), terminal status check, resume_phase primary/fallback.
  Follow-up: Added handoff_payload repair-from-artifacts. Added terminal cleanup protocol for re-entry.

- [x] **4. Rehydrate `credentials_path` before UI review**
  Added explicit rehydration protocol in /continue (step 8) and worker Phase 0.5 on_resume_skip.
  Follow-up: Added interactive repair paths (recreate worktree, prompt credentials, start dev server).

- [x] **5. Unify loop-back semantics for Phase 4+5**
  `CHANGES_REQUESTED` sets `invalidated_phases: [4, 5]`, `resume_phase: 3`. Added `invalidation_rules` to core-orchestration.
  Follow-up: Added worker before_phase guard enforcing invalidated_phases rerun. Added evaluate_return checkpoint_write to Phase 3. Added stopped_by_user producer path.

- [x] **6. Move metrics write to terminal events**
  Added `terminal_collection` to core-metrics. Worker error handlers write partial metrics before STOP.
  Follow-up: Fixed ordering: checkpoint → metrics → display (everywhere). Fixed phases_completed semantics: count (0-9), not phase ID.

- [ ] **7. Define `figma-audit` checkpoint protocol**  
  Give `figma-audit` resumable phases and preserved `.tmp/` state similar to the main worker pipeline.

## P2: Canonical Contracts and Layer Purity (CRITICAL)

- [ ] **8. Make `core-orchestration` the only source of truth for handoff envelopes**  
  Reviewer and worker skills must not depend on undeclared fields.

- [ ] **9. Remove stack leakage from `pipeline/*` and `core/*`**  
  Move Angular/Figma/Jira/browser-specific logic into adapters or explicit non-generic facades.

- [ ] **10. Add capability flags to adapters**  
  Introduce flags like `supports_design_review`, `supports_local_ui_testing`, `supports_task_transition`, `supports_api_discovery`.

- [ ] **11. Re-scope facades that bypass abstraction**  
  `community-sync` and `figma-audit` should either become thinner facades or be documented as specialized, non-generic flows.

- [ ] **12. Separate canonical rules from examples**  
  Mark examples as non-normative and stop mixing policy with stack-specific samples.

## P3: Consensus Topology and Review Contracts (CRITICAL)

- [ ] **13. Normalize consensus topology across files**  
  Plan review agent counts, mandatory fan-out wording, and section definitions must match across `core/consensus-review`, worker, and reviewer skills.

- [ ] **14. Normalize score and verdict models**  
  `ui-reviewer` must use one coherent scoring contract instead of mixing `%` and `1-10`.

- [ ] **15. Keep consensus optional by default**  
  Restore the original principle: expensive `3x3` review only for `L/XL` or explicit `--thorough`, not blanket default for `M`.

- [ ] **16. Add one reusable aggregation template**  
  Consensus points, conflicts, unique findings, combined recommendation format should be defined once and reused everywhere.

## P4: Operability and Cost Control (HIGH)

- [ ] **17. Fix `figma-audit` mode semantics**  
  `audit_only` must not require a live `app_url` path later in the same flow.

- [ ] **18. Stop wasting UI review runs**  
  Run `ui-reviewer` after code review passes, or preserve reusable partial results instead of throwing them away on rework.

- [ ] **19. Reorder expensive pre-checks**  
  Check `scope/UI?`, `figma_urls?`, `app_url/browser ready?`, `task-analysis sufficient?` before QA planning or heavy fan-out.

- [ ] **20. Remove duplicate heavy research**  
  Planner should not always spawn research fan-out if Phase `0.7` already produced enough task analysis.

- [ ] **21. Reduce redundant verification**  
  Avoid rerunning full expensive lint/test/research flows when a safe reuse signal already exists.

- [ ] **22. Add operational cost telemetry**  
  Track agent count, model mix, discarded review runs, retries, and fan-out size.

## P5: Installability and Day-1 UX (HIGH)

- [ ] **23. Fix install completeness**  
  Copy `templates/` and any runtime assets, not only `SKILL.md`.

- [ ] **24. Add `doctor` / readiness flow**  
  Verify MCP auth, `glab`, model access, external skills, and expected local URLs before first `/worker`.

- [ ] **25. Document dependency matrix**  
  For each command: required tools, optional tools, degraded mode, abort conditions.

- [ ] **26. Unify public naming**  
  Use one canonical naming scheme for core skills, facades, aliases, and commands across README, overview, and install docs.

- [ ] **27. Split facade vs direct-command routing in docs**  
  Stop implying every command flows through `Command -> Facade -> Worker`.

- [ ] **28. Generate catalog docs instead of hand-editing them**  
  `SKILLS_OVERVIEW.md` and `REPORT.md` should be generated or sharply reduced.

- [ ] **29. Remove dangling section references and doc drift**  
  Example: `/attach` pointing to a non-existent figma verify section.

## P6: Remaining Legacy Open Items

- [ ] **30. Add `/scan-all` umbrella command**  
  Run `scan-ui + scan-practices + scan-qa`.

- [ ] **31. Add rollback command**  
  Implement `/rollback` using adapter-gitlab rollback workflow.

- [ ] **32. Merge `STANDARD` and `FULL` routes if they remain identical**  
  Keep them separate only if they carry distinct execution meaning after the refactor.

- [ ] **33. Implement metrics aggregation or remove the placeholder entirely**  
  No more "not yet implemented" state in the active refactor target.

- [ ] **34. Share portable adapter variants for non-Claude agents**  
  Keep cross-agent portability on the backlog, but only after contracts are stable.

## Suggested Execution Order

1. `P1` — recovery/checkpoint/phase semantics
2. `P2` — canonical contracts and adapter boundaries
3. `P3` — consensus model normalization
4. `P4` — operability and cost controls
5. `P5` — installability, docs, naming
6. `P6` — secondary features and portability

## Notes

- `pipeline-code-researcher` remains one of the stronger pieces and should not be expanded casually.
- `plan-reviewer` should be kept, but only after its contract and consensus topology are normalized.
- This file replaces the old split between `REFACTOR.md` and `REFACTOR-v2.md`.
