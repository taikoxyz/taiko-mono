# Signing rights, exit escrow and the evidence window

The new results strengthen the registry trajectory argument without strengthening H1–H3 or assuming a bond remains live. They do **not** establish an unconditional equivalence between cryptographic commit validity, current signing authority and current positive collateral.

## General results

`EtnaProofs/SigningEscrow.lean` proves:

- `trace_clocked` and `trace_confirmation_lower_bound`: every original `ProtocolState.Step` is handled. Starting with no future-dated confirmations, a retained confirmation cannot be in the future; a confirmation introduced after an initially unconfirmed state cannot predate that state's L1 clock. Clearing a confirmation and confirming again cannot backdate it. `trace_withdrawal_lower_bound` combines this with the actual withdrawal guard. Registration, slot reuse, request/confirm/withdraw, top-up/activation, slash, forfeiture, FI enqueue/sweep, recovery, nonce invalidation and rollback are included.
- `trace_covered`: every retained confirmation is covered by slot 284 under the explicit `SnapshotTrace` condition. Each edge is an original step, with either a nondecreasing snapshot or the exact exceptional rollback transformer. `snapshot_trace_projects` gives the original trace. Rollback's recheck establishes coverage even for an arbitrary restored number; trusting that number is a separate, stronger requirement. `trace_withdrawal_window` combines the trajectory clock invariant with `withdrawal_window`, obtaining the recorded confirmation, full registry withdrawal delay, covered effective exit, exact principal payout and zero output balance from successful withdrawal. There is no positive/live escrow premise.
- `trace_keys_well_formed`, `unallocated_trace_keys_well_formed`: allocated nonzero identities remain in the lifetime used-key set and cannot occur in two allocated slots. This is derived from zero allocated slots with arbitrary configured immutables. Public registration freshness, edit identity-or-zero, recovery and recheck behavior provide the proof; existing `Core.identities` alone was weaker.
- `step_exit_link`: a finite, nonzero post-step occupant either retains the same old key and exit or its effective exit is at or beyond the transaction's L1 clock. Delayed requestExit establishes the latter; slash/forfeit/recovery `min(old, now)` either retain the old barrier or establish one exactly at now. A fresh registration has no finite exit.
- `trace_exit_visible`, `unallocated_trace_exit_visible`: under the original structural `Core`, lifetime uniqueness and initial exit-history invariant, **every finite current exit E is visible to all typed registry lookups at cutoffs >= E**. Zero-slot initial states establish the identity and initial exit-history invariants. Checkpoints written by actual entry-changing operations, including same-block replacement, provide the historical linkage.
- `unallocated_effective_exit_excluded_forever`: once a key has finite exit E, all later registry lookups at cutoff >= E exclude it, through arbitrary original traces including withdrawal, slot reuse, recovery and verifier rollback. The final slot need not still hold the key. This closes the conservative earlier gap for cutoffs between effective exit and confirmation time.
- `selected_excludes_confirmed_key` applies that history exclusion to an actually built historical context and its chosen committee. `confirmed_key_absent_later_cutoff` combines this with coverage: if the selected cutoff is >= the confirmation state's stored snapshot, its selected members cannot contain the confirmed lifetime key. Its explicit cutoff hypothesis is a chain/history fact, not an assumption that escrow is locked.
- `retired_generation_never_revives`: retirement persists through arbitrary successful signatures, domain switches and session openings. Old generations cannot resume signing after later generations reopen sessions. Authentication of generation/session trust remains an adapter boundary.

`SnapshotTrace` is a refinement used only for the extra coverage theorem, not an observer replacing the original machine. There is no completeness claim that every unrestricted `ProtocolState.Trace` has this refinement: the model accepts landing inputs whose archived context/endpoint relation is not established. All original traces receive the unconditional clock, identity, exit-history and lifetime-exclusion results under their stated structural initial conditions.

The evidence period is `withdrawalDelay` **in L1 blocks from the retained successful confirmation**, as SPEC 4.1 states. Ordinary repeated confirmation, slash and forfeiture do not reset it. If rollback clears an uncovered confirmation, a fresh confirmation starts the full delay again. It does not run from requestExit or the effective exit. A halt before confirmation cannot consume the period. Neither the period nor these proofs guarantee that evidence is observed, published, finalized or acted on by the DAO before withdrawal.

## Two distinct checked limits

### Historical validity after ordinary withdrawal

`EtnaWitnesses/Counterexamples/HistoricalEscrow.lean`, theorem `ordinary_exit_and_historical_validity`, gives an executable original-machine trace:

1. Existing initialized deployment, key 7 active; standby key 8 registers at L1 15 and activates at 17.
2. Key 7 requests exit at L1 16, effective at 17.
3. A 12-block `BlockValidity.Chain` crosses the ordinary H(1)=11 handover. D(1)=8 has anchor 24; key 8 replaces key 7.
4. An accepted landing at L1 29 writes checkpoint 12 and snapshot 24. Confirmation records 29. Withdrawal at 29 fails; withdrawal at 30 pays the entire principal under this fixture's one-block delay.
5. On the final World, deployment-built historical rules still validate key 7's height-1 commit. Key 7 alone is rejected at fresh height 13.

There is **no recovery or rollback** in this trace. `snapshot_exit_trace` and `trajectory_invariants` apply the general snapshot and clock results to it. Header hashes and EL consistency use the existing non-vacuity adapters; signature, committee-storage and complete history authentication remain explicit decoded-fixture adapter boundaries. This is a historical-validation/weak-subjectivity boundary, not an attack on an authenticated current checkpoint or proof that withdrawn keys can extend the actual trusted chain. It shows why the earlier untrusted-rollback counterexample is not the only reason unrestricted `CommitValid -> current escrow` is false.

### Current fixed voting power after all collateral has been slashed

`EtnaWitnesses/Regressions/SigningEscrow.lean`, theorem `current_voting_power_survives_full_slash`, uses the existing three-validator non-vacuity deployment and all seven of its `Premises`. Key 9 has one sixth of the selected power and admissible same-round conflicting evidence. An actual successful `ProtocolState.Step.modification` at L1 15 slashes its whole entry. Deployment-built rules still give it positive voting power at height 1, above current checkpoint 0, in the same active generation 0. A valid height-1 commit including key 9 exists while that entry's balance is zero. Its unconfirmed entry cannot be withdrawn even after a long wait.

This is a real limitation of a stronger proposed invariant that every currently selected voting unit always has positive remaining collateral. It follows the specified fixed historical committee selection and already-executed whole-balance punishment; it is not a premature withdrawal. It does not contradict the original less-than-one-third Byzantine-power assumption or H2 finality. Additional misconduct cannot slash principal already exhausted by the earlier punishment, and the fixed committee changes only on later activation or recovery.

The witness establishes **future-height current-generation voting authority**, not a timestamped new cryptographic signing event: `World` does not record actual EL tips or signature creation time, and the accepted signature relation includes already-cast votes. This distinction is necessary; no absent fresh-signing model bridge is silently assumed.

## Follow-up: typed signer/prefix connection

The following section records the bridge obligations identified by this trajectory batch.
The later [signer/prefix connection](signing-prefix-connection.md) now models the local prefix
and actual Signer.sign event explicitly, derives the cutoff bound, and supplies initialized
positive and typed stale-view witnesses. The remaining obligations are real adapter/producer
refinement, causal view freshness and inclusion relative to confirmation, and authentic
rollback/session revalidation. The older `Built`/World/headline premises alone still do not
supply them.

### Original boundary inventory

SPEC 4.3, 8 and 9 require more than `Built`:

- The actual local EL/Comet prefix must extend the exact authenticated latest checkpoint and the correct fixed generation origin, with current/pending committees derived from the authenticated switches of that same prefix.
- The archive queried for D(t), the landing's terminal committee cutoff and the signer's actual next height must refer to that same prefix. Prefix extension and its nondecreasing authenticated anchor history must show that the selected signing cutoff is at least the stored snapshot relevant to exit confirmation.
- Historical registry openings must be authenticated under the specified L1 roots and actually be latest at the selected cutoff. Typed registry trajectory proofs establish the consequences once this authentication and prefix linkage are supplied.
- Session readiness and `Request.trusted` must be linked to actual finalized-L1 checkpoint/generation checks and the corresponding real signing event. They are booleans in the present signer model; the actual EL signing tip is absent from `World`.
- Exceptional rollback must restore the value written by the last trusted landing (or initialization), with the registry recheck, rather than merely an arbitrary number below the rollback's clock. `SoundTrace`'s numeric snapshot bound alone is weaker than this governance duty.

`Built` currently accepts arbitrary sorted archives and reference inputs; the seven headline premises do not authenticate a common retained archive/local signing prefix. Therefore these proofs **do not claim full fresh-signing/escrow safety** merely from `Built`, `Run` or those seven premises. The exact missing theorem is the authenticated-prefix-to-selected-cutoff relation used explicitly by `confirmed_key_absent_later_cutoff`, plus a real signing-event linkage. This is a model/external boundary, not a demonstrated SPEC-compliant fresh-signing withdrawal exploit.

The generation/domain result separately prevents a retired full chain-id generation from returning via signer operations. It does not implement L1 authentication, key fencing or a complete node/EL forkchoice process.

## Verification of the trajectory batch

Pinned Lean 4.35.0-rc4. The central integration build and strict audit passed: 851 exact theorem contracts, mechanically checked roles, standard axioms only, fresh kernel replay of the full import closure, unchanged seven-field headline premise use, fresh vectors and nine silent Lean regression modules. `trace_withdrawal_window` also combines the whole-trajectory clock result with the exact recorded confirmation, full withdrawal delay and principal payout.

The general trajectory goals were checked before and after their proofs, and kernel evaluation rejects positive collateral in both the ordinary-withdrawal final state and the still-current slashed-member state. Independent semantic review found no Critical/Important findings. The complete Python regression/mutation result and source inventory totals are recorded in the package README and the trajectory assurance report.

Sources: [SPEC 4.1–4.3 and 8–9](../../../packages/protocol/docs/etna-pos-zk/SPEC.md), [ProtocolState](../EtnaModel/ProtocolState.lean), [HistoricalContext](../EtnaModel/HistoricalContext.lean), [Signer](../EtnaModel/Signer.lean), [existing untrusted rollback boundary](../EtnaWitnesses/Counterexamples/UntrustedRollback.lean).
