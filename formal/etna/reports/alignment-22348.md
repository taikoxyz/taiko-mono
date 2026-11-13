# Alignment with merged PR #22348

Current authority: main `d18357214fab30ea512ae9858a11699806d72ba1` (2026-11-13), which merges
#22348 (Etna spec gaps on stock CometBFT behaviour, anchor age and L1 forks) on top of the
[#22341 pin](alignment-22341.md) `49df560256c3f20f0868f6c6e555443c2b1fd669`. SPEC, ACCEPTANCE,
ANCHORLESS, SWITCH and `rules/INDEX.md` all changed and are re-pinned to that commit. No
definition or theorem statement changes; only comments and evidence wording do.

## What changed in the authorities

- **Stock CometBFT behaviour.**
  - Info (CONS-3.1-9): `app_version` is always the generation's genesis app version;
    `last_block_height` never exceeds the last height the app holds as committed; InitChain
    returns the same `app_hash` on every start that finds height 0.
  - Block time tolerance (CONS-3.4-12, START-10-6): CometBFT v0.40.0 rejects a block dated past
    the node's clock plus `block_time_tolerance`. Validators keep `adaptive_sync` off,
    `double_sign_check_height` 0 and `block_time_tolerance` 60 s.
  - Signer refusals (SYNC-9-11): a refusing signer answers with an explicit error before
    CometBFT's 5 s read timeout.
  - CometBFT genesis (START-10-23): the parameter-update authority reaches InitChain but has no
    effect, so InitChain need not check it.
  - First block of a new generation (RECOV-8.4-10): stock CometBFT requires the block time at
    the initial height to equal `genesis_time`, so that block's BFT time is R.timestamp.
  - Vote timestamps (STAKE-4.1-31, ENC-A-45): int64 seconds and int32 nanoseconds, encoded as
    two's-complement varints, so a vote timestamped before 1970 is covered.
  - The pinned EL's Engine API extensions are published with it (CONS-3.1-11).
- **Anchor age (PARAM-11-5).** `maxAnchorAge` must exceed the L1 finality delay, which on
  Ethereum is 1152 s plus an allowance the deployment makes for missed slots and import delay,
  so 1152 s itself no longer satisfies it. START-10-9 keeps the 1152 s floor; the allowance has
  no stated value (Q10-8 in `rules/review/10.md`). ACCEPTANCE section 1 item 3 now records the
  finalized block's peak age.
- **L1 forks (PARAM-11-13, LIMIT-12-10a).** A fork that changes L1's slot time, gas costs or
  per-transaction gas cap requires the delays counted in L1 blocks and the gas measurements to
  be checked again before it activates. ACCEPTANCE adds those re-measurements and asks for the
  rollback upgrade's gas to be published next to the gas cap.
- **Verifier-failure rollback (RECOV-8-27).** After the rollback no voided checkpoint can be
  read through `SignalService` or proven against; every other checkpoint stays usable, and a
  checkpoint a later landing writes is usable at whatever height. Moving the whole checkpoint
  mapping to a new storage version would also hide the kept ones. SWITCH now says that a later
  rollback does upgrade the L1 `SignalService` and Bridge.
- **Batches (BATCH-6.3-4, BATCH-6.3-7).** A lander should pick a reference block its L1 node
  reports as finalized. A long enough pause in production can, like an outage, need governance
  recovery.
- **Structural upgrades (START-10.1-14e).** The upgraded configuration keeps U a multiple of the
  new K and `maxBatchBlocks` at least the new K.
- Smaller changes: anchor-keyed decoding changes include proof formats (START-10.1-2a);
  appendix C notes that any sender can cause the worst-case load for the L2 fee alone
  (COST-C-7); ANCHORLESS spells out the raw EIP-4788 call; ACCEPTANCE adds crash tests between
  FinalizeBlock and Commit, and settlement lag to the FI backlog example.

## Clause identities

Seventeen SPEC clauses, six ACCEPTANCE clauses, one ANCHORLESS clause and one SWITCH clause
changed text. None is new or removed, so the inventory stays at 568 clauses. Three of the
changed SPEC clauses carry theorem edges; their edges move to the new identities with unchanged
roles:

| Old clause                 | New clause                 | Edges                                                                                                                                                              |
| -------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `LIVE_EN-405f21d19d6bc681` | `LIVE_EN-356addd3f6ed91f2` | `evidence_stays_transaction_slashable` (STAKE-4.1-31, whose row also names the clause)                                                                             |
| `LIVE_EN-1079277c334a4883` | `LIVE_EN-4a56676c3ce76122` | `authorized_rollback_restores`, `coherent_signal_bounded`, `rollback_coherent`, `rollback_snapshot_provenance` (RECOV-8-27), `rollback_target_unique` (RECOV-8-28) |
| `LIVE_EN-d8189cd72ebd5832` | `LIVE_EN-8da31506138f2a44` | `first_anchor_witness` (RECOV-8.4-12), `Recovery.segment` (RECOV-8.4-13)                                                                                           |

No theorem became wider or narrower: no Lean definition or theorem statement changed, and each
moved edge still holds as written.

- **STAKE-4.1-31.** The new text states the vote timestamp's range. The model's votes
  (`Staking.Vote`, `Consensus.Vote`) have no timestamp, so the edge, which covers callability
  only, is unaffected. Neither the range nor its encoding (ENC-A-45, deferred) is modelled.
- **RECOV-8-27.** The new sentences state the outcome the rollback must reach. The model reaches
  it by keeping the checkpoints at or below the trusted one and appending fresh ones: `rollback`
  keeps the Etna signals at or below the trusted height, block 0's genesis signal included, and
  leaves the Unzen signals, all at or below S, untouched; `land` appends each new checkpoint.
  The RECOV-8-27 reason and the scopes of `coherent_signal_bounded` and `rollback_coherent` now
  say so. How an implementation hides the voided checkpoints is not modelled, nor are the
  receive cache and Bridge `RETRIABLE` messages of RECOV-8-27a.
- **RECOV-8.4-10 to 8.4-13.** The new sentence fixes the first block's BFT time to R.timestamp.
  The model leaves BFT time free: `HeaderValid` reads it only inside the header timestamp's
  `max`. `segment` takes BFT time 0, and the first segment block's header timestamp already
  equals R's, so BFT time R.timestamp would give the same headers. A comment beside
  `bftTime := 0` says so. RECOV-8.4-10 has no edge and stays deferred; the anchor-witness and
  anchor-floor edges are unaffected.
- The other fourteen changed SPEC clauses, and every changed ACCEPTANCE, ANCHORLESS and SWITCH
  clause, had no edges and stay deferred.

`reports/rule-coverage.md` is regenerated: the 73 rule rows owned by the seventeen changed SPEC
clauses change only their clause ID.

## Checked against the model

- **START-10.1-14e.** The model already enforces the new sentence. `recover` with an upgrade
  requires `parameters.valid`, which includes `Committee.configOK` (`u % k = 0`, so U is a
  multiple of the K it installs) and `gridK ≤ maxBatchBlocks`.
- **Vote timestamps.** The model has no vote timestamp, so neither the range before 1970 nor its
  encoding is modelled.
- **`maxAnchorAge`.** `Parameters.valid` checks `1152 ≤ maxAnchorAge`, START-10-9's contract
  floor. That is not a value that satisfies PARAM-11-5 on Ethereum (Q10-8). The witnesses use
  1152 only as the floor, and a comment beside the check now says so. The model has no L1
  finality delay, so PARAM-11-5's bound is not modelled.

## Deferred

The rules of the changed clauses that carry no edge stay deferred, among them those with new
requirements: CONS-3.1-9, CONS-3.1-11, CONS-3.4-12, BATCH-6.3-4, BATCH-6.3-7, RECOV-8.4-10,
SYNC-9-11, START-10-6, START-10-23, START-10.1-2a, START-10.1-14e, PARAM-11-5, PARAM-11-13,
LIMIT-12-10a, ENC-A-45 and the appendix C cost assumption COST-C-7. RECOV-8-27a stays deferred.
INDEX only retitles rows; no rule is added or retired.

Evidence after this pin is unchanged: 60 partial / 508 deferred clauses; 43 partial / 37
supporting / 528 deferred binding rules, plus 32 deferred assumption/limitation rows.
