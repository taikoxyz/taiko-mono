# Etna design findings (historical 02:33Z assessment)

Historical report: counts, source line IDs and audit packaging below describe the original batch; see [review corrections](review-corrections.md) for the current schema, bindings and checks.
This report preserves the earlier assessment against the 02:33Z text, which was
not retained. The current 04:07Z bilingual snapshots and first-batch proof scope are
in [first-batch-verification.md](first-batch-verification.md). The later spec has
incorporated the K-upgrade boundary, FI trial sizing and appendix-C rate wording;
this historical report is not a fresh claim that those findings remain open.

Authority: Chinese spec
and English spec,
published snapshots 2026-10-27T02:33:14.285Z (zh) and 2026-10-27T02:33:19.646Z (en);
content hashes were in the then-committed `coverage.json` (now generated under `.scratch/generated`). This is a design assessment; client and
contract implementation PRs are not evidence of correctness or of a defect.

## What this refresh verifies

The design uses a grid cut: landings end only at heights that are multiples of the grid
interval K, `land(input, leaves, proof)` carries exactly the (h−p)/K − 1 grid-point leaves
strictly inside (p, h), the cut hash is a flat keccak over them, and the leaf at c > p is
checked against cutLeaf(c) from `landings[c]`. The 02:33Z snapshot makes K a protocol constant
built into the Inbox and both guests, with 1 ≤ K ≤ 6 and its value fixed later from measured
proving capacity; every bound that said 6 is now stated in K. The model keeps K in
`State.gridK` and proves the grid results for every K > 0 (the blob bound for every K ≤ 6).

- **Grid soundness.** `Landing.accepted_leaves_are_certified`: an accepted leaf list is the
  certified grid-leaf list. `accepted_frontier_on_certified_table`: the leaf at c (or, when
  c = p, the origin the statement binds) pins the certified cut at c to `landings[c]` and the
  FI head, so (c, h] extends the current checkpoint. `grid_frontier_index` holds for any K > 0.
- **No window choice.** `honest_leaves_pass_any_grid_frontier` (step 3) and
  `honest_fi_advance_at_any_frontier` (step 4): at every grid frontier c in [p, h) whose record
  lies on the certified chain, the honest transaction passes every c-dependent check, and
  `statement_frontier_independent` shows the statement never names c.
  `Examples.same_transaction_lands_at_any_grid_frontier` (K = 6: one (0, 18] transaction at
  c = 0, 6, 12) and `k3_same_transaction_lands_at_any_grid_frontier` (K = 3) replay it; a
  competing landing at or above h makes it revert as already settled.
- **The grid is invariant.** `OnGrid` (checkpoint and every record on the K grid) is preserved
  by `land_preserves_grid`, `Recovery.recover_preserves_grid` and `rollback_preserves_grid`;
  `off_grid_rejected`, `wrong_leaf_count_rejected` and `batch_limit_below_grid_blocks_landing`
  (maxBatchBlocks < K) cover the rejections; `recovery_origin_on_grid`: a recovery starts on a
  grid point; `Committee.pause_point_on_grid`: with U a multiple of K the pause point c+U is a
  grid point; `target_u_fits_every_k`: U = 3,600 is valid for every K ≤ 6.
- **Budget.** `Budget.grid_segment_fits_one_landing`: for every K ≤ 6, K maximal blocks with the
  0x06 prefix fit one landing's K blobs; `next_grid_point_within` / `last_grid_point_within`: a
  lander waits at most K − 1 blocks and a recovery leaves at most K − 1 provable blocks behind;
  `grid_calldata_examples`: for 300 blocks, 99 leaves (3,168 bytes) at K = 3 and 49 (1,568 bytes)
  at K = 6; 599 leaves (19,168 bytes) for 3,600 blocks at K = 6; none for h = p+K.
- **K mismatch fails closed.** `Landing.accepted_landing_fixes_guest_k`: a landing accepted with a
  certificate that is sound for guest interval k forces k to equal the Inbox's K;
  `Examples.k3_same_transaction_lands_at_any_grid_frontier` replays a K = 3 list on a K = 6 Inbox.
- **Encodings.** 128-byte leaf and 160-byte cutHash preimages, 32 bytes per packed leaf, an
  empty list for h = p+K (`Encoding.cut_preimage_lengths`, `cut_calldata_size`).
- Unchanged and re-checked: the rollback model (snapshot re-check, Inbox rollback), withdrawal
  without re-checks, confirmed exits never re-elected at R, R as generation origin, monotone
  snapshots under sound proofs, the vp_unit bound, the fee sweep, cleared FI entries, the
  124,000-byte cap, compressed keys, FI consumption and the signer. The zk-gas rewording
  (revert the whole overflowing transaction; continuing is builder policy) is EL behaviour
  outside the model.

## Findings

No P0 or P1 design defect was found.

An independent review against both snapshots contributed the three new items below, which were
checked against the spec text, and found one model gap, now closed: `CertifiedTable` lacked guest
item 10's "p and h are grid points", so a K mismatch was not provably rejected
(`Landing.accepted_landing_fixes_guest_k` now proves it).

1. **Changing K at an upgrade can deadlock settlement (new, P2).** §11 makes K a protocol constant
   built into the Inbox and both guests, but it is not in the §10 immutable list, in
   `committeeConfigHash` or in the statement, and 10.1 only requires the boundary H to be "a grid
   point". If an upgrade changes K and the settled H is not a multiple of the new K, p = H is off
   the new grid, and from the earlier grid origins the leaf at index (H−p)/K − 1 belongs to another
   height, so nothing can land; a recovery at c = H cannot land either, and only another upgrade
   helps (`Examples.k_change_at_upgrade_deadlocks`: H = 18, K 6 → 4). Fix: make K deployment-
   immutable (a new Inbox and genesis to change it), or require H to be a multiple of both the old
   and the new K; optionally bind K into `committeeConfigHash` or the cutHash preimage so a mismatch
   fails as a statement mismatch.
2. **The K sizing rule should count the 7.2 skip trial (new, P2-low/doc).** §1 and the §11 K row
   require any K consecutive worst-case blocks to be provable in one landing. 6.2 item 5 makes the
   guest reproduce the singleton build behind a legal skip, which can use a full
   `L2_BLOCK_ZK_GAS_LIMIT` before it overflows, so a block within EL limits can cost about two block
   budgets to prove and a segment about 2K. K due FI transactions that overflow late, next to
   zk-heavy, low-EVM-gas blocks (cheap per appendix C), then stall a K sized from block-only
   measurements. Fix: define the worst case as the block budget plus one singleton trial (and the
   witness verification) per block.
3. **Appendix C's data worst case assumes K divides 6 (new, doc).** "每 6 块一次 6-blob landing，约
   每小时 150 次" holds for K ∈ {1, 2, 3, 6}; at K = 4 or 5 a landing of data-full blocks holds 4 or 5
   blocks, i.e. 225 or 180 landings per hour (`Budget.data_worst_case_landing_rate`); blobs per L1
   slot are unchanged.

Nit: `maxBatchBlocks` has no K-dependent upper bound against the per-transaction gas cap: at K ≤ 5 a
full 65,536-block batch needs about 13,100 leaves (≈ 419 KB, ≈ 16.8M gas at the EIP-7623 calldata
floor, above EIP-7825's 2^24); landers can split, so liveness is unaffected.

Checked and sound: every K-dependent bound is consistent for each K in [1, 6] (U range, with 3,600
valid for every K; blob fit; the 124,000-byte cap; maxBatchBlocks ≥ K; waits and discards of at
most K − 1); K = 1 behaves exactly like per-block landing at 32 bytes per block; an Inbox/guest or
guest/guest K mismatch only stops landing (`accepted_landing_fixes_guest_k`); the zk-gas rewording is
consistent (an FI transaction at position 0 runs on the same pre-state and budgets as the 7.2
singleton, and validation never discards listed transactions, as in 3.4 rule 9).

### Still open from the 10:54Z refresh

1. **A long halt between grid points can still force a recovery (P2, partly addressed).** If
   the chain stops at a height x that is not a grid point (for example c = 600, halt at 603 with
   K = 6 because more than 1/3 of the voting power is offline), the blocks (c, x] cannot land
   until the next grid point exists. 6.3 now states the general rule that an old suffix beyond
   the ancestry budget (reference value 131,072 L1 headers, about 18 days) can only be discarded
   by recovery, but 6.3 (代价), 6.4 and 8.1 still promise "at most K − 1 more provable blocks". If
   the outage outlasts the budget and the committee resumes before a recovery, settlement stays
   at c, L2 runs on to back-pressure at c+U and the recovery discards up to U blocks, including
   everything produced after the return. Fix: qualify the K − 1 bound (the DAO recovers before
   the committee resumes once the budget may be exceeded), or choose K = 1, which removes the
   case.
2. **Nits.** The 3.4 stored-zlib fallback is still triggered by a "single-block" payload although
   every landing carries at least K blocks; `maxBatchBlocks ≥ K` is stated in §10/§11 but not in
   the §10 deployment-constraint list or the Inbox init checks, and a smaller value makes every
   land revert (`Landing.batch_limit_below_grid_blocks_landing`).

Closed since the 10:54Z refresh: the six-block provability premise is now tied to a parameter
(§11's K row requires any K consecutive worst-case blocks to be provable in one landing, with K
set from measured proving capacity).

Checked and sound (10:54Z review, re-checked for general K): every path that sets c stays on the
grid; the pause point c+U is a grid point; when c = p the origin is bound through the statement
and the `cur.head` check; the empty-leaf cutHash is unambiguous because p and h are in the
preimage; the leaf index (c−p)/K − 1 is always in range; front-running below h cannot fail an
honest transaction on the honest chain; calldata stays small; a grid-point H in 10.1 is
consistent while K stays the same across the upgrade (see new item 1), and the grid origin for
the Unzen switch is already §12 item 9.

### Still open from the 10:06Z refresh (§8 rollback)

The grid change does not touch §8's verifier-failure rollback, which sits outside the threat
model (two proof systems failing together); these four items are unchanged.

1. **The rollback target discards honest settlement (P2).** §8 defines the last trusted
   landing as the last one before the first bad landing, and voids everything after it. A bad
   landing whose EL hash, Comet hash and FI cursor are honest (only the SignalService
   stateRoot or slot 284 wrong) does not stop honest landings: the next landing's leaf check at
   c passes. The 8.1 pre-check looks only at c's landing, so a recovery can run at a later
   honest c. When the bad landing is found, the rule voids the honest records after it, leaves
   that generation unable to land (its origin is above the restored c), and forces a recovery
   from before the bad landing that discards honestly settled, final L2 blocks. L1 may already
   have paid bridge withdrawals against those honest checkpoints, while the new generation
   rebuilds L2 without the burns, so the same funds exist on both sides
   (`Examples.rollback_before_first_bad_discards_honest_settlement`). Fix: restore to the latest
   landing whose record matches the honest chain, void only the corrupted SignalService
   checkpoints, set slot 284 to the honest snapshot at that c and re-check confirmations; go back
   further only when c's own record is wrong. Checking every landing since the last audit in
   8.1 narrows the window but does not change the rule.
2. **Unexecuted recovery authorizations revive (P2-low).** 8.3 relies on c only increasing
   to kill old authorizations. The rollback restores (generation, c), so any authorization
   bound to that pair, e.g. one approved during the stall before the bad landing, becomes
   executable the moment the upgrade lands; the spec says only that the DAO cancels them
   "同时". Require cancellation before or atomically with the rollback (or make the upgrade
   change a value that `recover` must match).
3. **Side effects of an invalidated recovery persist (P2-low/doc).** If a recovery ran
   above the restored c, its FI blanking (`txHash := keccak256("")`) and forced exits
   (exitEffectiveL1 = min(·, R)) survive: txHash changes only through recovery and
   exitEffectiveL1 only moves earlier, and the rollback restores only 270/271, 281 and 284.
   Blanked users lose their forced transaction without refund and excluded validators cannot
   undo the exit (a new key is needed). The spec should say whether the rollback restores them
   or the next recovery decides again.
4. **Rollback text gaps (doc).** (a) Voiding SignalService checkpoints needs a SignalService
   upgrade, not only Inbox and registry. (b) Slot 281 packs head and tail; only the head lane
   is restored, otherwise entries enqueued since (whose fees were kept) disappear. (c) "作废"
   later records should mean zeroing them, since §9 trust and 5.3 reconstruction read slot 285.
   (d) The confirmation re-check only helps if the upgrade executes within `withdrawalDelay` of
   the first confirmation that relied on the bad snapshot; say so as the procedure's deadline.

Nits: the 8.1 comparison of slot 284 with "签署 c 的 committee 的选人 snapshot" is undefined for
c = 0 (it should be genesisCutoff); the deployment constraints give no upper bound for
`activationDelay`/`exitDelay`, although activeFromL1/exitEffectiveL1 are 48-bit lanes that revert
on overflow, so an oversized `exitDelay` would make every requestExit revert.

Checked and sound (10:06Z review): the confirmation re-check keeps every confirmation made
before the first bad landing (`Staking.rollbackBySnapshot_keeps_covered`) and clears exactly
those that needed the bad snapshot, including same-block ones; `landings[c]` exists in every
reachable state and the rollback keeps it consistent (`Recovery.rollback_record_consistent`);
`cur.head == fiHead` holds by construction (redundant but harmless); land and recover in one
L1 block are safe in either order; the 2^48 − 1 sentinel and 48-bit lanes are unreachable for
L1 block numbers, FI indices, heights and generations.

The grid also retires the earlier window-related notes (window sizing, cut-tree padding and the
load-bearing `cutStart+n−1 ≤ h` bound); they no longer apply.

## Model simplifications

- `land_snapshot_below_block` and the `snapshot < R` premises of the recovery theorems rest
  on the proof-certified `snapshot ≤ reference`. Events and `nonpayable` are not modelled.
- `CertifiedTable` covers the cut table's length, its grid-leaf cutHash, origin, end, the
  0-or-1 FI cursor steps and p, h on the guest's grid; that intermediate cuts come from real headers and executions is guest
  item 10, outside it. A supplied leaf is a free term (`Leaf.cut` or an arbitrary word).
- `State.checkpoint` holds lastCheckpoint (270/271); the frontier check reads the slot 285
  record at c from `records` (`currentRecord`), as the Solidity reads `landings[c]`. Origin
  existence uses `recordAt … isSome` where the Solidity tests `elHash != 0`; they agree
  because written records carry a real block hash.
- Recovery exclusions act on `Committee.Entry`; `Staking.exclude_matches_recovery` shows the
  bond-level update is the same.
- L1 block monotonicity (a recovery block R is later than every landing block) is an
  environment fact used as a premise.
- `Forced.admissionFee` rounds down in gwei before converting to wei.

## Remaining boundaries

Real guests, MPT, KZG/blob decoding, canonical encodings, EL execution including zk gas,
stock CometBFT behaviour, EVM/bytecode refinement, the durable signer and measured
resources remain external, as listed in the then-committed `coverage.json`. These are specification proofs,
not production conformance or deployment readiness.
