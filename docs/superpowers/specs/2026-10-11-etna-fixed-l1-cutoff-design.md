# Etna committees from fixed L1 cutoffs

## Objective and approval context

The user approved the fixed-L1-cutoff architecture for PR #22280 and PR #22286,
requested that committee derivation and activation require neither a separate
`set()`/`commitSet()` transaction nor a committee-publication `land()` transaction,
and authorized pushing both branches after verification. Back-pressure and
recovery-generation rules remain unchanged.

Baselines: client `50dd8723622daac0930ac7a03688102a933f20d1`; protocol
`639bae72ba2e69fc44387306d56f9fef7cb6703d`. This document makes the previously
presented architecture concrete before implementation.

## Fixed committee schedule

Genesis remains L2 block 0, epoch 0, with CometBFT initial height 1.
Let `L = epochLenL2`, `E = epochLenL1`, `G = cutoff_grid`, and
`H(t) = 1 + t * L`. All additions and multiplications are checked for overflow.

For committee 0, `cutoff(0) = genesisCutoff`. For every `t >= 1`:

```text
base(t) = L1_0 + max(t - 2, 0) * E
lagged(t) = max(base(t) - cutoff_lag, 0)
cutoff(t) = max(genesisCutoff, floor(lagged(t) / G) * G)
```

`G` must be nonzero. The two-L1-epoch reference preserves the existing heartbeat
lookahead and makes the cutoff available before the target L2 epoch. It does not
depend on an L2 parent's chosen anchor, a landing reference, transaction timing,
or the current wall clock. The cutoff is not silently advanced on failure.

The registry snapshot is the last checkpoint with `l1Block <= cutoff(t)`.
Authenticate checkpoint-array length, selected checkpoint metadata/root and,
when present, the next checkpoint's height. Check that the next checkpoint is
after the cutoff, and verify the complete entry count and entries root.

For runtime switch witnesses, verify those registry slots under the committed
parent anchor's state root. Require `cutoff(t) <= parent_anchor.number` explicitly.
Historical entries may be discovered through L1 RPC or cached data; discovery
results are never trusted without root verification. The proving header can be
later than the cutoff because registry checkpoint roots are immutable once the
L1 block closes. L1-only proof jobs may use their authenticated reference header
as the proving header, subject to the same cutoff coverage condition.

## Membership and heartbeat rules

Keep the existing deterministic algorithm: active-at-cutoff and effective-stake
eligibility; one member per public key with the earliest eligible bond retained;
the `n_max` cap, stake ranking and deterministic tie-break; MEM-08 ordering and
set root; floor division by `vp_unit`; stake/power overflow checks.

Keep the current heartbeat predicate, including launch exemptions for committees
0, 1 and 2, the target-epoch evaluation instant, its cap at the cutoff window,
and the nonzero sequence guard. Moving the witness does not move the heartbeat
instant to the switch or landing time. No implicit fallback is introduced when
the fixed snapshot yields an empty committee.

## Autonomous ABCI activation

Nodes may discover/cache a future committee after its cutoff becomes final.
Advance notice is supplied by the fixed L1 schedule; publication in an earlier
L2 block is no longer required.

At `S(t) = H(t) - 2`, for each `t >= 1`:

1. Require exactly one committee witness for `t` and verify it using the fixed
   cutoff and the committed parent's authenticated anchor.
2. Recompute the committee record and members; compare every claimed record
   field with the derived record.
3. On `FinalizeBlock`, retain the derived set and return validator updates from
   the outgoing set to that set.
4. On `Commit`, persist the application state. CometBFT activates the updates at
   `H(t)` using its ordinary H+2 timing.

There is no committee witness requirement at epoch-first heights, except for
the separately authenticated genesis committee in `InitChain`. Non-switch
blocks must not carry a runtime committee witness. The envelope version becomes
2 so old witness timing cannot be accepted accidentally.

Remove runtime committee-landed checks and their Inbox mapping proof. Anchor
witnesses remain required when the anchor changes and at height 1; switch height
alone no longer forces one. Anchor progress, Inbox status, generation and the
exact existing back-pressure rule remain active. An unchanged anchor is inherited.

Normal proposal processing still confirms a newly supplied L1 anchor against
the node's own canonical/finalized L1 view. Finalization and replay remain free
of L1 RPC and rebuild the same sets and updates from embedded witnesses.

## Authenticated derivation configuration

Without an on-chain starting-committee hash, fixed snapshot selection alone is
insufficient if the prover can supply different derivation parameters.

Introduce a nonzero `committeeConfigHash` as a trusted genesis deployment input,
stored at the previously reserved Inbox slot 269 and exposed by a getter.
Its canonical encoding is:

```text
keccak256(abi.encode(
    bytes32("ETNA_FIXED_CUTOFF_V1"),
    uint256(l2ChainId), address(stakingRegistry),
    uint64(cutoffGrid), uint64(cutoffLag),
    uint256(vpUnit), uint256(sMin), uint64(nMax),
    uint64(heartbeatWindow), uint64(2), uint8(1)
))
```

The last words bind the fixed lookahead and record/algorithm version. Genesis
schedule fields (`L1_0`, both epoch lengths and `genesisCutoff`) remain independently
authenticated through Inbox storage under an authenticated L1 header. The guest
must verify both the config opening and this schedule; none is an unchecked hint.

The client independently computes the hash from its configured parameters.
Genesis verification rejects a different on-chain value. Persist the hash in
the authenticated genesis record and check it when loading a saved state so a
configuration change cannot silently reinterpret a committee.

## Inbox and V4 landing statement

Keep status at 258, generation at 268, checkpoint at 270-271, genesis at 272-274
and genesis cutoff at 279. Replace slot 278's unused mapping anchor with the
single genesis committee record hash; retain that bootstrap authentication but
publish no future epoch records. Expose it as `genesisCommitteeRecordHash()`.
Remove the future `committee(epoch)` getter, `CommitteeRecorded` event and
`CommitteeRecord[]` landing outputs. Keep other package/contract scopes unchanged.

`LandInput` becomes the four fields `lastHeight`, `lastBlockHash`,
`lastStateRoot`, and `l1ReferenceBlockNumber`.

Use a new, flat fifteen-word V4 statement:

```text
TAIKO_ETNA_LAND_V4,
l1ChainId, l2ChainId, executingInboxProxy, configuredStakingRegistry,
recoveryGeneration, parentHeight, parentBlockHash, committeeConfigHash,
lastHeight, lastBlockHash, lastStateRoot,
l1ReferenceBlockNumber, l1ReferenceBlockHash, packedOrderedBlobHashesHash
```

All identities, generation, parent checkpoint and config hash are derived by the
contract, not replaceable by the caller. Preserve the proxy/registry public-input
binding, reference ancestry, blob presence/binding, batch-size and height limits,
SignalService checkpoint saving, nonreentrancy and verifier-revert rollback.

The authoritative guest rules require each used committee to be derived from its
fixed cutoff and authenticated registry snapshot, including the parent certificate
and all current/next validator hash checks across H+2 boundaries. Bind every L1
account proof to the corresponding configured address. A batch may start or end
at any valid height; it never needs a previous batch's committee output. Witnesses
may be deduplicated by epoch within a proof job. The dummy proof provider remains
explicitly dummy; this task does not implement a ZK guest.

## Lander and persistence

Authenticate needed committee contexts with registry witnesses rather than
trusting CometBFT committee query hints or an Inbox epoch mapping. The collector
still verifies complete blocks/commits, execution ancestry and the reference
header chain. Prepared proof jobs retain the authenticated per-epoch witnesses.

Remove records from publication scheduling, V4 hashing and journals. Preserve
batch/blob limits, minimum/maximum waiting, back-pressure flushes, nonce handling,
durable signed-byte journaling, receipt-reorg checks and identical-byte retries.
A switch witness may still justify a useful early flush, but is not an activation
permission or mandatory committee transaction.

Regenerate the copied Solidity interface and integration fixtures from the exact
new protocol commit using the existing generator; do not hand-edit artifacts.
Update source provenance and cross-language hash vectors consistently.

This is a new prelaunch protocol/wire version. Old V3 journals and old envelope
histories must be rejected explicitly, not migrated by inventing state, discarding
an outstanding nonce or rewriting history. Existing field-name aliases can remain
for valid new-format state. Fresh restart and full-history replay of the new
version must retain their existing behavior.

## Deliberate boundaries

Back-pressure remains `height - anchoredCheckpointHeight <= d_max - margin_v`.
The existing `epochLenL2 >= unsettledCap + 3` validation remains. Thus committee
authorization is independent of landing, while a prolonged settlement outage
can still stop overall block production. Generation identifiers, supersession
checks and the absence of a full recovery-generation bootstrap stay unchanged.

No per-block roster churn, forced-inclusion changes, snapshot/state-sync feature,
proof backend replacement, slashing, recovery fallback, fee accounting or registry
capacity redesign is part of this change. Document the unchanged empty-roster and
old-key/withdrawal assumptions; do not claim those liveness issues are solved.

## Verification and release

Regression coverage must prove:

- Different parent anchors at or after the same fixed cutoff derive the same set.
- The fixed formula handles launch epochs, lag underflow, grid flooring and overflow.
- Wrong contract, checkpoint selection, entries root, record and config opening fail.
- Switch witnesses are required at `H(t)-2`, forbidden elsewhere, and activate at H+2.
- No future committee slot is read or written; an advancing checkpoint without any
  epoch mapping permits committee activation.
- Pausing settlement still stops at the existing back-pressure cap and resumes
  after checkpoint progress; generation supersession is unchanged.
- New-version crash restart and lost-state replay reconstruct sets and EL hashes.
- V4 binds proxy, registry, config, reference, every terminal field and blob order;
  V3 digests and caller-supplied identities/config cannot be accepted.
- Real-contract lander tests cover arbitrary batch cuts around switches, cross-
  language ABI/hash vectors, races, verifier rollback and journal recovery.

Run client `just fmt`, both `just clippy` passes, `just unit` and all Docker tests.
Run protocol formatting/solhint, full tests, storage-layout comparisons and gas
snapshots. Live-fork tests whose RPC prerequisites are missing must be reported.
Have an independent reviewer check the final cross-repo transition and binding.
Push #22286 and #22280 only after their required verification succeeds; pin the
client fixture generator to the verified protocol commit and confirm remote SHAs.
