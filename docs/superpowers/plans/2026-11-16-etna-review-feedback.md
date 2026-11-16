# Etna PR feedback repair implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Track completed gates in the ledger; no automatic next batch.

**Goal:** Replace the invalid fresh-recovery fixture and make independent checks reject its recurrence before new verification work.

**Architecture:** Reuse the existing handoff model/public action engine, capture independent raw recovery/retained-parent premises, and strengthen the existing FreshIdentity oracle.

**Tech Stack:** Existing configured Python stdlib, Java17/TLC1.7.4, existing sensitivity runner and source pins.

**Spec:** `docs/superpowers/specs/2026-11-16-etna-review-feedback-design.md`.

## Global Constraints

- Baseline4c8b96c93; SPEC d18357214fab30ea512ae9858a11699806d72ba1; actual contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c.
- Preserve all339 configuration bytes and unrelated changes. No production/normative edits, new dependencies, duplicate caches, merge or deployment.
- Inspect/run code only through the existing offline read-only-source isolation; reuse normal signal disposition in disposable drivers.
- Root owns plan, ledger, final REPORT and publication. Author owns scoped formal model/module/sensitivity edits; independent reviewer/tester do not author the final implementation. No nested agents.
- Repair existing feedback before the next three-increment batch. Stop on independently supported actual protocol defects; verification defects are repaired separately. Maximum two material review/fix waves.

## Review Focus

- Recovery transaction time silently substituted for the retained parent's L2 timestamp.
- First-block BFT time confused with the general EL timestamp formula.
- An oracle reuses the operational constructor, or invalid candidate guards make a supposedly successful witness vacuous.
- Candidate parent/anchor/generation misbinding survives a timestamp-only check.
- Added fault obligations are omitted or run with incompatible runtime selectors.

## R0 — repair and publish the old feedback

- [x] Read complete feedback and independently reproduce the old invalid fresh receipt on all four relevant normal profiles.
- [x] Add independent audit/oracle and meaningful RED evidence before changing the constructor.
- [x] Construct a valid first block from immutable retained-parent metadata and recovery time; preserve all configs/public-call/export inputs.
- [x] Run all43 handoff configs, fresh witnesses, controls and three source faults normal/mutated/restored.
- [x] Update the required fault inventory/cohort partition; run the complete compatible campaign with exact aggregate coverage.
- [x] Complete independent adversarial review and behavioral challenges; original raiser rechecks fixes.
- [x] Root checks final frozen full339/Python regression, source pins/hashes, unchanged concrete replay inputs, full diff and hygiene.
- [x] Update the report and prepare accurate draft PR evidence; confirm the verified repair is ready for commit/push. Publication and exact remote-head readback are recorded in Git history and the ledger before new work.

Hourly monitoring is host-local runtime configuration, not part of this PR's
portable protocol verification artifacts. Its timer and queue semantics receive
separate focused verification and review.
