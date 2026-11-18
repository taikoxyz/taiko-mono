# Alignment with merged PR #22410

Current authority: main `9c832234b4681fbc5eccdbaf9c9303b7869f91f4` (2026-11-18), which merges
#22410 (move the Etna L2 fork boundary into the SignalService) on top of the
[#22348 pin](alignment-22348.md) `d18357214fab30ea512ae9858a11699806d72ba1`. Since that pin,
main has also merged #22386 (share SignalService across L1 and L2), #22394 (one term per concept
in the spec wording) and #22393 (a design briefing deck, which is not an authority). SPEC,
ACCEPTANCE, ANCHORLESS, SWITCH and `rules/INDEX.md` all changed and are re-pinned to that
commit. No definition or theorem statement changes; only comments and evidence wording do.

## What changed in the authorities

- **One SignalService contract for L1 and L2 (START-10-5, ANCHORLESS section 4).** Both layers
  run the same code with different immutables: `_authorizedSyncer` (the Inbox on L1, the
  `Anchor` proxy on L2) and `beaconRootsFrom` (0 on L1; on L2, `ETNA_FORK_TIME` on a switching
  network and `max(1, t)` on a new one). From `beaconRootsFrom` on, the L2 SignalService
  rejects every checkpoint and resolves proof roots only through EIP-4788. This replaces the
  `Anchor`'s `etnaTimestamp` gate on `anchorV4` as the L2 fork boundary.
- **The Unzen gate moves into the Inbox (START-10-5, START-10-5c, START-10-5d).** The L1
  SignalService accepts checkpoints only from the Inbox and reads no Inbox state. On a
  switching network the Inbox forwards the Unzen Inbox's checkpoints: its `saveCheckpoint`
  accepts calls only from the Unzen Inbox, accepts any height before the start write, rejects
  heights above S once the start is written, passes each checkpoint unchanged and reverts for
  no other reason. The Unzen Inbox's `prove` is upgraded to save through it, in the same DAO
  proposal as the SignalService upgrade. A start below the true last Unzen block now blocks the
  final Unzen `prove` because the Inbox rejects its checkpoint.
- **The start-implementation check names the L2 SignalService (PROOF-6.2-46a, SYNC-9-5a,
  START-10-5a, PARAM-11-12a, SWITCH sections 4 and 5).** The guest, the nodes and the
  originWriter check that the L2 `SignalService` proxy's EIP-1967 implementation slot at S holds
  the Etna L2 `SignalService` implementation that clients and guests build in, instead of the
  `Anchor`'s.
- **A node's own fork time (SYNC-9-5a).** Before it becomes trusted, a node on a switching
  network also checks that `beaconRootsFrom()` of that built-in implementation, read from L2
  state it has authenticated, equals the fork time the node runs with, including any local
  override. No landing settles this, so the check applies whatever the latest checkpoint.
- **Wording (#22394).** "normal" or "committee" checkpoint becomes registry checkpoint
  (STAKE-4.1-18, FORF-4.4-11, STOR-B-27, STOR-B-33); LAND-6.1-9 says "active committee
  snapshot"; "subproof" becomes sub-proof; "halt" becomes pause in 6.4 and LIMIT-12-4; the
  Unzen queue "cursor" becomes its head; START-10-22's "forced cursor" becomes FI cursor.
- SWITCH and ANCHORLESS are rewritten for the shared SignalService, the Inbox's checkpoint
  forwarder and the single-proxy L2 upgrade. ACCEPTANCE section 8 now checks the L2
  SignalService implementation instead of the `Anchor`'s.

## Clause identities

Nineteen SPEC clauses and two ACCEPTANCE clauses changed text; none is new or removed. In
ANCHORLESS, 18 clause identities are gone and 26 are new (93 to 101 clauses); in SWITCH, 29 are
gone and 33 are new (113 to 117). The inventory grows from 568 to 580 clauses. Eight of the changed SPEC clauses
and two of the SWITCH clauses carry theorem edges; their edges move to the new identities with
unchanged roles:

| Old clause                     | New clause                     | Text change                                     | Edges                                                          |
| ------------------------------ | ------------------------------ | ----------------------------------------------- | -------------------------------------------------------------- |
| `LIVE_EN-543ce5a6713613f1`     | `LIVE_EN-78c909bca20c5cd0`     | registry checkpoint (STAKE-4.1-18)              | nine, among them `closed_registry_history`                     |
| `LIVE_EN-a563a899ed3d4c6b`     | `LIVE_EN-4217c5498e2e83a4`     | active committee snapshot (LAND-6.1-9)          | eighteen, among them `certified_landing`, `path_rooted`        |
| `LIVE_EN-b22f4a02a0ce7e37`     | `LIVE_EN-9e082fe4b4d911e8`     | sub-proof (PROOF-6.2-9)                         | `accepted_suffix_from_certificate` and three more              |
| `LIVE_EN-9dabf1462e3643ef`     | `LIVE_EN-2096743a5d399f16`     | L2 SignalService implementation (PROOF-6.2-46a) | twenty-four, among them `checked_run_records`                  |
| `LIVE_EN-926574b7e8b2e1e6`     | `LIVE_EN-2b31e997f0d3114c`     | L2 SignalService; node fork time (SYNC-9-5a)    | `checked_run_prefix`, `checked_run_records`, two `trust_cut_*` |
| `LIVE_EN-469ffbdb2e14d0b4`     | `LIVE_EN-8dbee22be3a3eda7`     | shared SignalService; Inbox forwarder           | `trace_legacy_etna_disjoint`, `trace_legacy_prefix`            |
| `LIVE_EN-418f79028f11c3d9`     | `LIVE_EN-8c95830dc59e5ff1`     | L2 SignalService implementation (START-10-5a)   | `set_origin_once`                                              |
| `LIVE_EN-a0a126e4b8ea2b61`     | `LIVE_EN-434877759085292e`     | the Inbox rejects the checkpoint (START-10-5c)  | six, among them `trace_start_frozen`, `prepare`                |
| `LIVE_SWITCH-5feebcd49f3b4148` | `LIVE_SWITCH-1b91cab49034187c` | L2 SignalService; checkpoint cutoff             | `path_rooted`, `pending_parent`, `pending_parent_fence`        |
| `LIVE_SWITCH-2b455848adac9018` | `LIVE_SWITCH-c744303db39a7ea9` | L2 SignalService implementation                 | `path_rooted`, `pending_parent`, `pending_parent_fence`        |

No theorem became wider or narrower: no Lean definition or theorem statement changed, and each
moved edge still holds as written. The other eleven changed SPEC clauses, the two ACCEPTANCE
clauses and every changed or new ANCHORLESS and SWITCH clause had no edges and stay deferred.

`reports/rule-coverage.md` is regenerated: the 63 rule rows owned by the nineteen changed SPEC
clauses change only their clause ID, and START-10-5's evidence reason now names the forwarder.
INDEX only retitles four rows (PROOF-6.2-46a, SYNC-9-5a, START-10-5d, PARAM-11-12a); no rule is
added or retired.

## Checked against the model

- **The Inbox's checkpoint forwarder.** `unzenProve` already applies the forwarder's height
  gate: it accepts the Unzen proof's checkpoint when no start is written, and afterwards only
  at or below S, and the whole call fails otherwise, as an Unzen `prove` does when the forwarder
  reverts. It appends the checkpoint's height, hash and stateRoot unchanged, and is the only
  call that appends to `World.legacySignals`, matching the forwarder's caller check. Its other
  conditions are the Unzen Inbox's own `prove` checks. So START-10-5's and START-10-5c's edges
  hold under the new text. The docstring of `unzenProve` and START-10-5's evidence reason now
  name the forwarder; the forwarder's caller check and its call into SignalService are not
  modelled separately.
- **The start-implementation check.** The model never names the contract. It abstracts the
  check as `Environment.startImplementation`, a predicate on S's stateRoot that node trust
  (`nodeTrust`), the guest at p = S (`LiveBatchCertificate`), the first landing's custody root
  (`Custody.FirstFence`) and H4's `UnzenStartUsable` hypothesis read. Renaming the
  contract from `Anchor` to the L2 `SignalService` leaves that predicate, and every statement
  that uses it, as it was. `reports/recoverability.md` now names the L2 SignalService.
- **The node's fork-time check.** The model has one fork time, `Core.forkTime`, which
  `setOrigin`, `Custody.FirstFence` and `nodeTrust` all read; it has no local override and no L2
  SignalService state. The new check is therefore not modelled, and SYNC-9-5a stays deferred.
  Node trust in the model omits a check the spec adds, so properties proved for trusted nodes
  still hold for a node that also makes it. H4's path needs a node that becomes trusted; a node
  whose own fork time differs from `beaconRootsFrom` halts under the new check, a deployment
  failure (PARAM-11-12a) that the model does not represent.
- **Wording.** The README's Terms section already uses registry checkpoint, sub-proof and
  `activeCommitteeSnapshot`; its "Unzen lane" entry now says that `unzenProve` includes the
  Inbox's forwarding.

## Deferred

The L2 SignalService, its `beaconRootsFrom` cutoff and EIP-4788 root resolution, the L1
SignalService's syncer configuration, the Unzen Inbox upgrade of START-10-5d and the node's
fork-time check are not modelled. The rules of the changed clauses that carry no edge stay
deferred, among them SYNC-9-5a, START-10-5b, START-10-5d, PARAM-11-12a and SYNC-9-16. All
ANCHORLESS and ACCEPTANCE clauses remain deferred.

Evidence after this pin: 61 partial / 519 deferred clauses (twelve new deferred ANCHORLESS and
SWITCH clauses); 45 partial / 39 supporting / 524 deferred binding rules, plus 32 deferred
assumption/limitation rows, unchanged.
