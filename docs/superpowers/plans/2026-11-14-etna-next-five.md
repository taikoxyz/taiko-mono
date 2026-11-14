# Etna next five verification tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Check up to five successive Etna worklist boundaries, stopping on an independently supported protocol counterexample.

**Architecture:** Extend the existing formal project one bounded module at a time. Preserve earlier regressions and record the correspondence contracts needed for future composition and actual-code replay.

**Tech Stack:** TLA+/TLC 1.7.4, existing Java17 and Python runner; no production builds or new toolchain.

**Spec:** `docs/superpowers/specs/2026-11-14-etna-next-five-design.md`

## Global Constraints

- Preserve existing models, 63 configurations and shared runner.
- No normative SPEC edit, implementation fix, toolchain install, push or PR.
- Keep original checkout untouched and all artifacts portable.
- A module's narrower scope/exclusions must be explicit; inconclusive is not pass.
- Stop before the next task on a credible source-permitted protocol counterexample.
- Independent source review and behavioral verification for each non-trivial model.

## Review Focus

- Crash windows must not be hidden in atomic multi-store updates.
- Independent assertions must inspect actual state/history, not reuse a mutated decision.
- Different node knowledge, domains, and actual effective committee schedules are distinct.
- Known limitations and negative controls do not become newly discovered protocol bugs.
- Missing progress premises or implementation refinement must not be counted as proved.

## Task 1: M03 crash recovery

Create `formal/etna/EtnaSignerCrash.tla`, `EtnaAppCrash.tla`,
`configs/signer-crash-*.cfg`, `configs/app-crash-*.cfg` and `CRASH_RECOVERY.md`.

- [x] Pin actual signing/store/handshake sources and write expected outcomes first.
- [x] Implement explicit durable/volatile write, crash, replay/retry and trust gates.
- [x] Independently review source correspondence, behavior and assertion sensitivity.
- [x] Resolve findings, record hashes/counts/traces, commit locally and update worklist.
- [x] Apply stopping rule before Task 2.

## Task 2: M04 committee activation

Create `formal/etna/EtnaCommittee.tla`, `configs/committee-*.cfg`, `COMMITTEE.md`.

- [ ] Refresh source and refine the bounded selection/activation/recovery brief.
- [ ] Add H+2 schedule, snapshot/pending state and independent effective-set observer.
- [ ] Run positive/negative cases and independent review/behavior verification.
- [ ] Record results, commit, update worklist and apply stopping rule.

## Task 3: M05 registry lifecycle

Create `formal/etna/EtnaRegistry.tla`, `configs/registry-*.cfg`, `REGISTRY.md`.

- [ ] Refresh source and define bounded identity, slots, stake and confirmation state.
- [ ] Model delayed changes, displacement, exit/confirmation/withdrawal interleavings.
- [ ] Check fund/membership/confirmation properties with independent challenges.
- [ ] Record results, commit, update worklist and apply stopping rule.

## Task 4: M06 forced-inclusion queue

Create `formal/etna/EtnaForcedInclusion.tla`, `configs/fi-*.cfg`, `FORCED_INCLUSION.md`.

- [ ] Refresh source and define queue, anchors, actual consumption and blanking interfaces.
- [ ] Model due-head processing, FIFO cursors, landing and recovery interaction.
- [ ] Check safety plus explicit reachability/progress premises independently.
- [ ] Record results, commit, update worklist and apply stopping rule.

## Task 5: M07 proving/DA progress

Create `formal/etna/EtnaProvingProgress.tla`, `configs/progress-*.cfg`, `PROVING_PROGRESS.md`.

- [ ] Refresh source and define produced/anchored/landed heads, jobs and DA lifetime.
- [ ] Model delays/failures, expiry, back-pressure and candidate resumption paths.
- [ ] Check bounded safety and conditional progress/circular waits independently.
- [ ] Run complete accumulated suite, record full coverage/assumptions and limitations.
- [ ] Commit locally, update worklist and report the five-task result for later retrospective.
