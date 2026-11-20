# Etna workspace source and evidence boundaries

## Historical single-SPEC correspondence

The historical authority remains commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256
`4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`.
The historical guard’s reviewed workspace is main commit
`9c832234b4681fbc5eccdbaf9c9303b7869f91f4`, SPEC blob
`033f7ffd28ab9c3de7188948fb67eabfe9d180e6`, SHA-256
`7875c10373114ca5eaa7b164d2bfa844b4f5bbbede2ebfa252bb59246efd96de`.
This supersedes the previously reviewed workspace `991e06f6`; it leaves
historical native sources, vectors, source manifests and their authority intact.
The guard still accepts only canonical bytes or this single reviewed exact
revision. Other revisions and even a one-byte modification are refused.

The change in [#22410](https://github.com/taikoxyz/taiko-mono/pull/22410)
is normative. It moves the L2 fork boundary and EIP-4788 lookup into the
SignalService, and moves L1 legacy checkpoint forwarding into the Etna Inbox.
The historical review permits the bounded subsets below.

| Amended clauses                       | Selected consumers and scope                                                                                                                                                                                                                                                                                                                                                 | Unverified obligation                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| START-10-5                            | The unchanged initialization tail still checks the Registry, initializes the committee snapshot and generation/nonce, and restricts recovery to the owner. Registry admission/lifecycle cases execute contracts `89f419915de4b73bb57c53bf970f6dea9e8e8c8c` with explicit mock Inbox inputs. Existing settlement/publication replays observe ordinary L1 checkpoint save/get. | Single-syncer deployment, Unzen forwarding through Etna Inbox, forwarding failure behavior and cutoff before/after the start write, L2 beaconRootsFrom configuration, EIP-4788 lookup and checkpoint-store closure. Historical L1/L2 contract variants do not execute this refactor.                                                        |
| START-10-5a, START-10-5c, START-10-5d | The unchanged start-record/generation semantics used by bounded start/recovery models remain historical subsets. None of the selected native consumers performs an actual Unzen migration or originWriter implementation check.                                                                                                                                              | SignalService implementation validation at S, rewritten-start retry through the Inbox forwarder, and the changed Unzen prove sink and deployment order.                                                                                                                                                                                     |
| PROOF-6.2-46a, PARAM-11-12a           | Selected proving models treat validated execution/proofs as premises; no selected consumer proves the L2 implementation slot. Public Comet vote, canonical-byte, FilePV and synchronous signer-handler tests consume unchanged CONS-3.1 and double-sign rules.                                                                                                               | Guest authentication of the built-in L2 SignalService implementation at S and correct per-chain deployment manifest.                                                                                                                                                                                                                        |
| SYNC-9-5a, SYNC-9-16                  | Existing signer/trust models assume authenticated matching trust evidence and test the gate after that premise. Import/Bootstrap tests exercise selected historical stock storage and arithmetic, not the live switching-network trust procedure.                                                                                                                            | The new implementation check at S and the additional beaconRootsFrom() comparison against the node's own fork configuration, including local overrides, at EVERY trust target. A first landing does not settle the latter check; later snapshot joins must perform it too. Required authenticated L2 state availability remains unverified. |

N01/O01/O02 execute pinned CometBFT
`0880b4d378f347ab16e54ec677ff50d803f37d62`; their public vote and cached
replay oracles are unchanged by these amendments. N02/N03/N04 and O03 use
the historical Registry source above; a mock generation or active snapshot
cannot prove the new migration, client trust or committee-recovery procedure.
Other old bounded models and native receipts retain their original inputs and
limits. Passing this correspondence guard is not evidence that the current
SignalService design is implemented, deployed or fully verified.

Feedback [4611583127](https://github.com/taikoxyz/taiko-mono/pull/22387#discussion_r4611583127)
exposed a merge-result validation gap: branch-only tests used canonical SPEC
bytes, while hosted CI used the newer main SPEC. Validation must exercise the
reviewed merge-result bytes as well as the branch snapshot. Advancing main can
invalidate this exact correspondence again and requires another source review.

## Exact three-document workspace bundles

[#22412](https://github.com/taikoxyz/taiko-mono/pull/22412) amends SPEC, ACCEPTANCE
and SWITCH together at `2e6763e21bc236cfcda6011d164b32040f9e0c8d`.
The legacy three-argument verifier continues to refuse that SPEC. The separate
[bundle and claim ledger](current_spec_boundaries.json) records the byte lengths,
Git blobs and SHA-256 digests of all three documents at the canonical `d1835721`,
historically reviewed `9c832234`, fixed product-review `2e6763e2` and separately
source-reviewed `f556fa94` revisions. A
partial, mixed or modified bundle is refused. Independent pins for the document
inventory and the claim inventory keep source classification and claim selection
bound to their respective reviewed inputs.

`classify_workspace_documents` establishes `SOURCE_REVIEWED` for one exact
bundle. `select_claim` requires that bundle ID and a named consumer and claim.
A selection always reports `NOT_EVALUATED`. `historical-only` identifies the
frozen scope of an older model or execution. `current-model` and
`selected-public-operation` identify the current rules chosen for a bounded
model or stock API check. `waiting` covers outstanding current implementation
or deployment evidence. Each current-rule selection requires execution evidence
from its own consumer before reporting an outcome.

The signed-vote, Registry and FilePV runner summaries now use version 2 and
carry `specBoundary.workspace`, `specBoundary.evidence` and
`specBoundary.claim`. The evidence binds the historical SPEC authority, the
implementation revision, the native source manifest and the runner input pins.
Each Registry scenario and each FilePV scenario selects its own scope. The
Registry also checks the scenario's staged Solidity files against its selected
source digests. A full signed-vote campaign checks its smoke's version 2 receipt
against the phase record, current boundary, watched inputs and cache lock.
These runners can report historical regressions beside any reviewed workspace
bundle. The companion documents and ledger are watched through the run. The
archived summary formats and their original inputs retain their identities.

## Latest source review at f556

The latest separately reviewed document revision is
[`f556fa94186b0ab604573e8d3a4c4d4fa835dc84`](https://github.com/taikoxyz/taiko-mono/tree/f556fa94186b0ab604573e8d3a4c4d4fa835dc84/packages/protocol/docs/etna).
The fixed product-review revision remains `2e6763e2`; the compatibility identifier
`CURRENT_BUNDLE` means that fixed product revision. `LATEST_SOURCE_BUNDLE` names
f556. Matching the fourth exact triple can establish SOURCE_REVIEWED, but it
cannot transfer old product claims, test outcomes or implementation identity.
An old nonhistorical claim, including an old waiting row, refuses f556 inputs.
Historical-only receipts keep their original authority and implementation pins.

| Latest exact document | Bytes | SHA-256 |
| --- | --- | --- |
| SPEC |261010| `6f7150d65ff7c4a8b46b719d2ed48e665a60e47a6d013a2994229e8119ff24a7` |
| ACCEPTANCE |51711| `1ee58f0600daebc8277c6456145a9112388ae3f7c93efdba4d7618d04debdae4` |
| SWITCH |27213| `c33db855c674b1907480403a8ad54497e05fb1ca32d9772a15d97e2ffc61e14e` |

The separately pinned [source-review ledger](source_revision_obligations.json),
SHA-256 `218e4167e438dcaafdd35a1a6aa2b7a0e05e01a7b25cc5c3d6971898cbaccb65`,
contains eleven concrete WAITING obligations, no execution evidence and
execution NOT_EVALUATED. `select_source_revision` returns this source-only scope;
actual workspace classification still requires all three original byte streams.
The earlier claim inventory remains pinned at `d127d53a73905b701d950d75c1021433f05de6c6dfc3e21a0b96394ab79ef958`.
The three older bundle encodings remain unchanged. Exact mixed, missing, extra or
modified document inputs refuse.

| Obligation | Concrete latest-source evidence still WAITING |
| --- | --- |
| Y01 |Generation-bound rules/stop writes and cancellation, including delayed authorized calls after recovery (START-10.1-5a/5b/5c). The old finite transition system has separate evidence. |
| Y02 |Permanent issued bondId exclusions in strictly increasing order, whole-landing authorization audit, voided records and fixed recovery genesis (STAKE-4.1-13a, RECOV-8-38, RECOV-8.1-1/7, RECOV-8.3-1, RECOV-8.4-3, START-10-21). Empty exclusion examples do not exercise the new nonempty ABI. |
| Y03 |Unvoided retained origin and non-regressing active snapshot before verification, current signing-set/header/anchor checks and real per-rule guest proofs (LAND-6.1-6/10, RECOV-8-27, PROOF-6.2-17/43, START-10.1-5a). |
| Y04 |Permanent bondId forfeit calldata, flags/events, issued-id and withdrawal races, ordered exclusions and self-report economics (STAKE-4.1-13a, FORF-4.4-1/20). Historical proxy balances do not establish the new ABI/key space. |
| Y05 |Zero count when empty or highest occupied slot+1, occupied final entry, shrinking counts, unified immutable minStake and bondId resolution (STAKE-4.1-36, COMM-4.3-2/3/4/5, START-10-12). Old positive-width trailing/all-empty inputs remain historical. |
| Y06 |Authenticated full window, both LoadBlockCommit and LoadSeenCommit, metadata/full validator sets with stored proposer, durable aligned app/EL/Comet installation and signer fencing (DATA-5.4-1/2/3/4/5/6/8, RECOV-8.2-2, SYNC-9-5c). Y06's full producer integration remains INCONCLUSIVE. |
| Y07 |Zero block-evidence budget in both genesis types; proposer emits an empty list; consensus and block-sync validation reject nonempty lists; fresh imported evidence DB and authenticated history for continued gossip/light-client evidence (CONS-3.1-10, START-10-20/21/22/23, RECOV-8.4-7, DATA-5.4-2/3/4/5/6/8). The synthetic stock marker/budget fixture is not valid imported Etna history. |
| STOCK_DEPLOYMENT |Exact installed platform binary/build/config, certified first-block recovery, complete historical proposer/validator state and isolated signer restart (CONS-3.1-1/8/9, RECOV-8.2-1, SYNC-9-5c). A version string or selected public API is insufficient. |
| SWITCH |Permissionless proven Unzen-tip latch, finalized R0, forwarding cutoff, deadline-bound two-chain replacement/acknowledgment, split configuration failure and actual first landing (START-10-5b/5c/20, LAND-6.1-8a). |
| PUBLIC_HISTORY |Independent public availability/import packages after blob expiry and authenticated header/commit ancestry with current evidence/committee/anchor windows (DATA-5.3-9a, DATA-5.4-8). |
| RESOURCES |Worst legal single-block/full-batch real two-proof feasibility, 4096-slot Registry measurements and full operational/resource rehearsals (MODEL-1-2, LIMIT-12-17). |

The original W/Y models, public fixtures, historical native pins, nineteen
archived INCONCLUSIVE searches and broader R01/P01/K01/Q01 limits remain intact.
This review records specific changed requirements; it establishes no latest
runtime or deployment conformance. The sections below retain the earlier
9c832234→2e6763e2 review at its original scope.


## Normative delta from `9c832234` to `2e6763e2`

### Registry, capacity and selection

- **STAKE-4.1-4, 13a, 14a, 24, 26, 28 and 36.** `register` requires
  `amount >= minStake` and takes the lowest empty slot. A held slot stays occupied through
  exits and zero balance, and is cleared by withdrawal. Full refusal issues no
  bond and consumes no key identity. Lifetime key flags, the distinction between
  `(false, 0)` and `(true, 0)`, slot-indexed roots, and historical checkpoints
  remain important. Exit confirmation still requires snapshot coverage and the
  subsequent withdrawal delay. STAKE-4.1-14b and Appendix A's `BondDisplaced`
  event are removed. The separate Registry storage and lookup namespaces remain
  under STOR-B-20–34.
- **START-10-12, PARAM-11-11 and LIMIT-12-11, 12, 18.** Deployment requires
  `4096 * minStake > 10^27` base units, making
  `244140625000000000000001` the least permitted integer value. Full occupancy
  requires return and reuse of tokens penalized from still-held bonds, including
  possible reporter recycling. With zero sink returns, more than the stated
  post-bounty fraction of supply must be held or paid into the sink. A stalled
  confirmation snapshot can keep the Registry full even with held-zero bonds.
  Recovery selects from existing bonds in that state. Top-ups, exits, penalties,
  withdrawal and available vacancies can still affect selection at R without a
  reservation for DAO-funded operators (RECOV-8.1-7 and 9).
- **RECOV-8-40a.** Exclusion still authenticates issued bond IDs against entryKey
  and preserves earlier exits. A withdrawn bond can be named without changing
  any slot checkpoint. The displacement variant is removed.
- **Affected consumers.** `EtnaRegistry`, `EtnaRegistryRetirementProduct`, and
  the historical admission contexts in `EtnaCommittee`, Registry public and
  baseline Lean/Forge vectors, and all four `run_registry_cases.py` scenarios
  retain historical scope. In particular the pinned Registry implementation
  displaces an occupied slot and checks a nonzero constructor minimum. W02 and
  W03 select distinct current models. The current contract and 4096-slot gas
  measurements remain waiting.

### Proof, landing, overlap and back-pressure

- **MODEL-1-2, CONS-3.4-13, LAND-6.1-5–8 and 13, BATCH-6.3-1 and 2.** A single
  valid block must fit a landing and its two proofs, including the worst FI
  singleton trial. Any height above c may be the terminal h. Range is
  `generationStartHeight <= p <= c < h < 2^48` and batch length is `h - p`.
  The argument `LandInput` drops `lastValStateHash`, leaving eight fields. The
  range, origin, cut, FI pointer, reference/blob and proof checks still bind the
  transaction. The leaf at c and agreement of its FI cursor with the live head
  are checked before proof verification. Slot 285 records actual c as parent
  independently of proof origin p.
- **PROOF-6.2-40–43 and 45, ENC-A-3 and 29–35, STOR-B-9.** Slot 285 has three
  words, a packed parent/generation/head word and the EL and Comet hashes.
  There is no validator-state word at the start or later. A cut is four words
  (height, EL hash, Comet hash and FI cursor). The hash uses ordered interior
  leaves `p+1..h-1`, count `h-p-1` and index `c-p-1` for an interior c. A single
  block hashes the empty list. Origin and terminal bind separate statement
  fields. The statement drops both `parentValStateHash` and `lastValStateHash`
  and now has 21 static words (672 bytes). PROOF-6.2-41a is removed. Application
  validator-state commitments move outside the guest statement.
- **PROOF-6.2-16, 17 and 45.** Verify h's commit and the commit of the last block
  under each committee before a switch inside the batch. Those commits bind
  the correct BlockID, strict threshold, distinct signers and chain domain.
  Earlier same-committee blocks are bound through authenticated ancestor links.
  Every block still receives the validators/next-validators and schedule checks.
  The stock signed-vote threshold vectors alone leave this guest input and
  schedule obligation open.
- **BACKP-6.4-2 and 13, START-10-10 and 18, PARAM-11-6, 8 and 9,
  LIMIT-12-16, COST-C-10 and 11.** `U` is independently bounded 1–65,536 and
  `maxBatchBlocks >= 1`. K and its divisibility and rounding rules are removed.
  The leaf calldata budget is `(B-1) * 32` bytes, including 9,568 bytes for 300
  blocks. Shortest competing landings advance one block. Selected operating
  capacity still calls for measurement of six-blob worst cases, proof and L1
  cost. The grid-specific proving wait, rollback loss and production cost
  estimates are removed.
- **Affected consumers.** `EtnaSettlement`, `EtnaCheckpointIdentity`,
  `EtnaRepeatedRecoveryIdentity`, `EtnaForcedInclusion`, `EtnaFISuffixRecovery`,
  `EtnaVerifierRollback` and `EtnaRollbackPayments` retain their historical
  checkpoint assumptions. `EtnaProvingProgress`, `EtnaProofRecapture`,
  `EtnaProvingArrivalOverlap`, `EtnaProvingAsyncProduct` and
  `EtnaProvingRecovery` retain their original bounded proof premises. The
  identity, settlement, recovery and recovery-lifecycle exporters and Solidity
  replays use historical grid and layout formats. The settlement exporter runs
  `conformance/EtnaSettlementReplay.tla` under the historical six-block grid.
  W06 selects a separate
  structural current model. A concrete current Inbox, guests, ABI and resource
  execution remain waiting.

### AppHash, import and stock evidence

- **CONS-3.1-8, SYNC-9-5 and 5c, ENC-A-29a and 29b, RECOV-8.4-7.** The app
  computes and durably keeps stock per-height validator state from genesis or
  an authenticated import. The six-head-word `valStateHash` retains ordered
  current/next sets, four-word entries and both stored proposer indices.
  `appHash(x)` adds the three-word domain-separated hash of EL hash and
  `valStateHash(x)`. Header `x+1` carries that value, and InitChain returns the
  hash of the starting EL hash and this generation's genesis validator state.
  Latest-finalized-L1 trust checks compare EL/Comet hashes. The app computes
  its own state commitments using running-state arithmetic. Sparse store lookup
  can rescale/center once over multiple steps and yield different priorities.
- **DATA-5.3-4 and DATA-5.4-1–6.** A checkpoint requires an authenticated
  retained record from a landing ending there or the start. Import obtains the
  `s-1` preimage authenticated by header(s).AppHash with the EL parent hash.
  The two sets match `validators_hash` and `next_validators_hash`. Apply s's
  authenticated update once to obtain state after s, install the corresponding
  post-s AppHash in stock state and ABCI Info, and fill EL's own indexes down
  to `max(o,s-U+1)` even when the Comet window is shorter. A wrong preimage
  rejects the candidate. An authenticated contradiction in the header or
  committee data halts for safety. Session trust uses latest-finalized EL/Comet
  records and a generation change invalidates unfinished import admission.
- **DATA-5.4-8, SYNC-9-5c, START-10-21 and SYNC-9.1-1, 5 and 8.** The package
  producer checks the ordered sets, powers, priorities and stored proposers
  against a stock node's running state and refuses publication on divergence.
  Uniform app arithmetic errors can pass header checks between those apps.
  Stock evidence limits become 900 blocks / 1 hour / 1 MiB. Evidence expiry
  requires both age thresholds, while peer gossip uses the height threshold.
  A duplicate already pending can bypass revalidation and produce different
  accept/reject results from full validation. The first precommit step and
  complete proposal determine whether >2/3 prevotes stop consensus before a
  decision. A decided invalid block keeps consensus stopped or block sync below
  it without a process exit. Replay after correction handles clock-only
  rejection. Expired evidence requires importing from a landed checkpoint at
  or above the decided block carrying it. Governance recovery handles persistent
  committed-state rejection such as appHash
  disagreement. Retain the authenticated preimage for published import
  checkpoints. L1 double-sign submission is independent of stock pool expiry.
- **Affected consumers.** `EtnaCheckpointImport`, `EtnaImportProgress`,
  `EtnaAppCrash`, `EtnaL1Trust`, `EtnaTrustSupersession` and the signer models
  retain historical authentication/availability premises. The checkpoint import
  exporter, `run_comet_bootstrap.py`, existing first-block, handover and restart
  runners retain their historical or synthetic app hashes and evidence inputs.
  The signed-vote and FilePV public controls retain their own historical scope.
  W04 and W05 select bounded operations via stock APIs. Current Etna app,
  producer, store installation, evidence continuation and trust remain waiting.

### Recovery and schedule

- **RECOV-8.1-6–9 and RECOV-8.3-3.** Set expectedC to the last provable block.
  RECOV-8.3-3a's grid fence is removed. The actual generation, checkpoint,
  nonce and deadline equality/ordering guards remain. The DAO audits every
  landing above a named audited boundary, even if honest nodes already hold
  the block at c. Use the p, h and reference block of each L1 landing; validate
  its full blobs and required L1 ancestry. If honest nodes lack or disagree
  with the settled block, independently execute from their last common settled
  state, recompute FI from the anchored queue and exercise legal singleton
  skips, check headers and the committee-terminal commit rule, and apply every
  3.4 rule including U and stop. Verified divergence or stock-only rejection
  can proceed from c. A contradiction in the independent block or landing
  checks leads to verifier rollback before recovery. The reselected committee
  and genesis depend on actual finalized R.
- **RECOV-8-47a, START-10.1-3d, 3e, 5b, 6c, 14d and 14e, Appendix A and
  STOR-B-15a.** Slot 293 stores `activeRules`, `nextRules`, `rulesTime` and
  `stopTime`. Owner-only `scheduleStop(uint48 time)` removes the grid argument.
  Cancellation uses zero and pending deadlines still apply. The parent
  timestamp at the block's anchor determines the stop boundary. Planned
  structural upgrade settles the terminal height and recovers with nonzero
  `nextRules + 1`, clearing stopTime. The ordinary rules=0 path preserves any
  pending rules activation. Nodes and guests independently select each block's
  authenticated historical schedule. The supported two-proof combination must
  cover the batch's actual rulesets and the planned-stop predicate.
- **Affected consumers.** `EtnaRecoveryTransaction`, `EtnaRecoveryTime`,
  historical recovery/recovery-time/recovery-lifecycle exports and rollback
  models keep their earlier ranges or trusted-check premises.
  `EtnaRulesSchedule`, `EtnaCandidateHandoff`, `EtnaStopProofHandoff`,
  `EtnaHandoffSigner`, `export_rules.py` and `EtnaRulesReplay.t.sol` retain
  grid-conditioned stop or the five-field schedule. W07 selects a separate
  timestamp schedule model. Real audit/replay, contract and guest scheduling,
  image compatibility and execution remain waiting.

### Changed acceptance and switch checks

| Exact document location                | Consumer obligations                                                                                                                                                                                                                                                                    |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ACCEPTANCE §1 items 1, 2 and 4–7       | U single-block landings at the anchor limit, app validator-state resource accounting, worst single block and multi-block proofs, three-word writes, one-block competing landings through every interior c, fresh held-zero/full and last-vacancy Registry gas measurements.             |
| ACCEPTANCE §2 item 2                   | Non-grid recovery boundaries, from-c verification after appHash rejection or conflicting decided blocks, FI skip replay and invalid U+1 block controls, whole-landing reference mismatch on both paths, fully occupied stalled recovery.                                                |
| ACCEPTANCE §3                          | Bytes for four-word cuts, appHash, three-word checkpoint layout, every position and FI cursor binding, U endpoints, deployment minStake, admission/refusal and slot-indexed identity after withdrawal, running-state import comparison, removed displacement/old-grid test obligations. |
| ACCEPTANCE §4                          | Recompute actual reselected power after finalized R without assuming access to a full Registry, verify timestamp stop and per-height landing at launch.                                                                                                                                 |
| ACCEPTANCE §6 items 1–3                | Earlier/later and three-ruleset landing, scheduleStop deadline/cancellation without grid fields, terminal-height settlement, authorized recovery and first real new landing.                                                                                                            |
| ACCEPTANCE §7 items 2, 5–7 and 9       | Header(s) preimage/refusal versus contradiction, per-height post-s state, short evidence window and longer EL retention, pending evidence asymmetry and stopped/stalled progression, same-generation trust/restart and clock-only retry.                                                |
| ACCEPTANCE §8 item 3 and SWITCH step 8 | First landing from S needs any-height cut checks plus the existing Unzen/SignalService and guest validation. Startup passes the Etna start EL hash and genesis validator-state commitment as genesis appHash.                                                                           |

`2e6763e2` supplies these documents. Its tree does not supply the current Etna
Registry, Inbox, ABCI application, importer or guest implementations. The
historical models, exports, stock APIs and native proofs-as-premise replays
listed here leave those concrete consumers and deployment acceptance waiting.
