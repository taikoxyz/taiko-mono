# Alignment with merged PR #22341

Current authority: main `49df560256c3f20f0868f6c6e555443c2b1fd669` (2026-11-07), which merges
#22341 (three design gaps in trust, forced inclusion and rollback) on top of the
[#22338 pin](alignment-22338.md) `589b542de`. SPEC, ACCEPTANCE and `rules/INDEX.md` changed;
ANCHORLESS and SWITCH are byte-identical and are re-pinned to the same commit.

## What changed in the authorities

- **Forced inclusion admission (FI-7.1-1, FI-7.1-3).** A `tx` longer than 8,192 bytes reverts
  the submission; of the bytes, only the length is checked at submission.
- **Verifier-failure rollback (RECOV-8-26, new RECOV-8-27a, RECOV-8-35).** Voiding checkpoints
  does not revoke what they already authorized: a signal the L1 `SignalService` cached as
  received, and an L1 Bridge message left `RETRIABLE`. The rollback upgrade makes those from
  the first bad landing's L1 block on unusable until they are proven again, without taking a
  legitimate message's value or paying its fee twice. RECOV-8-35 adds state other contracts
  derived from bad checkpoints to what cannot be recovered. Section 1 lists the L1 Bridge
  among the upgradeable proxies.
- **Trust check source (SYNC-9-5, new SYNC-9-5c, DATA-5.4-8).** The node's own validator state
  at a height is the one it recorded when it committed that height in the current generation,
  never stock CometBFT's historical lookup.
- ACCEPTANCE adds a rollback exercise (section 2 item 6) and rewords the validator-state and
  import checks.

## Clause identities

Seven clauses changed text and one is new. Two of the changed clauses carry theorem edges;
their edges move to the new identities with unchanged roles:

| Old clause                 | New clause                 | Edges                                                                                                                                                   |
| -------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LIVE_EN-eb5074ad77d4a985` | `LIVE_EN-9a631b0ede20a8dd` | `admission_exact`, `admission_failure_atomic`, `forced_admission_accounting`, `refund_failure_rejected`, `underpayment_rejected` (FI-7.1-1, -2, -4, -7) |
| `LIVE_EN-ce821167c4d49d35` | `LIVE_EN-1079277c334a4883` | `coherent_signal_bounded`, `rollback_coherent`, `rollback_snapshot_provenance` (RECOV-8-27)                                                             |

- The FI edges still hold as written. `Forced.enqueue` already returns `none` for more than
  8,192 bytes, and `QueueIntegrity.AdmissionAccounting` concludes `raw ≤ 8192` for every
  successful admission, so the new revert sentence describes existing model behaviour.
- The rollback edges cover RECOV-8-27 only. The modelled `signals` are SignalService
  checkpoints, which rollback truncates; the receive cache and Bridge message states of
  RECOV-8-27a are not modelled. The edge reason and theorem scopes now say so.
- The other changed clauses (section 1 trust, DATA-5.4-8, SYNC-9-4/9-5 and two ACCEPTANCE
  items) and the new ACCEPTANCE item had no edges and stay deferred.

New rules RECOV-8-27a and SYNC-9-5c are deferred. Evidence after this pin: 38 partial / 530
deferred clauses; 41 partial / 36 supporting / 531 deferred binding rules.

## H1 restated over its own premises

`fund_safety`'s proof reads 5 of the 15 premise fields, and none of the 5 concerns consensus.
The statement now says so:

- `FundPremises` holds `currentPrimitives`, `currentVerifierSound`, `currentReferenceBinding`,
  `currentRegistryGenesis` and `currentUnzenExtension`.
- `Premises` extends `FundPremises` with the other ten fields. Field access is unchanged; the
  three witnesses that build `Premises` positionally nest the five fund fields.
- `FundSafety` quantifies over `FundPremises` and no engine:
  `∀ env registry, FundPremises env registry → ∀ w, Trace env (empty env registry) w → FundSafetyAt env registry w`.
  `FundSafetyAt` is unchanged, so H1 is strictly stronger. `deployed_claims` passes
  `premises.toFundPremises`.
- The audit runs a second premise-use check: every `FundPremises` field must be read by
  `fund_safety` alone. The `Premises` check now reports `toFundPremises` (read by H2 and H3)
  and the ten other fields.
- New tests: H1's type unfolds to the statement above; checking `FundPremises` against H2
  alone fails on the reference binding and the Unzen extension; and `FundSafety`'s dependency
  closure contains neither `Premises` nor any signature, codec, attribution, honesty or
  locking definition.

The review-surface lock goes from 1,431 to 1,433 constants: `FundPremises` and its constructor
are added, and `FundSafety` and `Premises.mk` change.
