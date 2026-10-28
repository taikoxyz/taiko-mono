# First-batch design verification

Historical report: counts, source line IDs and audit packaging below describe the original batch; see [review corrections](review-corrections.md) for the current schema, bindings and checks.
Baseline: PR #22292 at `de04742839de4a0437152bd82fd6ff255bf65d2e`; current frozen bilingual 04:07Z edits on 2026-10-27. All work is confined to `formal/etna`.

## Conditional proof claims

Each row describes a narrow modeled property, not full coverage of every linked source clause. Complete theorem types and premises are audited in the manifest. Cryptographic/L1/EL facts stay explicit boundaries.

| ID | Property | Audited theorems | Boundaries |
| --- | --- | --- | --- |
| DV-01 | Consecutive height and EL/Comet parent linkage, with empty first-generation LastBlockID. | `Etna.Design.BlockValidity.valid_parent_links`, `Etna.Design.BlockValidity.chain_height` | context, hash |
| DV-02 | Decoded anchor floor/presence/freshness/back-pressure and header/share/size checks compose with validity. | `Etna.Design.BlockValidity.valid_anchor_rules`, `Etna.Design.BlockValidity.valid_header_rules` | l1, context, el, payload |
| DV-03 | Actual committee selection and global-height H+2 activation, including recovery cancellation. | `Etna.Design.Consensus.active_at_handover`, `Etna.Design.Consensus.switch_keeps_old_authority`, `Etna.Design.Consensus.recovery_initial_until_switch`, `Etna.Design.Consensus.active_cutoff_monotone`, `Etna.Design.Committee.chosen_eligible`, `Etna.Design.Committee.canonical_keys` | context, hash |
| DV-04 | Distinct selected precommit signers strictly exceed 2/3 power and bind deployment/generation/height/round/block. | `Etna.Design.Consensus.commit_authorizes_actual_committee`, `Etna.Design.Consensus.commit_strict_quorum`, `Etna.Design.Consensus.signed_power_bounded`, `Etna.Design.Consensus.foreign_generation_rejected` | context, signature, hash |
| DV-05 | Switch witness uses the D(t) cutoff and the switch block anchor root, with an accepted election. | `Etna.Design.BlockValidity.valid_switch_witness` | context, l1 |
| DV-06 | Per-block FI results compose into zero/one cursor steps along the full chain. | `Etna.Design.BlockValidity.valid_cursor_step`, `Etna.Design.BlockValidity.chain_cursor_steps`, `Etna.Design.Forced.step_one_or_zero`, `Etna.Design.Forced.overdue_waits_for_execution` | l1, payload, el |
| DV-07 | The decoded valid chain constructs a continuous endpoint-bound certified cut table. | `Etna.Design.Settlement.chain_certified`, `Etna.Design.BlockValidity.cuts_length`, `Etna.Design.BlockValidity.cuts_origin`, `Etna.Design.BlockValidity.cuts_terminal` | context, payload, el, hash |
| DV-08 | An accepted overlapping landing attaches to its execution-time frontier on that same valid chain. | `Etna.Design.Settlement.accepted_frontier_from_valid_chain`, `Etna.Design.FirstBatch.all_frontiers_accept_same_transaction` | context, payload, el, hash |
| DV-09 | Checkpoint, FI head, SignalService state root and active snapshot come from one terminal block. | `Etna.Design.Settlement.accepted_terminal_from_valid_chain`, `Etna.Design.Settlement.accepted_snapshot_monotone` | context, payload, el, hash |
| DV-10 | Ordinary landing sequences preserve current-record consistency, grid and unique historical heights without overwriting old records. | `Etna.Design.Settlement.landing_preserves_state`, `Etna.Design.Settlement.landing_preserves_old_records`, `Etna.Design.Settlement.trace_preserves_state` | journal |

## Source coverage

The source inventory has 619 clauses: 552 deferred, 6 design-pending, 61 partial. There are no fully proved source-clause claims. The ten proof claims above are narrower than those clauses.

IDs refer to exact frozen source line ranges and text digests. Headings are context, numbered/list items and table rows are separate clauses, and code blocks are whole clauses. Code blocks and paragraphs may require further decomposition. The inventory is checked for completeness, duplicate/stale rows, theorem/source links, statuses and named boundaries; semantic correspondence still needs review.

## Boundaries and remaining work

- `context`: Fixed generation/origin/genesis and historical registry/anchor lookup are authenticated inputs. Lifetime key uniqueness and complete registry history transitions remain later work.
- `l1`: Real raw-header ancestry, canonicality/finality, storage/MPT parsing and authentication are external.
- `signature`: The signature relation authenticates decoded vote fields and key; actual low-s/ecrecover/sign-byte encoding is external. Full Comet lock/round safety is not derived here.
- `payload`: Envelope/tx0/raw/singleton bindings and full-range blob-to-payload equality are external named relations, not actual guest proofs.
- `el`: Complete deterministic EL execution, header/body fields and zk-gas semantics remain external relations.
- `hash`: Opaque/free hash terms, actual cryptographic separation and canonical encodings remain external.
- `journal`: The abstract ordinary-land transaction commits atomically. Recovery/rollback/node-trust composition is not included in LandingTrace.

- No whole-protocol safety or liveness claim is made. A >2/3 quorum check is not a proof of Comet locking/round safety.
- Context authentication, full blob/payload equivalence, signatures and EL validity are externally instantiated relations. Their true-valued finite examples are satisfiability witnesses, not implementations.
- Node trust/restart and full registry/evidence state machines, public reconstruction, conditional progress and deployment/upgrade activation remain explicitly deferred.
- The composition theorem for ordinary landings does not establish recovery/exceptional-rollback trace safety or recover irreversible bridge/staking payouts.

## Findings

No new specification defect was established by this first batch. Existing historical findings are retained separately and are not silently treated as current defects. The current spec explicitly leaves upgrade activation unfinished; this is recorded as design-pending rather than asserted safe.

## Validation

Use the commands in README. Current commands and generated runtime results are described in README; historical machine reports remain in git history.


## Independent review and correction

A fresh reviewer found one P2 regression gap: the recovery-first-switch example
used an old checkpoint anchor newer than R, and therefore did not exercise the
recovery-origin floor. The repaired context uses old anchor 14 < R=20, checks
cutoff 20 and the targetEpoch transition 1 -> 2 at H=7, and includes a valid
recovered S/S+1/H chain plus wrong-witness-root rejection. Its new assertion
failed on the old fixture and passed after repair. An isolated `normal` mutant
that omits max(anchorD,R) computes 14 and fails the same expected cutoff 20.
No corresponding specification or scheduling-definition defect was found.
No other substantive review findings were reported.

The review intentionally excluded actual crypto/L1/MPT/payload/EL implementations,
real guest/client/contract conformance, full Comet locking, and later node-trust,
registry/evidence, recovery/rollback, liveness and upgrade state machines. Those
remain explicit assumptions or deferred clauses; no safety claim about their
implementations follows from this batch. Frozen fetch bytes are authenticated by
the inventory hashes, not by an independent proof of the Notion service.

Implementation choices: reuse the existing isolated PR clone (the app does not
manage that checkout); keep plan/materials inside formal/etna (different from a
conventional root plan directory); separate node-only checks from guest validity
(future trust proofs must use NodeValid); audit regression examples as theorem
contracts (additional formal build work); inventory source clauses conservatively
(further decomposition remains necessary before any full-coverage claim).
