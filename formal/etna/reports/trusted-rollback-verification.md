# Trusted rollback across recovery

> **Historical report.** This document describes the original model and the baseline identified below. Any use of “current” refers to that historical baseline. For the current `Etna.Design.Current` claims and evidence, read the [current scope](../README.md) and [latest alignment](latest-design-alignment.md).

Task 4 extends the decoded design proof package from base `a2cbbff99c` without changing any prior public theorem type, model transition, headline premise, normative specification or production code.

`CanonicalHistory.run_snapshot_below` exposes the source-history invariant already derived from valid accepted batches, decoded header/archive binding and raw origin/reference bounds. `SigningEscrow.later_generation_origin` proves by induction on unrestricted actual protocol transitions that a strictly newer generation's origin block is at least the source World’s L1 clock. Thus the exact source snapshot lies below every later recovery origin, including after arbitrarily many forged landings and recoveries. The recovery cutoff floor establishes `SnapshotTrusted` without requiring verifier soundness or canonical history on the suffix.

`certified_values_trusted_across_recoveries` retains exact checkpoint and snapshot provenance. `certified_rollback_excludes_confirmed_keys` composes the actual checked rollback, registry recheck and an existing `SnapshotTrace` to cover retained and later confirmations while the confirming World still displays those restored values. Initialization has its own later-World result. These are conditional exclusion results for the built context, not governance-spanning consensus agreement.

`rollback_interval_rejects_landing` covers arbitrary same-generation steps after rollback below the preserved origin: every retained record is lower than the origin, so neither another rollback nor registry/FI/nonce operations can enable a landing. The pruned origin record prevents construction of a `TrustState.Target`. Rollback consumes the recovery nonce, closes session trust and retains deployment, active/retired generations, HRS bytes and authenticated-generation knowledge.

The actual confirmation guards determine ordering. Recheck clears an exit when `restoredSnapshot < exitAt`; confirmation requires `exitAt <= currentSnapshot`. Recovery preserves the stored snapshot, even though it changes the new generation's initial committee cutoff. Therefore a cleared exit must wait for a valid snapshot-advancing landing before reconfirmation.

The nonvacuous witness executes:

1. Initialized registration and exit, then a certified height-1 landing at L1 block 29, snapshot 12.
2. Accepted forged height-2 landing with snapshot 1000, exit confirmation, and real recoveries to generations 1 and 2.
3. Checked rollback at block 33 to height 1/snapshot 12, preserving generation 2 and origin height 2, clearing the confirmation and pruning the origin record.
4. Real recovery to generation 3 at restored height 1, followed by a valid accepted landing advancing snapshot to 40, then reconfirmation at L1 block 42.
5. Actual immutable-key/encoder trust transitions using `switchDomain`, replay, exact match, `openSession` and `Signer.sign`; the prior HRS and watermark survive rollback and the old-generation request is rejected.

The restored and later contexts exclude exited key 7. A separate weak-source regression accepts snapshot 1000 with reference 28 and landing 29 under mere construction/certificate equality, documenting why the old same-generation hypotheses cannot establish the new bound.

Carried MinorM2 adds `LockingRegression.interleaving_all_actual`, checking every normalized observation against actual execution events while preserving `asynchronous_interleaving`’s type. Its mutation changes the sixth observation to a nonexistent round-5 event: all old order/two-vote checks still compile, and the new quantified check rejects it. No causal delivery model is introduced.

The full fresh formal audit passes 1,056 exact contracts, kernel replay, vectors, roles, shadowing, library contents, headline claims, transitive axioms and all 17 Lean regression modules. All 1,030 prior manifest entries and the original 954 declaration/type pairs are unchanged. Focused rollback tests pass 12/12, with silent Model-only baselines before unchanged proof layers reject every semantic mutation; locking/M2 tests pass 12/12. The complete Python regression/mutation suite passes: 267 tests in 295.367 seconds, with no failures, errors or skips.

Limits remain ideal decoded L1/crypto/EL truth, authenticated origin/header/storage inputs, authoritative durable signer/knowledge state and atomic decoded transactions. The proof does not reverse already paid funds or withdrawn stake, prove physical persistence, ensure timely governance action or establish agreement across recovery generations. Source coverage is traceability, not clause completeness.
