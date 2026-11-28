# Alignment with merged PR #22412

Current authority: main `2e6763e21bc236cfcda6011d164b32040f9e0c8d` (2026-11-19), which merges
#22412 (simplify the Etna PoS + ZK design) on top of the [#22410 pin](alignment-22410.md)
`9c832234b4681fbc5eccdbaf9c9303b7869f91f4`. No other commit between the two pins touches
`packages/protocol/docs/etna`, and main's later #22413 (a pnpm upgrade) does not either. SPEC,
ACCEPTANCE, SWITCH and `rules/INDEX.md` changed and are re-pinned to that commit; ANCHORLESS
has the same bytes, and only its pin commit moves.

Unlike the last three re-pins, this one changes the model. Five commits before the re-pin
align it: `2d07b682c2` and `37e13173ab` (registry admission and its vectors), `d0dda1b9b4`
(a test that assumed a zero minimum stake), `04495fc33e` (no landing grid, no validator state
in settlement) and `f33620c45f` (the validator-state replay claim and the H4 premises). This
report lists what #22412 changed and what each change did to the model.

## What changed in the authorities, and in the model

- **Validator state leaves settlement (SYNC-9-5c, CONS-3.1-8, ENC-A-29b, PROOF-6.2-42, 5.4).**
  The landing statement drops `parentValStateHash` and `lastValStateHash` (21 ABI words),
  `cutLeaf` covers four words, the slot 285 record has no validator-state hash and `LandInput`
  has eight fields. The app commits the validator state in `app_hash` instead, as
  `appHash(x) = keccak256(abi.encode("ETNA_APP_HASH_V1", blockHash(x), valStateHash(x)))`.
  Guests no longer compute proposer priorities (PROOF-6.2-41a is retired) and do not check
  `app_hash`; nodes no longer compare a landed validator-state hash (SYNC-9-5b is retired).
  A checkpoint import at s > o checks a preimage of valStateHash(s − 1) against header(s)'s
  `app_hash` and its two sets against header(s)'s `validators_hash` and
  `next_validators_hash`, then applies s's updates once (DATA-5.4-3/4/5).
  - Model: `Cut`, `Checkpoint`, `LandInput`, `StatementData` and `BlockValidity.Header` lose
    their validator-state fields, and node trust (`trustCut`) compares the EL hash, the Comet
    hash and the FI cursor, as before, with no validator-state exception at the origin.
    `QueueIntegrity.node_trust_matches_checkpoint` states that comparison for SYNC-9-5: a
    trusted node's own chain reaches the Inbox's latest checkpoint with a header that matches
    the record in all three.
  - The replay-soundness layer that rested on those hashes is deleted: `checkBlock`,
    `checkRun`, `Batch`, `Certificate`, `ReplaySound`, `accepted_replay`, the `checked_run_*`,
    `batch_*` and `certificate_refines` lemmas, `trust_cut_at_origin`,
    `trust_cut_after_origin`, `openOrigin`, `membership`, `origin_uses_genesis`,
    `later_origin_authenticates` and the `NonVacuity` replay witness. The CometBFT arithmetic
    (`commit`, `update`, `increment`, `genesis`, `scheduled`, `replay`) and its lemmas
    `commit_pipeline`, `hplus2`, `replay_append` and `replay_height` stay, now outside
    settlement; see the [validator-state report](validator-state.md).
  - The import keeps its Boolean adapter flags. `nextValidatorsMatch` becomes
    `validatorSetsMatch`, covering both header hashes, and the import theorems are restated
    to DATA-5.4-3/5 (`validator_sets_conflict_halts`, `committee_conflict_halts`,
    `invalid_val_state_rejected`, `genesis_path_ignores_val_state`). At s = o the import still
    takes the 8.4 genesis path (DATA-5.4-1).
  - The validator-state vectors are retagged from COMM-4.3-13 and PROOF-6.2-41a to
    COMM-4.3-13, CONS-3.1-8 and SYNC-9-5c. ENC-A-29b's appHash encoding is not modelled.
- **No landing grid (6.1, 6.3, PARAM-11-9 and RECOV-8.3-3a retired).** A landing may end at any
  height h above c and carries the leaf of every height strictly inside (p,h); `land` requires
  h − p − 1 leaves and, if c > p, the leaf at index c − p − 1 to equal c's `cutLeaf`. U only
  needs 1 ≤ U ≤ 65,536, `maxBatchBlocks` ≥ 1, slot 293 loses `stopGrid`, `scheduleStop` takes
  only a time, and a planned stop makes a block invalid whenever its parent's timestamp is at
  or after `stopTime`, at any height.
  - Model: `gridK`, `Start.onGrid`, `gridCount` and the three grid checks of `land` are gone;
    `gridLeaves` becomes `innerLeaves p h table`, empty when h = p + 1. `Committee.configOK`,
    `Parameters.valid`, `Rules.Schedule`, `scheduleStop`, `Rules.stopped` and `recover`
    follow the new text, and `recover` has no grid check.
  - A new invariant, `Journal.FrontierShape.floor` (the written start is at or below the
    origin and every active record), replaces the grid argument that the proof origin is at
    or above S.
  - Two new lemmas check the review focus: `land_single_block` (h = p + 1, no leaves, accepted)
    and `land_overlap_at_p_succ` (a competing landing that moves c to p + 1 leaves the leaf
    count unchanged and its frontier leaf at index 0).
- **Guests verify fewer commits (PROOF-6.2-16/17).** Only h's commit and the commit of each
  block in (p,h) whose successor a different committee signs are verified; every other block is
  covered by its last_block_id ancestry. The model does not change; see the disclosure below.
- **No registry displacement (STAKE-4.1-14a; STAKE-4.1-14b retired).** `register` takes the
  lowest-numbered empty slot and never moves another bond; with every slot held it fails.
  Deployment requires 4096 × minStake > 10^27 base units (START-10-12, PARAM-11-11).
  - Model: `register` uses `firstEmpty`, so a full registry rejects every amount, including
    when a holder has zero balance. New theorems `register_takes_lowest_empty`,
    `register_full_rejected` and `admission_none_iff_full` replace the displacement theorems,
    and `EtnaProofs/CurrentAdmission.lean` is deleted.
  - The registry vectors are regenerated: seven cases at a deployable token scale (minStake
    250,000 TAIKO), among them `zero-balance-bond-not-replaced`.
  - The deployment bound is not part of the model's `config.valid`; the contract constructor
    and deployment checks enforce it. `tests/CurrentEconomics.lean` still shows that
    `config.valid` accepts minStake 0, as a statement about the model only.
- **CometBFT evidence limits (START-10-21)** become 900 blocks, 1 h and 1 MiB. They are not
  modelled.

## H4

H4 now has one path: a plain recovery from wherever c is, then a landing of the single block
c + 1. `RecoveryCall` admits only plain recoveries and lost its unused state argument;
`NoRollbackOrUpgrade`, `OnGrid`, the structural branch that installed K = 1 and the rollback
grid trap with its witnesses are deleted. `LiveAt.height` is c + 1 < 2^48, `WindowBound` adds
2, and `LiveRules`' first case has no grid condition. `PayloadLive` covers at most one block
(was six) and `UnzenStartUsable` needs room for one more height (was six).

Every changed premise is weaker than before, so the new H4 is at least as strong as the old.
The review of `f33620c45f` proved in Lean that the old H4 premises imply the new ones
(`PayloadLive` for six blocks implies it for one, and `UnzenStartUsable` with room for six
heights implies it with room for one), so the new H4 implies the old. The `LiveAt` changes go
the same way: for any K ≥ 1, c + K < 2^48 implies c + 1 < 2^48, a window past the old bound
(plus K + 1) is past the new one (plus 2), and the old first case of `LiveRules` (on the grid
and live) implies the new one (live). The conclusion also became stronger, because its trace
may use fewer kinds of recovery. That last part is by reading: the old statement's terms
(`gridK`, `OnGrid`) no longer exist, so it is not restated in Lean.

## PROOF-6.2-17: the every-block commit premise

The model keeps a verified commit for every block of a batch (`Blocks.Valid.commit`), and a
certificate requires one for every block. `currentVerifierSound` (H1's premise, which H2 and H3
inherit) is therefore stronger than what a guest checks under PROOF-6.2-16/17: only h and the
last block each committee signs in (p,h]. The docstring of `Protocol.VerifierSound` says so. H2's
chain agreement still rests on that every-block commit, because it compares valid chains under
the same validity relation. No theorem shows that the guest's sparser check implies the
every-block one; the spec's argument, that each unchecked block is an ancestor through
last_block_id of a checked block signed by the same committee, is not formalized here.

## Clause identities

SPEC goes from 315 to 313 clauses (64 identities gone, 62 new), ACCEPTANCE keeps 47 (23 gone,
23 new) and SWITCH keeps 117 (1 gone, 1 new); ANCHORLESS is unchanged at 101. The inventory
goes from 580 to 578 clauses. Nineteen changed SPEC clauses carry theorem edges; each edge
moves to the new identity and still holds as written:

| Old clause                 | New clause                 | Rules                   | Text change                                         | Edges                                                                                               |
| -------------------------- | -------------------------- | ----------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `LIVE_EN-4eeb66cec75465ce` | `LIVE_EN-dff27e7057a061cd` | STAKE-4.1-13a, 14a      | lowest empty slot; no displacement                  | 22, the displacement theorems replaced by the three admission theorems                              |
| `LIVE_EN-443baffea980ec5b` | `LIVE_EN-27f6a5d40d0ce55d` | STAKE-4.1-25, 26        | exit causes lose displacement                       | eight, among them `confirm_blocked_above_snapshot`                                                  |
| `LIVE_EN-8863d8019505caf8` | `LIVE_EN-66d59803d30c85d4` | STAKE-4.1-27 to 29      | withdrawal always leaves the slot empty             | sixteen, among them `withdrawal_identity`                                                           |
| `LIVE_EN-255e96e167914963` | `LIVE_EN-1d6f17bd21c3404a` | STAKE-4.1-36            | no displacement checkpoint                          | `execute_history_origin_exact`                                                                      |
| `LIVE_EN-598126cd6d0d70f0` | `LIVE_EN-8943613d8a93c4ca` | DATA-5.4-1              | no record validator-state check                     | `genesis_path_ignores_val_state`                                                                    |
| `LIVE_EN-5197fc5f88162605` | `LIVE_EN-0f8e196ab4a6954b` | DATA-5.4-4              | post-s app hash from the derived state              | `import_complete_range`, `node_import_closed`                                                       |
| `LIVE_EN-87331d19f043f44c` | `LIVE_EN-4266dc92f72e00d9` | DATA-5.4-5              | preimage checked against header(s)                  | seven, `next_validators_conflict_halts` renamed `validator_sets_conflict_halts`                     |
| `LIVE_EN-4217c5498e2e83a4` | `LIVE_EN-3d0fb99927ba67de` | LAND-6.1-1 to 9, 8a     | any end height; inner leaves; leaf at c             | nineteen, among them `land_single_block`, `land_overlap_at_p_succ`                                  |
| `LIVE_EN-4b408fa419d8782a` | `LIVE_EN-cc34fca3e258c580` | PROOF-6.2-12 to 16      | commits only for the last block of each committee   | seventeen committee-derivation theorems                                                             |
| `LIVE_EN-af33164a1858c781` | `LIVE_EN-16923cd8df6a0d78` | PROOF-6.2-17 to 19      | commit of h and of each committee's last block      | `Recovery.segment`                                                                                  |
| `LIVE_EN-2096743a5d399f16` | `LIVE_EN-6c59150df089c846` | PROOF-6.2-39 to 47      | inner cuts only; app_hash outside the statement     | ten, among them `statement_endpoints`, `chain_cursor_walk`                                          |
| `LIVE_EN-b8d78ca3f1f77e84` | `LIVE_EN-4ad2efd265e7f07c` | BACKP-6.4-1 to 8        | 1 ≤ U ≤ 65,536, no multiple of K                    | `Recovery.segment`                                                                                  |
| `LIVE_EN-47c9c7d7edef31c4` | `LIVE_EN-1885dff5441f40db` | RECOV-8-40a to 42       | a withdrawn bond can be excluded; none is displaced | seven, among them `recover_excludes`, `recoverable`                                                 |
| `LIVE_EN-e4d5ea9bf749c3f7` | `LIVE_EN-8ef06591adea330d` | RECOV-8-47 to 50        | recovery clears `stopTime` only                     | seven, among them `recover_clears_stop`                                                             |
| `LIVE_EN-7bda477553dde1bb` | `LIVE_EN-f7e2b71973efaba8` | RECOV-8.3-1 to 7        | no multiple-of-K check                              | `Recovery.prepare`                                                                                  |
| `LIVE_EN-2b31e997f0d3114c` | `LIVE_EN-5822dd8d7b64f579` | SYNC-9-4 to 9           | no validator-state comparison; app's own record     | `commit_pipeline`, `hplus2`, `replay_append`, `replay_height`; new: `node_trust_matches_checkpoint` |
| `LIVE_EN-95576d90354f3a45` | `LIVE_EN-bb8d2af49a890370` | START-10.1-3a to 3d     | K leaves the list a rule upgrade keeps              | `closed_generation_parameters`, `trace_same_generation_parameters`                                  |
| `LIVE_EN-f3360a370c6978e1` | `LIVE_EN-1afd41294ce37c15` | START-10.1-3g, 5a to 5c | `scheduleStop(time)`                                | six, among them `schedule_stop_result`                                                              |
| `LIVE_EN-ad883390e144f5e5` | `LIVE_EN-184e98d059f7f4cd` | START-10.1-6 to 6c, 14  | a block, not a grid segment                         | `accepted_image_certificate`                                                                        |

Three new clauses gain edges: LIMIT-12-11's registry-capacity item (`register_full_rejected`,
so the clause is partial), appendix A's cut-leaf block (`land_single_block`, supporting) and 6.3's
proving paragraph (`land_overlap_at_p_succ`, supporting). No edge is lost: every source of a
deleted clause either moved through the table or belonged to a deleted theorem.

`Recovery.segment` stays a property. With one block its conclusion would have included
`bs.length = 1`, which names none of its arguments and so fails the audit's Rule P. The
conclusion therefore states the terminal height p + 1 and not the length, and H4's proof derives
the length from it with `Blocks.chain_height`. `segment` is the only property citing sixteen
clauses of SPEC 3.2 (four), 3.3 (one), 3.4 (six), 4.3 (two), 6.2 (one), 6.4 (one) and 8.4 (one),
which stay partial, as do its rule edges CONS-3.2-2 and RECOV-8.4-13.

## Rules

INDEX retires five IDs and adds ENC-A-29b (deferred, appHash), so it has 636 rule IDs
(was 640). Their evidence:

| Rule          | Before     | After      | Why                                                                                |
| ------------- | ---------- | ---------- | ---------------------------------------------------------------------------------- |
| STAKE-4.1-14b | partial    | retired    | displacement theorems deleted                                                      |
| PROOF-6.2-41a | partial    | retired    | replay layer deleted                                                               |
| RECOV-8.3-3a  | deferred   | retired    | no evidence                                                                        |
| SYNC-9-5b     | deferred   | retired    | no evidence                                                                        |
| PARAM-11-9    | deferred   | retired    | no evidence                                                                        |
| ENC-A-29b     | (new)      | deferred   | appHash not modelled                                                               |
| STAKE-4.1-14a | partial    | partial    | `register_takes_lowest_empty`, `register_full_rejected`, `admission_none_iff_full` |
| LAND-6.1-5    | supporting | supporting | `land_single_block` replaces `grid_offset`                                         |
| LAND-6.1-7    | deferred   | supporting | `land_overlap_at_p_succ`                                                           |
| BATCH-6.3-10  | deferred   | supporting | `land_overlap_at_p_succ`                                                           |
| ENC-A-32      | deferred   | supporting | `land_single_block`                                                                |
| CONS-3.2-2    | partial    | partial    | `Recovery.segment`, now one block                                                  |
| RECOV-8.4-13  | partial    | partial    | `Recovery.segment`, now one block                                                  |
| SYNC-9-5      | supporting | supporting | `node_trust_matches_checkpoint` replaces the deleted `trust_cut_*`                 |
| SYNC-9-5c     | partial    | partial    | arithmetic only: `commit_pipeline`, `replay_append`, `replay_height`               |
| DATA-5.4-5    | supporting | supporting | `validator_sets_conflict_halts` replaces `next_validators_conflict_halts`          |

STAKE-4.1-13a loses `displacement_keeps_old_bond`. The reasons of CONS-3.2-2, RECOV-8.4-13,
PROOF-6.2-42, RECOV-8-47a and START-10.1-5b are reworded for the new text.

## Deferred

The CometBFT evidence limits, ENC-A-29b's appHash encoding, the import's derivation of the
state after s, the app's durable SYNC-9-5c record, the guest's sparser commit check and the
deployment bound 4096 × minStake > 10^27 are not modelled. All ANCHORLESS and ACCEPTANCE
clauses remain deferred.

Evidence after this pin: 68 partial / 510 deferred clauses (67 / 513 before), and 45 narrow
partial / 43 supporting / 516 deferred binding rules (47 / 40 / 521 before), plus 32 deferred
assumption/limitation rows, unchanged. The theorem manifest has 670 entries (695 before) and
the review-surface lock 1,730 constants (1,790 before).
