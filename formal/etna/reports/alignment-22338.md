# Alignment with merged PR #22338

Current authority: main `589b542de790861efd8b4d9bb0a4b1d066c2685f` (2026-11-05), which merges
#22338 (app nodes import from a bounded window with landed proposer priorities) on top of the
[#22335 pin](alignment-22335.md) `e84a9aaac`. SPEC and ACCEPTANCE changed; ANCHORLESS and SWITCH
are byte-identical and are re-pinned to the same commit.

## What changed in the authorities

- The slot 285 record has four words; the fourth is the validator-state hash of appendix A
  (STOR-B-9, ENC-A-3). The start record stores zero there.
- `cutLeaf(x)` has five words and ends with `valStateHash(x)` (ENC-A-29, new ENC-A-29a).
  `LandInput` has nine fields, with `lastValStateHash` after `lastCometHash` (LAND-6.1-13). The
  statement adds `parentValStateHash` (the origin record's value as stored) and
  `lastValStateHash` (ENC-A-35). `land` compares the frontier leaf's validator-state hash with
  c's record and writes `lastValStateHash` into the new record (6.1 steps 3 and 7).
- The guest's last cut must carry `lastValStateHash` (PROOF-6.2-42). The first cut matches the
  origin's validator state except at a generation's start height (PROOF-6.2-40). Every cut's
  validator state follows CometBFT v0.40.0's state-update arithmetic (new PROOF-6.2-41a).
- The trust gate also compares the validator-state hash, except at a generation's start height
  (SYNC-9-5). A mismatch halts for safety (new SYNC-9-5b).
- App import reads a bounded window instead of the full consensus archive. EL headers are
  installed and retained from max(o, s − U + 1) through s (DATA-5.4-4). Validator sets and
  proposer priorities come from the preimage of the landed validator-state hash. A preimage that
  does not hash to that value is an invalid candidate. A matching preimage whose set for s + 1
  differs from header(s)'s `next_validators_hash` halts, and so does a committee derived from the
  window that differs from the preimage (DATA-5.4-3, DATA-5.4-5).

## Model changes

- `Cut`, `Checkpoint` and `BlockValidity.Header` gain `valStateHash`. `LandInput` gains
  `lastValStateHash` in the spec's field order, and `StatementData` gains `parentValStateHash`.
- `writeStart` records zero. `initializeInbox` requires the fixed genesis header's
  validator-state hash to be zero, as it already requires a zero Comet hash and cursor.
  `Custody.StartsAt` and `Custody.Pending` include the zero hash.
- `LandingChecks.frontier`, `landed`, the contract and guest statements, `certificateOriginCut`,
  `nodeTrust`, `Suffix` and `Custody.HeaderOf` carry the field like the EL and Comet hashes.
- `Import.Candidate` gains `valStateAuthenticated`, `nextValidatorsMatch` and `committeesMatch`.
  `inspect` rejects an unmatched preimage together with the other invalid-candidate checks. It
  halts on an s + 1 set mismatch once the record is finalized. It halts on a committee mismatch
  only after the window is available and authenticated. `Import.retainedFrom` and `publish`
  install max(o, s + 1 − U)..s, with U from the generation's committee configuration
  (`configOK` already requires U ≥ K ≥ 1).
- The validator-state hash is an opaque atom. CometBFT's state-update arithmetic
  (PROOF-6.2-41a) and the preimage encoding (ENC-A-29a) are not modelled. At a generation's
  origin, the model reads the origin header's validator-state hash as the record's stored value.
  That makes the start-height exceptions of PROOF-6.2-40 and SYNC-9-5 hold by construction. It
  is sound only because no later block in the model takes the origin's own validator state as an
  input.

## Statement changes

H3's import clause (`ForcedInclusionAt`) now says every imported header number n satisfies
`o ≤ n`, `s + 1 ≤ n + U` and `n ≤ s`, instead of `o ≤ n ≤ s`. The statement text of H1 and H2 is
unchanged. Their meaning changes only through the definitions above. The review-surface lock
records this: 1,417 → 1,430 constants, 13 added and 108 changed, including
`Etna.Statements.Current.ForcedInclusionAt`.

## Evidence changes

- Three clauses with existing edges changed identity: the DATA-5.4-4 post-s boundary, the
  DATA-5.4-5 installation and failure handling, and the 6.2 item 10 cut clause
  (PROOF-6.2-39 to 42). Their edges move to the new clauses with unchanged roles. No other
  linked clause changed.
- New supporting theorems for DATA-5.4-5: `Import.invalid_val_state_rejected`,
  `Import.next_validators_conflict_halts` and `Import.committee_conflict_halts`.
  `Blocks.statement_endpoints` now also exposes the terminal Comet and validator-state hashes;
  PROOF-6.2-42 stays supporting. `authenticated_conflict_halts` and
  `unfinalized_checkpoint_retries` take the preimage check as a hypothesis.
  `publish_boundary`, `import_complete_range` and `node_import_closed` state the window.
- Inventory: 38 partial / 529 deferred clauses (ACCEPTANCE has one more clause), and 41 partial /
  35 supporting / 530 deferred binding rules. The new rules PROOF-6.2-41a, SYNC-9-5b and
  ENC-A-29a are deferred. The manifest holds 643 exact contracts.
- New regressions:
  - `tests/CurrentDesign.lean`: preimage reject and halt ordering, and the window function.
  - `tests/CurrentQueueIntegrity.lean`: the published window for U = 1, 2, 4 and 64.
  - `tests/CurrentCustody.lean`: a frontier leaf whose only wrong field is the validator-state
    hash is refused.
  - `tests/CurrentGuards.lean`: the start record holds zero, and a landing writes its
    `lastValStateHash`.
- New mutants in the full suite: drop the preimage check, the s + 1 set check or the committee
  check; ignore the window; unbind the origin's validator-state hash; drop the landed record's
  validator-state hash.
- The admission vector JSON is regenerated with the new authority commit. Its cases are
  unchanged.

## Still not covered

CometBFT's validator-set update and proposer-selection arithmetic, the ENC-A-29a encoding, and
the window's sizing from evidence limits remain deferred. So do the 4.3 committee derivation from
the window, stock-store installation (`LastHeightValidatorsChanged` and related state), alerts,
DATA-5.4-8 availability and SYNC-9-5b's verifier-failure classification. All 46 ACCEPTANCE and
93 ANCHORLESS clauses remain deferred.

## Validation

Local, macOS, Lean 4.35.0:

- Fresh `lake build` from an empty `.lake/build`: 90 jobs, 2 min 59 s, no warnings.
- `lint_sources`, `check_imports` (84 modules), `check_spec_coverage` (567 clauses),
  `rule_coverage --check`, `check_current_vectors`, `review_surface --check` (1,430 constants)
  and `generate_artifacts --check` pass.
- `audit_proofs.py`: 643 exact contracts, mechanical roles, allowed axioms, shadowing, library
  contents, headline claims, all fifteen premise fields read by a headline proof, fresh
  whole-kernel replay and 29 Lean regression modules; 167 s.
- Full suite (`ETNA_FULL_TESTS=1`, which includes every fast test): 348 tests in 1,594 s, 347
  passed. The failure was the new window mutant. It left `unsettled` unused, so the mutated
  model compiled with a warning that the harness rejects, and it was checked only against the
  light fixture. It now uses `min` and the full fixture; the 28-test mutation module then
  passed in 294 s.
- `lake check --paranoid` needs bubblewrap, which macOS lacks; it runs in the nightly CI job.
