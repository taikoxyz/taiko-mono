# Etna contracts

Etna is a proof-of-stake validity rollup. A committee of TAIKO stakers orders and finalizes L2
blocks with stock CometBFT, anyone can land a proven batch on L1, and L1 recognizes only landed
checkpoints. These are its L1 contracts; the L2 changes are listed under
[Anchorless L2 contracts](#anchorless-l2-contracts). Section numbers refer to the
[Etna PoS + ZK design specification](../../../docs/etna/SPEC.md); appendix A is its
encodings and appendix B its L1 storage layout.

The current specification baseline is the Etna spec at docs PR
[#22422](https://github.com/taikoxyz/taiko-mono/pull/22422) head
`994960561490b882558da7847a21a41a271350c5`, on top of main `f556fa941`
([#22419](https://github.com/taikoxyz/taiko-mono/pull/22419)). Against the earlier baseline it makes
the start write a permissionless latch over the closed and fully proven Unzen Inbox, removes the
originWriter, closes the Unzen checkpoint forwarder at the start write, replaces the L2
SignalService's fork time with `usesBeaconRoots`, keys forfeiture and recovery exclusions by bond id
alone, takes the committee config hash's fifth word from the registry's `minStake`, bounds recovery
gas with a capacity F, binds schedule calls to a generation, lets the registry count shrink and
commits a committee with one `setHash`. This branch's copy of the spec also clarifies the
distinction between empty and present zero-filled vote hashes in STAKE-4.1-31 and ENC-A-44/45,
matching stock CometBFT's protobuf encoding.

## Contracts

- `iface/IEtnaInbox.sol`, `impl/EtnaInbox.sol`: `init` and the Etna start write (spec 10 steps
  5-5c), `land` (6.1), the forced inclusion queue and the protocol fee sweep (7.1), governance
  `recover` (8, 8.3, 8.4), the rules schedule (10.1) and Inbox slots 258–293 (appendix B).
- `iface/IUnzenProposeCutoff.sol`: the `proposeCutoff()` getter the upgraded Unzen Inbox
  (`layer1/core/impl/InboxWithEtnaCutoffs.sol`) exposes and `setOrigin` reads (START-10-5d).
- `impl/EtnaInboxBootstrap.sol`: the Inbox proxy's first implementation; it only sets the owner,
  so the proxy address exists before the registry that fixes it (10 step 1).
- `iface/IEtnaStakingRegistry.sol`, `impl/EtnaStakingRegistry.sol`: registration into the
  lowest empty slot, exits, withdrawals, double-sign slashing, recovery's forced exits and
  per-block checkpoints (4.1).
- `libs/LibEntriesTree.sol`: `regLeaf` and `entriesRoot` (appendix A) as an incremental Merkle
  tree of depth 12, one leaf per slot, whose count grows by appending and shrinks with `truncate`.
- `libs/LibEtnaKeys.sol`: 33-byte secp256k1 key decompression for registration, `ckAddr` and
  65-byte low-s signature checks (4.1, appendix A).
- `libs/LibCometVote.sol`: `chainDomain`, the 48-byte CometBFT `chain_id` and the CometBFT
  v0.40.0 vote sign bytes that double-sign evidence is checked against (3.1, 4.1, appendix A).
- `libs/LibEtnaForcedInclusion.sol`: the forced inclusion queue storage and fee (7.1).

## EtnaInbox

- The Etna start S is block 0 on a new network and the last Unzen block on a network that switches
  from Unzen ([SWITCH.md](../../../docs/etna/SWITCH.md)). The immutables `unzenInbox` and
  `etnaForkTime` are both zero on a new network and both non-zero on a switching one; the
  constructor rejects a mix and an Unzen Inbox without code. There is no originWriter
  (PARAM-11-12a). The immutable `recoveryCapacity` is F (START-10-18), in [1, 4096].
- `init`: owner only, sent through `upgradeToAndCall` from the bootstrap implementation. It checks
  every spec 10 deployment constraint it can see, checks that the registry's fixed Inbox is this
  proxy and that both use the same L2 chain id and owner with no pending transfer, then reads the
  registry's immutable `minStake()`: it requires `minStake >= vp_unit`, `4096 * minStake > 10^27`
  and K = min(4096, floor(10^27 / minStake)) <= F (`RecoveryCapacityExceeded`, START-10-14), and
  uses that same minStake as the fifth word of `committeeConfigHash` (ENC-A-36). It rejects dirty
  finite initial fields and generation-0/1 origin records, and writes the appendix B initial
  values. This is no proof that every historic mapping key is empty; bootstrap creation and
  privileged upgrade history must also be checked. On a new network it also performs the start
  write with S = 0 and the genesis hash and state root and saves the block-0 SignalService
  checkpoint; on a switching network both must be zero and it writes no start.
- `setOrigin(S)`: on a switching network anyone writes the start once (START-10-5a, LAND-6.1-8a),
  following the spec's reference body: an initialized Inbox with slot 273 zero, 0 < S,
  `block.timestamp >= etnaForkTime`, the live Unzen Inbox's `proposeCutoff()` non-zero and reached,
  its `getCoreState()` showing every proposal finalized (`nextProposalId == lastFinalizedProposalId
  + 1`), and the L1 SignalService checkpoint at S with a non-zero block hash equal to the
  `lastFinalizedBlockHash` and a non-zero state root. A failing check or read reverts. The caller
  supplies only S; the start write takes the hash and state root from that checkpoint and writes
  slots 272–274 (L1_0 = its own block), generation 0's origin, the checkpoint (S, hash) and S's
  landing record, emits `StartWritten`, closes the forwarder and opens the forced inclusion queue.
  It leaves the checkpoint at S untouched, and nothing rewrites the start afterwards (START-10-5c).
- `saveCheckpoint(checkpoint)`: on a switching network, forwards the Unzen Inbox's checkpoints to
  the L1 SignalService, which accepts checkpoints only from this Inbox (START-10-5). Only
  `unzenInbox` may call it; it accepts any height while slot 273 is zero and reverts at every height
  once it is nonzero (`ForwardingClosed`). It passes the checkpoint unchanged and ignores pause,
  initialization and the registry lock, so it reverts only for these checks and the SignalService's
  own.
- `etnaStart()`: (S, start hash), or (0, 0) before the start write. `generationStartHeight()` and
  `recoverySnapshot()`, which read the current generation's origin record, instead revert with
  `StartNotWritten` before the start write, since no record exists yet (spec 8.4).
- `land(input, leaves, proof)`: the spec 6.1 reference Solidity, check for check, plus the shared
  registry lock below. Before the start write no landing passes, because `landings[0]` is
  unwritten. p, c and h are any heights with p ≤ c < h and h − p ≤ `maxBatchBlocks`; `leaves` are
  the h − p − 1 cut leaves of the heights p + 1, ..., h − 1, one per height; the proven
  `activeCommitteeSnapshot` must be at least the stored one (`CommitteeSnapshotRegressed`,
  STAKE-4.1-29); and if c > p the leaf at c is compared with c's slot 285 record, all before the
  immutable verifier checks the 21-word statement with `verifyProof(0, statement, proof)` (0: no
  proposal age applies). The reference's `isValidLanding(p)` is the written-record check: these
  contracts have no verifier-failure rollback, so no written record is voided. A landing from S
  reads no Unzen state: `setOrigin` already authenticated the tip. The landing then moves the
  checkpoint, `activeCommitteeSnapshot` and the queue head, writes `landings[h]` with the actual
  parent c, saves the SignalService checkpoint and emits `Landed`. It pays nothing to anyone.
- `saveForcedInclusion(tx)`: after the start write, at most 8,192 bytes, for
  `fee × (threshold + pending) / threshold` Gwei, which stays in the Inbox; overpayment is
  refunded. An entry stores only the transaction hash, the L1 timestamp and the L1 block.
- `sweepProtocolFees()`: anyone sends the Inbox's whole balance to the immutable
  `protocolFeeRecipient`, the DAO treasury.
- `recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, exclusions, ...)`,
  whose last two arguments are `fiToClear` and `rules`: owner only after the start write, with all
  expected values matching current state, `block.timestamp <= validUntil` and a non-zero `rules`
  equal to `nextRules + 1`. `exclusions` are strictly increasing bond ids, one word each
  (ENC-A-51); since ids are issued from 0 and never reused, one read of the registry's
  `bondCount()` shows every one issued before any write (`UnissuedExclusion`, RECOV-8-40a), a
  withdrawn bond included. Recovery increments the uint256 authorization nonce. With R =
  `block.number`, each excluded bond's exit moves to min(existing, R) in the registry, each listed
  queue entry's hash becomes `keccak256("")`, the generation increments and its origin (c, R's
  number, R's timestamp) is written once to slot 290 (`OriginAlreadyWritten` if that record
  exists). It then clears the planned stop and, for a non-zero `rules`, sets `activeRules =
  nextRules = rules` and `rulesTime = 0`. The checkpoint, its record, the queue head and
  `activeCommitteeSnapshot` are kept. The list length is not bounded on chain; F is the length up to
  which the worst case is known to fit (below).
- `scheduleRules(expectedGeneration, rules, time)` and `scheduleStop(expectedGeneration, time)`:
  owner only after initialization; they first require `expectedGeneration == recoveryGeneration`
  (`GenerationMismatch`, START-10.1-5c), so a queued authorization cannot change or cancel the
  schedule once a recovery started another generation, then write the rules schedule in slot 293
  exactly as spec 10.1 steps 5a-5c, with `maxAnchorAge` as the deadline. A due `nextRules` is
  promoted first; a failed call keeps nothing. `recover` and both calls emit
  `RulesScheduleUpdated` with the new slot 293 word.
- `invalidateRecoveryNonce(expectedRecoveryNonce)`: owner only after initialization; checks and
  increments the nonce without wrapping, invalidating all unexecuted authorizations carrying it.
  Landing does not consume the nonce. A future verifier-failure rollback upgrade must preserve
  and increment its current value, so restoring an old checkpoint cannot revive authorization.

### Recovery capacity F

F is 212 for this bytecode, the deploy scripts' default (`DeployEtnaDevnet.DEFAULT_RECOVERY_CAPACITY`).
`EtnaInboxRecoveryCapacityGasTest` runs the worst-case ordinary recovery through a
`MainnetDAOController` that owns the Inbox: every slot held, F exclusions spread evenly over the
4,096 bonds (every one a registered bond in its own slot without an exit, which maximizes the entries
tree nodes written), one forced inclusion to clear and ruleset 1 installed over an all-zero slot
293. Counting the 21,000 intrinsic gas and the larger of EIP-7623's calldata floor and the standard
calldata cost plus execution, 212 exclusions need 16,718,165 gas before refunds and 213 need
16,787,608, above EIP-7825's 2^24 = 16,777,216. Because `init` requires K <= F, a deployment with
F = 212 needs minStake >= floor(10^27 / 213) + 1 base units (about 4,694,836 TAIKO); the scripts
default minStake to 4,700,000 TAIKO, K = 212. The governor or timelock that calls the controller
adds its own overhead, which the 59,051 gas of headroom must cover; measure the deployed DAO path and
re-establish F before an upgrade of this path or a change in the L1 gas schedule (START-10-18,
section 12 item 10).

`land`, `recover`, `invalidateRecoveryNonce`, `setOrigin`, `scheduleRules`, `scheduleStop`,
`saveForcedInclusion` and `sweepProtocolFees` share one reentrancy lock and reject callbacks from
registry mutations.
Pause affects none of these entry points, nor the registry's (spec 1 requires this for `land`,
`saveForcedInclusion` and the registry). Only `saveForcedInclusion` accepts ETH;
`upgradeToAndCall` rejects it too.
If a landing changes `c` after recovery is authorized, recheck the recovery conditions and
seek fresh authorization for the current tuple (RECOV-8.1-4). Maintain an accepted proof
combination covering the required rulesets throughout (START-10.1-6c).

## EtnaStakingRegistry

- `register(publicKey, amount, popSig)`: a 33-byte compressed consensus key with a proof of
  possession over the EIP-712 `Register(address owner)` digest for the caller, who becomes the
  owner for life. Each key registers once, ever. Each registration issues the next bond id
  (from 0, never reused) and takes the lowest empty slot. The stake must be at least `minStake`
  (`StakeTooLow`); with all 4,096 slots held it reverts `RegistryFull`. It never moves or removes
  another bond: a bond holds its slot from registration until withdrawal, which empties it.
  `bondForKey`, `bondInSlot` and `slotOfBond` return `(found, id)` pairs; `bondAt` returns a
  bond's record whether or not it holds a slot.
- `requestExit`, `confirmExit`, `withdraw(bondId, to)`, `slashDoubleSign(bondId, voteA, voteB)`
  and the Inbox-only `forceExit` follow spec 4.1 and 8 step 2, whether or not the bond holds a
  slot; a call naming an unissued id reverts `UnknownBond`. Withdrawal zeros the bond's balance
  and keeps its key, activation and exit, and empties its slot if it holds one. Confirming an
  exit needs an initialized Inbox whose `activeCommitteeSnapshot` reaches the exit block;
  `slashDoubleSign` needs an initialized Inbox and accepts votes from the current or an earlier
  generation.
  Both votes must recover to the same nonzero address whose lifetime key lookup, `bondForKey`,
  returns exactly `(true, bondId)` (STAKE-4.1-33): registration wrote it from the decompressed key
  and nothing releases it, so slashing never decompresses a key; a key registered to another
  bond, or to none, reverts `InvalidSignature`.
  Double-sign bounty rates are in [0, 10,000): the caller receives
  `floor(principal * slashBountyBps / 10000)` and the sink receives the remainder. The owner or
  signer may self-report for the same bounty.
  Registry mutations revert while the Inbox holds its lock, except its authorized `forceExit`.
- Vote hashes are `bytes` of length 0 or 32: an empty hash and a present all-zero hash have
  different sign bytes and BlockIDs. This changes the `slashDoubleSign` ABI from the earlier
  `bytes32` tuple; clients must refresh the registry ABI and schema-9 vectors before submitting
  evidence. `votes.slash_abi` pins the new selector and calldata.
- `topUp(bondId, amount)`: the active entry's owner deposits one positive pending amount, even
  with all slots occupied or before Inbox initialization. It has no voting power or checkpoint
  effect. `activateTopUp(bondId)` is
  permissionless at readiness, after `activationDelay` L1 blocks; activation writes the normal
  checkpoint and does not change historical committees.
  No deposit or activation is allowed after exit is set. Withdrawal and double-sign slashing
  account for **all** remaining effective and pending principal and clear the pending state.
- `forfeit(bondId, incidentId, validUntil)`: registry owner only after initialization, once per
  issued bond id (`forfeited(bondId)`; ids are never reused, so an id always names the same bond
  and key, FORF-4.4-16), with an inclusive timestamp deadline. Deducts
  `ceil((effStake + pendingTopUp) * forfeitBps / 10000)` from effective stake first, then pending
  funds, pays only `slashSink` and forces exit without resetting an existing confirmation clock.
  The flag survives withdrawal, recovery and verifier-failure rollback. There is no
  forfeiture nonce, revocation method, freeze or extra delay. Landing and recovery leave an
  unexecuted authorization usable until expiry; attribution and timely execution belong to DAO
  governance, including checking that the id names the intended bond and key (FORF-4.4-2).
  Double-sign evidence can still take the remainder.
- `forceExit(bondId)` derives the recovery execution block from `block.number` and checks only
  that the id is issued; a withdrawn bond is accepted and keeps its earlier exit (spec 8 step 2,
  RECOV-8-40a).
- Every L1 block that changes the entry in a slot ends with exactly one checkpoint
  (`l1Block`, `count`, `entriesRoot`); a change to a bond that holds no slot writes none. `count`
  is 0 when every slot is empty and otherwise one plus the highest occupied slot, occupied
  zero-balance slots included (STAKE-4.1-36): withdrawing from the highest occupied slot shrinks
  it to one plus the next occupied slot below, while an interior empty slot keeps its place with
  the all-zero entry's leaf. Padding beyond the count is `bytes32(0)` (ENC-A-38). Earlier
  checkpoints keep their own count and root. The Inbox proxy, the L2 chain id and `minStake` are
  immutables; `minStake()` is part of `IEtnaStakingRegistry`.

## Difference from the spec

- `init` takes `vp_unit`, `n_max` and `U` instead of the config hash (spec 10 step 5), reads
  `minStake` from the registry, checks their bounds and computes `committeeConfigHash` itself, so
  a configuration outside the spec bounds cannot be stored.

## Choices the spec leaves open

- The Inbox proxy starts on `EtnaInboxBootstrap`, so its address exists before the registry that
  fixes it. Once the registry exists, the owner calls `upgradeToAndCall(EtnaInbox, init(...))`,
  and `init` also requires the owner. Slot 258 then reads 3.
- `Landed` carries `VERSION = 1`; `Recovered` carries the new generation, c, R's number and
  timestamp, and both lists (exclusions as bond ids).
- F is an implementation immutable (`recoveryCapacity`) rather than a constant, so the same source
  can be measured and redeployed for another gas schedule; it has no setter or storage slot and
  does not change the `recover` interface (START-10-18).
- `init` checks the registry's identity (fixed Inbox, L2 chain id, owner, no pending transfers)
  before it reads the registry's `minStake`.
- Each field of a slot 290 origin is below 2^48.
- Evidence votes have type 1 or 2, a height in [1, 2^63), a round below 2^31 and a 65-byte low-s
  signature with V in {0, 1}. Their timestamp seconds are an int64 and their nanoseconds an int32,
  each with any value and no range check (ENC-A-45), so double-sign evidence is accepted even at
  a timestamp stock CometBFT would not sign.
- Registry storage that appendix B does not name (tree nodes, the occupancy index, the key and
  slot lookups, the bond records and the bond count) lives in the `taiko.etna.registry`
  namespace after `entries`, so nodes read only the two named slots.
- The occupancy index is a two-level bitmap over the 4,096 slots: one bit per slot in 16 words,
  and a summary word with one bit per full word. Finding the lowest empty slot takes two storage
  reads; registration sets a bit and only withdrawal clears one, so balances never touch it.
  Withdrawing from the highest occupied slot finds the new count by scanning the occupancy words
  downwards, at most 16 reads; withdrawing the sole occupied slot 4095 with every lower slot empty
  costs 164,234 gas (`EtnaStakingRegistrySoleLastSlotWithdrawalGasTest`).
- The `entries` array has exactly `count` elements: a registration into slot `count` appends,
  and a shrink sets the length directly, since every slot from the new count on is already zero.
- Every Inbox entry point also reverts with `RegistryLocked` while the registry holds its
  reentrancy lock, the reciprocal of the registry's check on Inbox execution. With a standard
  TAIKO token no registry call can reach the Inbox, so this check never fires in practice.
- The registry's `minStake` is the one stake threshold: registration, committee eligibility
  (COMM-4.3-3) and the config hash's fifth word all use it. The constructor requires `minStake`
  above 10^27 / 4096 base units (STAKE-4.1-14a), and the deploy script defaults it to 4,700,000
  TAIKO so that K <= F = 212.
- `activationDelay`, `exitDelay` and `withdrawalDelay` are each in [1, 2^32), so an oversized
  delay cannot make every registration or exit request revert.
- `maxBatchBlocks` is in [1, 12,951]. A landing of B blocks carries B − 1 leaves, and 12,951 is
  the largest B whose calldata, with a 4 KiB proof and every byte priced at today's EIP-7623
  floor of 40 gas, fits EIP-7825's 2^24 per-transaction gas cap (PARAM-11-6). The cap is an
  immutable while the calldata price is not: a higher floor fits fewer blocks, so leave
  headroom; a landing of one block carries no leaves and always fits.

`LandInput` has eight fields and carries no validator-state hash. The verifier statement is 21
static words (672 bytes); a cut leaf binds four words, the height, EL hash, Comet hash and FI
cursor, and the leaf at c, the latest checkpoint height, is checked against c's slot 285 record.
L1 never decodes the statement's preimage.

## Storage

- Inbox: appendix B exactly. The named slots are 258, 268–274, 278–282, 284, 285, 290, 292 and 293;
  reserved slots 283, 286–289 and 291 are never read or written, and slots 251–257, 259–267 and
  275–277 are unused padding. Each slot-285 mapping value has three words: the packed
  parent/generation/head, the EL hash and the Comet hash. The record's `head` is
  the forced-inclusion cursor at that height (the spec's "FI cursor"); the Inbox queue head
  (slot 281) equals it once that height is the checkpoint.
- Registry: the ERC-7201 namespace `taiko.etna.registry` with base R holds `checkpoints` at R
  and the slot-indexed `entries` at R + 1, the only slots nodes read, then the tree nodes, the
  occupancy index, the key and slot lookups, the bond records and the bond count. Bond owners
  and exit confirmations, keyed by bond id, live in the separate namespaces
  `taiko.etna.registry.owners` and `taiko.etna.registry.exit-confirmations`, outside
  `entriesRoot`.
- Pending deposits use `taiko.etna.registry.top-ups`, a bond-id mapping with a uint256 amount
  and a uint48 readiness block in the next word. Lifetime bool flags use a bond-id mapping in
  `taiko.etna.registry.forfeitures` (STOR-B-32). Neither enters the entries root or ordinary
  witnesses.
- Packed words in both contracts lay out their fields from the least-significant bit: `ckPrefix`
  takes 8 bits, every other field 48, and a wider value reverts.
- The machine-readable layout, with every slot, mapping derivation and packing table, is the
  `layout` section of `testdata/etna_vectors/vectors.json`; `EtnaVectors.t.sol` checks both
  contracts against it. `impl/*_Layout.sol` are generated by `pnpm layout:l1`.

## Deployment

`script/layer1/etna/DeployEtnaDevnet.s.sol` deploys a new network in the owner-initialized order
(the Inbox proxy on its bootstrap with the L1 SignalService, the registry, then the owner's
`upgradeToAndCall` with `init`), with zero `unzenInbox` and `etnaForkTime` and the recovery
capacity F (default 212, `RECOVERY_CAPACITY`); its NatSpec lists every environment variable. The
registry's `REGISTRY_MIN_STAKE` defaults to 4,700,000 TAIKO, so that K = min(4096,
floor(10^27 / minStake)) <= F as `init` requires. Run from `packages/protocol`:

```bash
export FOUNDRY_PROFILE=layer1 S=script/layer1/etna/DeployEtnaDevnet.s.sol:DeployEtnaDevnet
# REMOTE_SIGNAL_SERVICE is the L2 SignalService predeploy, which must be the generator's address
# for L2_CHAIN_ID; L1_CHAIN_ID must be this L1. Export INBOX_PROXY and SIGNAL_SERVICE.
forge script $S --sig 'deployInboxProxy()' --rpc-url "$L1_RPC" --broadcast
forge script $S --sig 'deployRegistry()' --rpc-url "$L1_RPC" --broadcast # export STAKING_REGISTRY
# Validators register and activate; pick GENESIS_CUTOFF and compute committee 0's record hash.
# Build the L2 genesis (below) and compute block 0's hash and state root with the EL.
forge script $S --sig 'deployInbox()' --rpc-url "$L1_RPC" --broadcast
```

The L2 genesis of a new network needs the Etna L2 predeploys. In
`test/genesis/data/genesis_config.js` set `chainId` to the L2 chain id, `l1ChainId`,
`usesBeaconRoots` to `true` (every block after genesis is an Etna block with a nonzero EIP-4788
root, so the L2 SignalService then accepts no checkpoint; the golden touch key is public, and
`false` would keep the checkpoint store open and never read EIP-4788) and `remoteSignalService` to
SIGNAL_SERVICE, then run `pnpm genesis:gen` and build the genesis from the base JSON:

```bash
python3 script/layer2/build_etna_genesis.py --base <genesis.json> \
  --predeploys test/genesis/data/genesis_alloc.json \
  --predeploy-config test/genesis/data/genesis_config.json \
  --l1-signal-service "$SIGNAL_SERVICE" --output <file>
```

The builder refuses a `usesBeaconRoots` other than JSON `true`, a `remoteSignalService` other than SIGNAL_SERVICE,
another chain id and predeploys without the Anchor or SignalService. Because the checked-in
`genesis_config.json` can disagree with a gitignored `genesis_alloc.json`, it checks the same values
in the emitted bytecode too, against the `out/layer2` artifacts of the same `pnpm genesis:gen` run
(`--artifacts` overrides the directory): both proxy accounts must hold exactly the compiled
`ERC1967Proxy` runtime and point at their implementations, whose code must be the compiled
`Anchor` and `SignalService` runtimes (neither links a library), with the SignalService's
`usesBeaconRoots` true (the 32-byte word 1), its syncer the Anchor proxy and its remote SIGNAL_SERVICE, and the
Anchor's `checkpointStore` the SignalService proxy. Every other immutable of the two
implementations is pinned to the generator's value (UUPS `__self` the implementation itself, the
configured `l1ChainId`, the SignalService's `pauser` zero), and an immutable it does not know is
refused. The proxies may hold only the storage the generator writes (initialized, not paused, the
configured owner, the implementation), so a seeded signal or checkpoint is refused. No root-path
address nor SIGNAL_SERVICE may be a precompile or system contract address, and SIGNAL_SERVICE may
not be an L2 predeploy. If `out/layer2` no longer matches the alloc, for example after a rebuild
from other sources or without the AST, it refuses until `pnpm genesis:gen` reruns. It replaces the
base's accounts at the predeploy addresses with the generated ones, keeping only the account fields
execution clients accept, and adds the EIP-4788 and EIP-2935 system contracts (spec 10 step 3).
Outside `alloc` it only drops the base's derived `stateRoot`; the 100% base-fee share is the
per-block `extraData[0] = 100` rule that nodes and guests enforce, not a genesis field. It needs
Python 3.9 or later, writes `--output` only on success and removes an existing one first, so a
failed run leaves no genesis behind. `pnpm genesis:test` (CI's genesis job) runs it on real
generator output: the default alloc and a config edited without regenerating must fail, and an
alloc generated with `GENESIS_CONFIG` pointing at an Etna configuration must pass.
`generate.ts` exits non-zero on failure, so a failed run cannot leave an older config/alloc pair
behind unnoticed. After booting the EL on the genesis, also check the SignalService proxy
(`contractAddresses.SignalService` in the generated config) at block 0:

```bash
# Must print true.
cast call --rpc-url "$L2_RPC" --block 0 "$L2_SIGNAL_SERVICE" 'usesBeaconRoots()(bool)'
```

`deployInbox()` deploys the `EtnaInbox` implementation over SIGNAL_SERVICE, then upgrades and
initializes the proxy if the deployer owns it, or logs that call for the owner. No contract
checks two spec 11 bounds, so the operator must: `REGISTRY_WITHDRAWAL_DELAY` no shorter than the
double-sign evidence window (suggested at least 50,400 L1 blocks, about 7 days) and
`MAX_ANCHOR_AGE` above the L1 finality delay (PARAM-11-5). That delay is the age the newest
finalized L1 block reaches just before the next finalization while L1 finalizes on schedule
(three epochs, 1152 s, on Ethereum), plus the deployment's allowance for slots missed at an epoch
boundary and for nodes' delay in importing that finalization. `init` checks only the 1152 s floor
(START-10-9), and on Ethereum 1152 s itself does not satisfy PARAM-11-5 (Q10-8).
`REGISTRY_FORFEIT_BPS` is an explicit deployment input in [1, 10,000], with no production default.
The launch manifest must also pin independent `C_CAP_MIN`, conservative per-TAIKO `P_REF` in the
same currency, its source/haircut/expiry/review frequency and responsible owner. Require positive,
current values and compute `S_MIN_TOTAL = ceil(3 * C_CAP_MIN * 10^18 / P_REF)`. At the actual
committee-0 snapshot require selected effective stake at least that floor and
`ceil(totalPower / 3) * vp_unit * P_REF >= C_CAP_MIN * 10^18`; pending and unselected funds do not
count. Every entry and known common controller must remain strictly below one third of power.
The client's committee-record report supplies the selected stake and integer powers for review.
These are launch acceptance checks, not a price oracle or consensus/signing gate. During operation
and recovery, shortfalls or expired valuation require alerts, disclosure and replenishment rather
than blocked recovery or signing. Owners can top up existing entries even in a full registry;
DAO funding does not bypass owner-only deposits. Exercise detection, attribution, governance and
L1-inclusion budgets against the fastest lawful withdrawal: the suggested seven days is not
automatically enough for forfeiture execution. See SPEC 4.4/8.3/11 and ACCEPTANCE 4.

## Anchorless L2 contracts

These implement [ANCHORLESS.md](../../../docs/etna/ANCHORLESS.md) sections 4 and 8.

- `shared/signal/SignalService.sol`: one contract for L1 and L2, with one syncer each and the
  immutable `usesBeaconRoots`, false on L1 and true on L2. No contract holds the Etna fork time.
  With the flag false, the checkpoint store is the only root source and never closes. With it
  true, `saveCheckpoint` reads EIP-4788 at `block.timestamp` and reverts `SS_CHECKPOINTS_CLOSED`
  unless the read returns one zero word. Every block before Etna records a zero
  `parentBeaconBlockRoot` and every Etna block a nonzero one, so the store closes by itself at the
  first Etna block (block 1 on a new network). The public golden touch key therefore cannot save a
  forged checkpoint through `anchorV4`, and a missing EIP-4788 contract fails closed. Proofs
  resolve their root from a checkpoint first (`blockId` an L1 block number up to `uint48`) and, on
  L2 only, from EIP-4788 when no checkpoint is held (`blockId` an Etna block's full `uint64` L2
  timestamp). The choice does not depend on the verifying block, so checkpoints saved before the
  fork stay provable after it. An id with neither, or with a zero, missing or overwritten EIP-4788
  root, reverts `SS_CHECKPOINT_NOT_FOUND`. It reads no Inbox state and adds no storage.
  Checkpoints and cached signals stay under `VERSION`. Bumping `VERSION` hides every checkpoint and
  cached signal at once, including the checkpoints a verifier-failure rollback must keep usable,
  so RECOV-8-27 rules out a rollback that only moves the whole checkpoint mapping to a new
  version.
- `layer2/core/Anchor.sol` needs no Etna change (ANCHORLESS.md section 8).
- `layer2/etna/EtnaSignalServiceUpgradeGuard.sol`: the read-only helper the readiness L2 message
  calls (SWITCH.md section 3). `checkBeforeUpgrade(proxy, preEtnaImpl)` requires the pre-Etna
  implementation, the canonical EIP-4788 runtime (code hash `0xf57acd40…f4b02c`) and a zero root at
  the current timestamp. `checkAfterUpgrade(proxy, expectedImpl)` requires the expected
  implementation and `usesBeaconRoots()` true. Each check reverts rather than returning false,
  because the `DelegateController` checks only call success.
- `script/layer2/DeployShastaL2Contracts.s.sol` (with the mainnet and Hoodi entry points) deploys,
  without upgrading the proxy, the switching L2 SignalService implementation (syncer the `Anchor`
  proxy, `usesBeaconRoots` true, the existing pauser) and the guard. It takes no fork time.
- `script/layer2/etna/BuildEtnaReadinessL2Message.s.sol`: `LibEtnaReadinessL2Message.buildActions`
  returns `[guard.checkBeforeUpgrade, signalService.upgradeTo(etnaImpl), guard.checkAfterUpgrade]`.
  There is no deadline or fork time; use execution ID 0. A failed check reverts the batch and leaves
  the message retriable with the proxy unchanged.

## Tests

Run from `packages/protocol`:

```bash
pnpm test:l1 --match-contract 'Etna|LibEntriesTree|LibEtnaKeys|LibCometVote'
FOUNDRY_INVARIANT_RUNS=256 pnpm test:l1 --match-contract 'Etna.*Invariant'
pnpm test:l2 --match-contract 'EtnaGenesisTest|DeployShastaL2Config|EtnaSignalServiceUpgradeGuard'
pnpm test:shared --match-contract 'SignalService'
FOUNDRY_PROFILE=layer1o forge build
python3 -m unittest discover -s test/layer2/core -p 'test_etna_genesis.py'
python3 -m unittest discover -s ../../testdata/etna_vectors -p 'test_vectors.py'
```

The full-capacity gas suites (`EtnaInboxRecoveryCapacityGasTest`, `EtnaInboxRecoverFullRegistryGasTest`,
`EtnaStakingRegistryFullCap*`, `EtnaStakingRegistrySoleLastSlotWithdrawalGasTest`) prefill all
4,096 slots and take longer than the rest.

`testdata/etna_vectors/README.md` explains how to regenerate the vectors.

## Switching from Unzen

[The switch preparation scripts](../../../script/layer1/etna/README.md) retain the existing L1
SignalService and deploy the Etna bootstrap, registry, dedicated verifier instances and replacement
implementations without upgrading live proxies, and emit the action lists of the readiness and
scheduling proposals and of a postponement, around reverting guard calls (SWITCH.md sections 3 and
7). `InboxWithEtnaCutoffs` preserves Unzen's configuration and storage while applying immutable
proposal and FI cutoffs and exposes `proposeCutoff()`, the timestamp from which its `propose`
reverts; its `signalService` names the Etna Inbox proxy, so Unzen `prove` saves its checkpoints
through `EtnaInbox.saveCheckpoint` until the start write closes it. The L1 SignalService upgrade is
the shared implementation with the Etna Inbox as its only syncer and `usesBeaconRoots` false,
keeping VERSION=1 and the shared signal/checkpoint storage. `setOrigin` reads the real six-word
Unzen CoreState ABI.

## Out of scope

- The verifier-failure rollback (spec 8); it comes with the Inbox upgrade replacing the verifier,
  in one DAO upgrade that also upgrades the registry, the L1 SignalService and the L1 Bridge
  (RECOV-8-26). After it no voided checkpoint can be read through the SignalService or proven
  against, while every other checkpoint stays usable (RECOV-8-27), and every signal the
  SignalService cached, and every Bridge message left `RETRIABLE`, at or after the L1 block of the
  first bad landing is unusable until it is proven again against a checkpoint the SignalService
  holds after the rollback (RECOV-8-27a).
- DAO proposal submission: the scripts emit the actions and the guards revert on chain, but
  assembling, authorizing and executing the proposals is governance tooling.
- Snapshot verification and checkpoint import are client work. Missing-data retry rules, R₀
  finality and the checks of S's timestamp and L2 SignalService implementation (SYNC-9-5a,
  PROOF-6.2-46a) belong to clients and guests; the contract enforces its observable gates. Switch
  deployment rehearsal remains outstanding.
- Real proving guests. Tests use mock verifiers, so they show contract behaviour, not proof
  soundness; production needs a verifier that requires two proofs, at least one ZK (6.2).

The Inbox, the registry, the L1 SignalService and the L1 Bridge are upgradeable proxies whose
owner should be the DAO behind a timelock; an upgrade can bypass any rule here (spec 1).
