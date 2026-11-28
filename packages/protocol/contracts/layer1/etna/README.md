# Etna contracts

Etna is a proof-of-stake validity rollup. TAIKO stakers bonded on L2, or a DAO fallback key set when
their stake cannot sign, order and finalize L2 blocks with stock CometBFT; anyone can land a proven
batch on L1, and L1 recognizes only landed checkpoints. These are its L1 Inbox, its L2 staking
contract `EtnaStaking` and the other L2 changes listed under
[Anchorless L2 contracts](#anchorless-l2-contracts). Section numbers refer to the
[Etna PoS + ZK design specification][spec]; appendix A is its encodings and appendix B its storage
layout.

The current specification baseline is the Etna spec of
[#22425](https://github.com/taikoxyz/taiko-mono/pull/22425) at
`797a708e57badb02dc4e974dcaf9167232aa2969`. Every spec link here points at that commit, not at this
package's `docs/etna`, which still holds the earlier baseline (main at
`3602629758beb653423a23608fd1960810efcfac`). Against that baseline it moves staking to L2: the L1
staking registry, committees and epochs, committee 0 and its genesis cutoff, the stored committee
snapshot (slot 284), recovery exclusions and the recovery capacity F are gone. The L2 `EtnaStaking`
contract seats at most 128 bonds of bridged TAIKO and, in a call the EL makes at the start of every
Etna block, counts missed signatures, applies their penalties, releases the seat of a bond whose key
has missed `missReleaseLimit` blocks in a row and writes the candidate snapshot. The Inbox holds a
DAO fallback key set and a `minTotalStake` threshold. The candidate that a block's call writes signs
two blocks later if it is a valid set whose total stake reaches the threshold; otherwise, and for
the first two blocks of every generation, the fallback keys sign. Present all-zero vote hashes keep
stock CometBFT's encoding, which that spec states. That spec's proposer rule that moves the anchor
once per 1,024 blocks (CONS-3.3-4) and its L1 history links in the guests' header chains
(PROOF-6.2-34a) need no contract change; only the `MAX_ANCHOR_AGE` a deployment chooses follows them
([Deployment](#deployment)). In that spec a penalty no longer resets the miss count, so a run of
misses is penalized at every multiple of `missLimit`, and the new staking immutable
`missReleaseLimit` releases the seat of a bond whose run reaches it, whatever stake the bond holds
([EtnaStaking](#etnastaking)). The spec's changes from `fbc7a5162` to `797a708e5` need no contract
change. They state that a block-start call that fails, including the first call of a generation
after a recovery, counts no miss and resets no count, so a seat that keeps its bond keeps its
count until a call succeeds (RECOV-8-59): `onBlockStart` makes all its writes in one call, so a
failed call keeps every count, and taking or releasing a seat zeroes the seat's count. They state
that a penalty that leaves a bond its seat changes the candidate only if it lowers the bond's power
floor(effStake / vpUnit) or takes the total below `minTotalStake`, which follows from the records
and total the snapshot already writes. And they state that the block-start call to a staking
address that holds no code removes an empty account there (EIP-161, CONS-3.2-13), which is the EL's
behaviour.

## Contracts

L1, in this directory:

- `iface/IEtnaInbox.sol`, `impl/EtnaInbox.sol`: `init` and the Etna start write (spec 10), `land`
  (6.1), the forced inclusion queue and the protocol fee sweep (7.1), governance `recover` (8, 8.3,
  8.4), the DAO fallback key set and `minTotalStake` (4.3), the rules schedule (10.1) and Inbox
  slots 258–293 (appendix B).
- `iface/IUnzenProposeCutoff.sol`: the `proposeCutoff()` getter the upgraded Unzen Inbox
  (`layer1/core/impl/InboxWithEtnaCutoffs.sol`) exposes and `setOrigin` reads.
- `impl/EtnaInboxBootstrap.sol`: the Inbox proxy's first implementation; it only sets the owner, so
  the proxy address exists before the L2 `EtnaStaking` that fixes it (10 step 1).
- `libs/LibEtnaForcedInclusion.sol`: the forced inclusion queue storage and fee (7.1).

L2 and shared, under `contracts/`:

- `layer2/etna/iface/IEtnaStaking.sol`, `layer2/etna/EtnaStaking.sol`: bonds, seats, the
  block-start call `onBlockStart`, double-sign slashing and DAO forfeiture (4.1, 4.2, 4.4) and the
  staking storage of appendix B. The interface has no imports, so clients can copy it.
- `layer2/etna/EtnaStakingDeployer.sol`: a constructor-only contract whose creation through a CREATE2
  factory deploys the `EtnaStaking` implementation and its initialized proxy in one transaction (10
  step 1).
- `layer2/etna/libs/LibCometVote.sol`: `chainDomain`, the 48-byte CometBFT `chain_id` and the
  CometBFT v0.40.0 vote sign bytes that double-sign evidence is checked against (3.1, 4.1,
  appendix A).
- `shared/signal/EtnaSignalService.sol`: the root-only SignalService that L1 and L2 share (see
  [Anchorless L2 contracts](#anchorless-l2-contracts)).
- `shared/etna/LibEtnaKeys.sol`: 33-byte secp256k1 key decompression, `ckAddr` and 65-byte low-s
  signature recovery, for staking registration and double-sign checks and for the Inbox's fallback
  key checks (4.1, 4.3, appendix A).

## EtnaInbox

- The Etna start S is block 0 on a new network and the last Unzen block on a network that switches
  from Unzen ([SWITCH.md][switch]). The immutables `unzenInbox`, `etnaForkTime` and
  `originMultisig` are all zero on a new network and all non-zero on a switching one; the
  constructor rejects a mix and an Unzen Inbox without code. `originMultisig` is the designated
  multisig that alone may call `setOrigin`; the config hash does not commit it, so a new Inbox
  implementation can replace it before the start write. The immutables `etnaStaking`, the
  non-zero L2 `EtnaStaking` proxy, and `unsettledLimit`, U in [1, 262,144], are the config hash's
  third and fourth words, with views of the same names.
- `init(params)`: owner only, sent through `upgradeToAndCall` from the bootstrap implementation. It
  checks every spec 10 deployment constraint it can see (`forcedInclusionDelay` in [1, 2^48),
  `maxAnchorAge` in [1152, 2^48), the block number and timestamp below 2^48) and rejects dirty
  finite initial fields and generation-0/1 origin records. It checks the initial fallback key list
  as `setFallbackKeys` does, stores it and emits `FallbackKeysUpdated`, then stores `minTotalStake`,
  any value, and emits `MinTotalStakeUpdated`. It writes the config hash, keccak256 of the four
  words `bytes32("ETNA_CONFIG_V1")`, the L2 chain id, `etnaStaking` and U (appendix A), and emits
  `EtnaInitialized(configHash, etnaStaking, U)`. This is no proof that every historic mapping key is
  empty; bootstrap creation and privileged upgrade history must also be checked. On a new network
  it also performs the start write with S = 0 and the genesis hash and state root and saves the
  block-0 SignalService checkpoint; on a switching network both must be zero and it writes no start.
- `setOrigin(S)`: on a switching network only `originMultisig` writes the start, once, following
  the spec's reference body. It checks the caller first (`NotOriginMultisig`), then an initialized
  Inbox with slot 273 zero, 0 < S, `block.timestamp >= etnaForkTime`, the live Unzen Inbox's
  `proposeCutoff()` non-zero and reached, its `getCoreState()` showing every proposal finalized
  (`nextProposalId == lastFinalizedProposalId + 1`) with a non-zero `lastFinalizedBlockHash`
  (`UnzenTipHashZero`), and an L1 SignalService checkpoint at S with a non-zero state root. A
  failing check or read reverts. The multisig is trusted only to supply S, the height of Unzen's
  finalized tip: the start write takes the hash from `lastFinalizedBlockHash` and the state root
  from the checkpoint at S, whose hash field the root-only SignalService returns as zero. Nothing
  on L1 ties the two to one height, so a wrong checkpointed S passes the one-time write; nodes and
  guests then reject the mismatch and Etna halts. The write sets slots 272–274 (L1_0 = its own
  block), generation 0's origin (S, L1_0, its timestamp and the fallback key hash of slot 278), the
  checkpoint (S, hash) and S's landing record, emits `StartWritten`, closes the forwarder and opens
  the forced inclusion queue. It leaves the checkpoint at S untouched, and nothing rewrites the
  start afterwards.
- `saveCheckpoint(checkpoint)`: on a switching network, forwards the Unzen Inbox's checkpoints to the
  L1 SignalService, which accepts checkpoints only from this Inbox. Only `unzenInbox` may call it;
  it accepts any height while slot 273 is zero and reverts at every height once it is nonzero
  (`ForwardingClosed`). It passes the checkpoint unchanged and ignores pause and initialization, so
  it reverts only for these checks and the SignalService's own.
- `etnaStart()`: (S, start hash), or (0, 0) before the start write. `generationStartHeight()` and
  `origins(generation)` read the slot 290 records; `generationStartHeight()` reverts with
  `StartNotWritten` before the start write, since no record exists yet (spec 8.4).
- `land(input, leaves, proof)`: the spec 6.1 reference Solidity, check for check. Before the start
  write no landing passes, because `landings[0]` is unwritten. p, c and h are any heights with p ≤ c
  < h and h − p ≤ `maxBatchBlocks`; `leaves` are the h − p − 1 cut leaves of the heights p + 1, ...,
  h − 1, one per height; and if c > p the leaf at c is compared with c's slot 285 record, all before
  the immutable verifier checks the 19-word statement with `verifyProof(0, statement, proof)` (0: no
  proposal age applies). The reference's `isValidLanding(p)` is the written-record check: these
  contracts have no verifier-failure rollback, so no written record is voided. A landing from S
  reads no Unzen state: `setOrigin` already authenticated the tip. The landing then moves the
  checkpoint and the queue head, writes `landings[h]` with the actual parent c, saves the
  SignalService checkpoint and emits `Landed(p, c, h, cutHash, version)`. It pays nothing to anyone.
- `saveForcedInclusion(tx)`: after the start write, at most 8,192 bytes, for
  `fee × (threshold + pending) / threshold` Gwei, which stays in the Inbox; overpayment is refunded.
  An entry stores only the transaction hash, the L1 timestamp and the L1 block.
- `sweepProtocolFees()`: anyone sends the Inbox's whole balance to the immutable
  `protocolFeeRecipient`, the DAO treasury.
- `recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, fiToClear, rules)`:
  owner only after the start write, with all expected values matching current state,
  `block.timestamp <= validUntil` and a zero `rules` or one equal to `nextRules + 1`. Recovery
  increments the uint256 authorization nonce. With R = `block.number`, each listed queue entry's
  hash becomes `keccak256("")`, the generation increments and its origin (c, R's number, R's
  timestamp and the current slot 278) is written once to slot 290 (`OriginAlreadyWritten` if that
  record exists), and `Recovered` reports the new generation, c, R's number and timestamp, that
  fallback key hash and the blanked indices. It then clears the planned stop and, for a non-zero
  `rules`, sets `activeRules = nextRules = rules` and `rulesTime = 0`. The checkpoint, its record and
  the queue head are kept. The new generation's first two blocks are signed by the fallback keys its
  origin holds, so a recovery that must start on another key set sends `setFallbackKeys` first, in
  the same DAO batch.
- `setFallbackKeys(keys)` and `setMinTotalStake(value)`: owner only after initialization, with no
  generation argument and no lead time. `setFallbackKeys` requires 1 to 128 keys, each a valid
  compressed public key, in strictly ascending order of the 33-byte value `ckPrefix ‖ ckX`, prefix
  first, so every key with prefix 0x02 comes before every key with prefix 0x03, whatever their X.
  It stores the list and, in slot 278,
  `keccak256(abi.encode(bytes32("ETNA_FALLBACK_KEYS_V1"), keys))`, and emits `FallbackKeysUpdated`.
  `setMinTotalStake` stores any uint256 in slot 279 and emits `MinTotalStakeUpdated`; 2^256 − 1
  hands every block to the fallback key set. Origin records already written keep the hash they
  hold. `getFallbackKeys()`, `fallbackKeysHash()` and `minTotalStake()` read them back.
- `scheduleRules(expectedGeneration, rules, time)` and `scheduleStop(expectedGeneration, time)`:
  owner only after initialization; they first require `expectedGeneration == recoveryGeneration`
  (`GenerationMismatch`), so a queued authorization cannot change or cancel the schedule once a
  recovery started another generation, then write the rules schedule in slot 293 exactly as spec
  10.1 describes, with `maxAnchorAge` as the deadline. A due `nextRules` is promoted first; a failed
  call keeps nothing. `recover` and both calls emit `RulesScheduleUpdated` with the new slot 293
  word.
- `invalidateRecoveryNonce(expectedRecoveryNonce)`: owner only after initialization; checks and
  increments the nonce without wrapping, invalidating all unexecuted authorizations carrying it.
  Landing does not consume the nonce. A future verifier-failure rollback upgrade must preserve and
  increment its current value, so restoring an old checkpoint cannot revive authorization.

`land`, `recover`, `invalidateRecoveryNonce`, `setOrigin`, `scheduleRules`, `scheduleStop`,
`setFallbackKeys`, `setMinTotalStake`, `saveForcedInclusion` and `sweepProtocolFees` share one
reentrancy lock. Pause affects none of the Inbox's entry points (spec 1 requires this for `land` and
`saveForcedInclusion`). Only `saveForcedInclusion` accepts ETH; `upgradeToAndCall` rejects it too.
If a landing changes `c` after recovery is authorized, recheck the recovery conditions and seek
fresh authorization for the current tuple. Maintain an accepted proof combination covering the
required rulesets throughout.

## EtnaStaking

`EtnaStaking` is an upgradeable L2 proxy whose owner is the DAO's execution address on L2. Its stake
is bridged TAIKO, the immutable `token`. Every parameter is an immutable that the constructor
checks: the L1 chain id and `inbox`, the Etna Inbox proxy, which the double-sign chain domain binds;
`vpUnit` at least 867,361,738 and `minStake` at least `vpUnit` with `minStake × nMax` ≥ 10^27,
TAIKO's fixed supply; `nMax` in [1, 128]; 1 ≤ `missLimit` ≤ `missReleaseLimit` ≤ 65,535;
`missSlashBps` and `forfeitBps` in [1, 10,000]; `slashBountyBps` below 10,000; `withdrawalDelay` in
[1, 2^48) L2 blocks; and a non-zero `slashSink` other than `token` (`SlashSinkIsToken`), since a
bridged token may refuse transfers to its own address, which would make every slash, forfeiture and
penalty revert.

- Seats: a bond can hold one of the `nMax` seats only while it is issued, unwithdrawn, has no exit
  and has effStake ≥ `minStake`. It takes the lowest empty seat at registration and in a top-up that
  leaves a seatless bond meeting these conditions, reverting `NoEmptySeat` if every seat is held,
  and no other call gives it one. It releases the seat in the call that ends one of the conditions,
  and in the block-start call in which its seat's miss count reaches `missReleaseLimit`; such a bond
  still meets every condition but holds no seat until its owner's next top-up. It never moves
  another bond, and taking or releasing a seat resets the seat's miss count. The key-to-seat
  mapping, the seat table and the lookups `seatOfBond` and `bondInSeat` are live: every call that
  takes or releases a seat updates them in that call.
- `register(publicKey, amount, popSig)`: a 33-byte compressed consensus key with a proof of
  possession over the EIP-712 `Register(address owner)` digest (name `EtnaStaking`, version 1, the
  L2 chain id and the proxy) for the caller, who becomes the owner for life. Each key registers
  once, ever. Each registration issues the next bond id (from 0, never reused), with effStake =
  `amount` ≥ `minStake`, and takes a seat in the same call. A call naming an unissued id reverts
  `UnknownBond` without writing anything.
- `topUp` adds stake to effStake at once and re-seats a seatless bond that it leaves at `minStake`
  or more, whatever it adds, so a bond released at `missReleaseLimit` takes a seat again with one
  base unit; `requestExit` sets the exit at the current block and releases the seat;
  `withdraw(bondId, to)` pays the whole effStake after `withdrawalDelay` L2 blocks from the exit,
  and anyone may withdraw a bond whose balance is zero, which pays nothing.
- `slashDoubleSign(bondId, voteA, voteB)`: anyone, with two votes of the same type, height, round
  and generation, at most the generation `onBlockStart` last stored, and different block ids, both
  signed by the bond's key under `chainDomain(l1ChainId, block.chainid, inbox, generation)`: the L1
  chain id comes first and the L2 chain id is the chain's own. It takes the whole effStake, pays
  `floor(slashed × slashBountyBps / 10000)` to the caller and the rest to `slashSink`, sets the exit
  to at most the current block and releases the seat. A vote hash is `bytes` of length 0 or 32: an
  empty hash and a present all-zero hash have different sign bytes, as in stock CometBFT.
- `forfeit(bondId, incidentId, validUntil)`: owner only, once per bond id, until `validUntil` (an L2
  timestamp). It deducts `ceil(effStake × forfeitBps / 10000)` for `slashSink`, sets the lifetime
  flag and the exit at most the current block, and releases the seat.
- `onBlockStart(generation, missBitmap)`: only the system caller
  `0xfffffffffffffffffffffffffffffffffffffffe`, from which the EL calls it at the start of every
  Etna block, before the first transaction, with both values from the block's own `extraData` and
  30,000,000 gas for its frame. It stores the generation, raises the miss count of each occupied
  seat whose bit is set and resets the others, penalizes each seat whose count is a positive
  multiple of `missLimit` by `ceil(effStake × missSlashBps / 10000)` and leaves its count, then
  releases the seat of each bond that a penalty left below `minStake` or whose count reached
  `missReleaseLimit` (setting no exit, deducting nothing more and discarding the count, so no
  occupied seat's count reaches `missReleaseLimit` between calls), and writes the 128 snapshot seat
  records, `snapshotTotalStake` and `snapshotHeight` = the block number. Only this call writes the
  snapshot, so a stake change in block X reaches the snapshot at X + 1. It emits no events.
  `snapshot()` is a convenience view of the stored snapshot; nodes and guests read its storage
  words.
- The failure path: a call that reverts or runs out of its frame's gas, for example because the
  penalty transfer fails or a power does not fit 64 bits, changes nothing. The snapshot words, the
  128 records, the miss counts and the stored generation stay as they were, and the block stays
  valid. Its `snapshotHeight` then differs from the block number, so the fallback key set signs the
  block two heights above it.
- No entry point is affected by pause, `onBlockStart` included.
- On a new network both `EtnaStaking` and its token are genesis predeploys: the staking proxy at
  `getConstantAddress(chainId, 10003)` and its implementation at
  `getConstantAddress("0" + chainId, 10003)`, the bridged TAIKO proxy and implementation at
  `getConstantAddress(chainId, 7)` and `getConstantAddress("0" + chainId, 7)`. On chain 167001 these
  are `0x1670010000000000000000000000000000010003`, `0x0167001000000000000000000000000000010003`,
  `0x1670010000000000000000000000000000000007` and `0x0167001000000000000000000000000000000007`.
  The EL, the nodes and both guests build in the staking proxy address for the L2 chain id, and the
  Inbox's config hash commits it. A switching network deploys `EtnaStaking` with `DeployEtnaStaking`
  instead (below).
- The bridged TAIKO predeploy is `BridgedTaikoToken`, which the L2 ERC20Vault maps to the L1 TAIKO
  token given to the genesis builder. Its `canonical()` is a constant that reports mainnet TAIKO
  (`0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` on chain 1) on every chain, devnets included; on a
  devnet, read the ERC20Vault's mapping for the L1 token.
- A devnet genesis may premint bridged TAIKO to test stakers. That TAIKO is unbacked, since no L1
  TAIKO is locked for it, and the staking contract counts it at face value. The generator writes a
  premint only with `etna.devnet` set, refuses that flag on chains 167000, 167009 and 167013, and
  caps the premint at TAIKO's 10^27 supply.

## Choices the spec leaves open

- The Inbox proxy starts on `EtnaInboxBootstrap`, so its address exists before the `EtnaStaking`
  that fixes it. The owner then calls `upgradeToAndCall(EtnaInbox, init(...))`, and `init` also
  requires the owner. Slot 258 then reads 3.
- The stored fallback key list is a dynamic array at slot 275, which appendix B leaves unused, two
  words per key from keccak256(275). No anchor witness proves it, and clients do not read it as
  storage: they take the list from `FallbackKeysUpdated` or `getFallbackKeys()` and accept it only
  if its hash equals slot 278.
- The events: `FallbackKeysUpdated(bytes32 indexed fallbackKeysHash, FallbackKey[] keys)` and
  `MinTotalStakeUpdated(uint256 value)`, which `init` emits in that order, as the setters would;
  `Landed` carries `VERSION = 1`; `Recovered` carries the new generation, c, R's number and
  timestamp, the new origin's fallback key hash and the blanked indices.
- Both setters require initialization, take the Inbox lock, ignore pause and are nonpayable.
- U and the `EtnaStaking` address are Inbox immutables with views, so `init` computes the config
  hash from them instead of taking it as an input, and a value outside the spec bounds cannot be
  stored.
- `init` reads no reserved slot, so it does not check that slot 284, the old committee snapshot, is
  zero; the tests show that the Inbox never writes it.
- The first three fields of a slot 290 origin record are each below 2^48.
- `onBlockStart` adds up the penalties of one call and sends them to `slashSink` in one transfer,
  made last. A failing transfer reverts the whole call, which is the spec's failure path.
- `withdrawalDelay ≥ U + 2 + the evidence window` is a deployment bound that no contract checks,
  since no single contract sees both U and the delay: `DeployEtnaStaking`, the readiness builder and
  the genesis generator and builder check it, from U and an explicit evidence window in L2 blocks.
- Evidence votes have type 1 or 2, a height in [1, 2^63), a round below 2^31 and a 65-byte low-s
  signature with V in {0, 1}. Their timestamp seconds are an int64 and their nanoseconds an int32,
  each with any value and no range check, so double-sign evidence is accepted even at a timestamp
  stock CometBFT would not sign.
- The staking storage that appendix B does not name (bond records, the key-to-bond lookup, the bond
  count, the seat table, the miss counts, the occupancy bitmap, the last generation and the
  forfeiture flags) follows the named words in the same namespace.
- `maxBatchBlocks` is in [1, 12,952]. A landing of B blocks carries B − 1 leaves, and 12,952 is the
  largest B whose calldata, with a 4 KiB proof and every byte priced at today's EIP-7623 floor of 40
  gas, fits EIP-7825's 2^24 per-transaction gas cap. The cap is an immutable while the calldata
  price is not: a higher floor fits fewer blocks, so leave headroom; a landing of one block carries
  no leaves and always fits.

`LandInput` has seven fields and carries no validator-state hash or committee snapshot. The verifier
statement is 19 static words (608 bytes) with the config hash ninth; a cut leaf binds four words,
the height, EL hash, Comet hash and FI cursor, and the leaf at c, the latest checkpoint height, is
checked against c's slot 285 record. L1 never decodes the statement's preimage.

## Storage

- Inbox: appendix B exactly. The named slots are 258, 268–274, 278–282, 285, 290, 292 and 293;
  reserved slots 283, 284, 286–289 and 291 are never read or written, slot 275 holds the fallback
  key list, and slots 251–257, 259–267, 276 and 277 are unused padding. Each slot-285 mapping value
  has three words: the packed parent/generation/head, the EL hash and the Comet hash. The record's
  `head` is the forced-inclusion cursor at that height (the spec's "FI cursor"); the Inbox queue
  head (slot 281) equals it once that height is the checkpoint. Each slot-290 origin has four words:
  the start height, the L1 block, its timestamp and the fallback key hash.
- EtnaStaking: the ERC-7201 namespace `taiko.etna.staking` with base T =
  `0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00`. Nodes and guests read only
  `snapshotHeight`, the whole word at T; `snapshotTotalStake` at T + 1; the key-to-seat mapping at
  T + 2, whose element for a key is at `keccak256(abi.encode(ckAddr, T + 2))` and packs [holdsSeat,
  seat]; and the 128 snapshot seat records, record s at T + 3 + 2s (`ckX`) and T + 4 + 2s
  ([ckPrefix, power]) whatever `nMax` is. On a switching network they also check the proxy's
  EIP-1967 implementation slot at S. The rest of the namespace, from T + 259 on, is the contract's
  own.
- Packed words lay out their fields from the least-significant bit. Every field of an Inbox packed
  word takes 48 bits. Of the `EtnaStaking` words above, the key-to-seat element packs `holdsSeat`
  and `seat` in 8 bits each and record word 2 packs `ckPrefix` in 8 bits and `power` in 64. A value
  too wide for one of these fields reverts. `EtnaStaking`'s own state, from T + 259 on, uses other
  widths.
- The machine-readable layout is the `layout` section of `testdata/etna_vectors/vectors.json` for
  the Inbox (every slot, mapping derivation and packing table) and its `staking_layout` section for
  `EtnaStaking`; `EtnaVectors.t.sol` and `EtnaStakingVectors.t.sol` check the contracts against
  them. `impl/EtnaInbox_Layout.sol` and `layer2/etna/EtnaStaking_Layout.sol` are generated by
  `pnpm layout:l1` and `pnpm layout:l2`.

## Deployment

### New network

`script/layer1/etna/DeployEtnaDevnet.s.sol` deploys a new network in the owner-initialized order: the
Inbox proxy on its bootstrap with the L1 `EtnaSignalService` (`usesBeaconRoots` false), then the L2
genesis with `EtnaStaking` fixing that proxy, then the owner's `upgradeToAndCall` with `init`. The
Inbox has zero `unzenInbox`, `etnaForkTime` and `originMultisig`; its NatSpec lists every
environment variable. Run from `packages/protocol`:

```bash
export FOUNDRY_PROFILE=layer1 S=script/layer1/etna/DeployEtnaDevnet.s.sol:DeployEtnaDevnet
# REMOTE_SIGNAL_SERVICE is the L2 SignalService predeploy, which must be the generator's address
# for L2_CHAIN_ID; L1_CHAIN_ID must be this L1. Export INBOX_PROXY and SIGNAL_SERVICE.
forge script $S --sig 'deployInboxProxy()' --rpc-url "$L1_RPC" --broadcast
# Build the L2 genesis (below) and compute block 0's hash and state root with the EL. Export
# ETNA_STAKING, the generator's EtnaStaking proxy for L2_CHAIN_ID, the fallback keys and
# minTotalStake, and ETNA_UNSETTLED_LIMIT, the U the genesis used.
forge script $S --sig 'deployInbox()' --rpc-url "$L1_RPC" --broadcast
```

The L2 genesis of a new network needs the Etna L2 predeploys. Start from
`test/genesis/data/genesis_config_etna.js`, the example for chain 167001: set `chainId` to the L2
chain id, `l1ChainId`, `usesBeaconRoots` to `true` (an `etna` block makes the L2 SignalService the
`EtnaSignalService`; every block after genesis is an Etna block with a nonzero EIP-4788 root, so it
then accepts no checkpoint; the golden touch key is public, and `false` would keep the checkpoint
store open and never read EIP-4788),
`remoteSignalService` to SIGNAL_SERVICE, and the `etna` block. It holds INBOX_PROXY as `inbox`, the
L1 TAIKO token as `l1TaikoToken`, the staking owner (the DAO's execution address on L2), the slash
sink, every staking parameter as a decimal string, `unsettledLimit` (U) and `evidenceWindowBlocks`.
The example uses the reference values `minStake` 7,812,500 TAIKO (7,812,500 × 10^18 base units, the
least value with which 128 seats cover TAIKO's 10^27 supply), `vpUnit` 10^9 and `nMax` 128,
`slashBountyBps` and `forfeitBps` 1,000, U 151,200, a 151,200-block evidence window and
`withdrawalDelay` 302,402 L2 blocks, U + 2 + the window. Its `missLimit` 3,600, `missSlashBps` 1,000
and `missReleaseLimit` 10,800, which the shared vectors also use, are not the specification's
references, 21,600 (about one day at 4 s blocks), 100 and 64,800 (about three days);
`DeployEtnaStaking` defaults to those. The generator refuses a `withdrawalDelay` below
`unsettledLimit + 2 + evidenceWindowBlocks` and everything the `EtnaStaking` constructor would
refuse. Then run `GENESIS_CONFIG=<config> pnpm genesis:gen` and build the genesis from the base
JSON:

```bash
python3 script/layer2/build_etna_genesis.py --base <genesis.json> \
  --predeploys test/genesis/data/genesis_alloc.json \
  --predeploy-config test/genesis/data/genesis_config.json \
  --l1-signal-service "$SIGNAL_SERVICE" --l1-inbox "$INBOX_PROXY" \
  --l1-taiko-token "$L1_TAIKO_TOKEN" --output <file>
```

The builder refuses a `usesBeaconRoots` other than JSON `true`, a `remoteSignalService` other than
SIGNAL_SERVICE, another chain id and predeploys without the Anchor, SignalService, `EtnaStaking`,
bridged TAIKO or ERC20Vault. Because the checked-in `genesis_config.json` can disagree with a
gitignored `genesis_alloc.json`, it checks the same values in the emitted bytecode too, against the
`out/layer2` artifacts of the same `pnpm genesis:gen` run (`--artifacts` overrides the directory):
every proxy account must hold exactly the compiled `ERC1967Proxy` runtime and point at its
implementation, whose code must be the compiled runtime differing only in immutables. The
SignalService implementation must be the `EtnaSignalService` with `usesBeaconRoots` true, its
syncer the Anchor proxy and its remote SIGNAL_SERVICE, and the Anchor's `checkpointStore` the
SignalService proxy. `EtnaStaking`'s immutables must pass its constructor's checks and the
withdrawal bound, its `inbox` must be
`--l1-inbox` and its `token` the bridged TAIKO proxy; the token's `erc20Vault` must be the ERC20Vault
proxy, which must map it to `--l1-taiko-token` on `l1ChainId`. Every other immutable is pinned to the
generator's value, and an immutable the builder does not know is refused. The proxies may hold only
the storage the generator writes (deployment and `init`, and for the token the premint's balances,
total supply and votes checkpoint), so a seeded signal, checkpoint or bond is refused. Outside a
devnet the staking owner must hold code in the genesis. No root-path address nor an L1 address
passed to the builder may be a precompile or system contract address, and no L1 address may be an
L2 predeploy. If `out/layer2` no longer matches the alloc, for example after a rebuild from other
sources or without the AST, it refuses until `pnpm genesis:gen` reruns. It replaces the base's
accounts at the predeploy addresses with the generated ones, keeping only the account fields
execution clients accept, and adds the EIP-4788 and EIP-2935 system contracts (spec 10 step 2).
Outside `alloc` it only drops the base's derived `stateRoot`; the 100% base-fee share is the
per-block `extraData[0] = 100` rule that nodes and guests enforce, not a genesis field. It needs
Python 3.9 or later, writes `--output` only on success and removes an existing one first, so a
failed run leaves no genesis behind. `pnpm genesis:test` (CI's genesis job) runs it on real generator
output: the default alloc and a config edited without regenerating must fail, an alloc generated
from `genesis_config_etna.js` must pass, the generator must refuse an Etna configuration that breaks
a staking parameter rule or the devnet premint guard, and a node started from the Etna genesis runs
`TestGenerateEtnaGenesis`. `generate.ts` exits non-zero on failure, so a failed run cannot leave an
older config/alloc pair behind unnoticed. After booting the EL on the genesis, also check the
SignalService proxy (`contractAddresses.SignalService` in the generated config) and the
`EtnaStaking` proxy at block 0:

```bash
# Must print true.
cast call --rpc-url "$L2_RPC" --block 0 "$L2_SIGNAL_SERVICE" 'usesBeaconRoots()(bool)'
# Must print INBOX_PROXY.
cast call --rpc-url "$L2_RPC" --block 0 "$ETNA_STAKING" 'inbox()(address)'
```

`deployInbox()` deploys the `EtnaInbox` implementation over SIGNAL_SERVICE with ETNA_STAKING and U
(ETNA_UNSETTLED_LIMIT, 151,200 if unset, empty or zero), then upgrades and initializes the proxy
with the fallback keys (ETNA_FALLBACK_KEYS) and ETNA_MIN_TOTAL_STAKE if the deployer owns it, or
logs that call for the owner. Use the same U for the genesis and the Inbox: the config hash commits
it, and the withdrawal bound depends on it. No contract checks two spec 11 bounds. The tooling
checks that `withdrawalDelay` is at least U + 2 + the evidence window it is given, but the operator
must choose a window that covers getting a double-sign report included through forced inclusion and
detecting a bad landing and executing its rollback (suggested no less than seven days). The
operator must also set `MAX_ANCHOR_AGE` above the L1 finality delay. That delay is the age
the newest finalized L1 block reaches just before the next finalization while L1 finalizes on
schedule (three epochs, 1152 s, on Ethereum), plus the deployment's allowance for slots missed at an
epoch boundary and for nodes' delay in importing that finalization; `init` checks only the 1152 s
floor, and on Ethereum 1152 s itself is too low. So that proposers can keep an anchor until the
next multiple of 1,024 (CONS-3.3-4), a deployment also adds the time 1,024 blocks take (4,096 s at
4-second blocks), with an allowance for slower blocks and for a proposer that picks an earlier
finalized block (spec 11, PARAM-11-5); a value without this addition is valid, and anchors then move
sooner, when they age out. `forfeitBps` is an explicit deployment input in [1,
10,000], with no production default. The deployment manifest must also pin independent `C_CAP_MIN`
and a conservative per-TAIKO `P_REF` in the same currency, with its source, haircut, expiry, review
frequency and responsible owner, from which the DAO chooses `minTotalStake`. These are launch
acceptance checks, not a price oracle or a consensus or signing gate; see SPEC 4.3, 4.4 and 11 and
ACCEPTANCE 4.

### Switching network

On a network that switches from Unzen, `script/layer2/etna/DeployEtnaStaking.s.sol` deploys
`EtnaStaking` on L2 before `ETNA_FORK_TIME`, in one transaction to the CREATE2 factory: it creates
an `EtnaStakingDeployer`, whose constructor creates the implementation and the proxy and initializes
the proxy with CONTRACT_OWNER, the DAO's execution address on L2, so no one else can initialize it.
`predict` gives the three addresses in advance. The EL, the nodes and both guests build in the proxy
and implementation addresses, so take them from the build that is released: any byte change to
`EtnaStakingDeployer`, `EtnaStaking` or `ERC1967Proxy`, metadata included, moves both. The script
reads the configuration through `LibEtnaStakingEnv`, defaults `minStake` to 7,812,500 TAIKO and
refuses a `withdrawalDelay` below U + 2 + EVIDENCE_WINDOW_BLOCKS.
[The switch scripts](#switching-from-unzen) list its inputs and the readiness builder's checks of
the deployment.

## Anchorless L2 contracts

These implement [ANCHORLESS.md][anchorless] sections 4 and 8.

- `shared/signal/EtnaSignalService.sol`: one implementation for L1 and L2, extending
  `SignalService` through its checkpoint hooks, with one syncer each and the immutable
  `usesBeaconRoots`, false on L1 and true on L2. It stores only the counterpart chain's state root
  per checkpoint height, writing the state-root word of the `VERSION` 1 record and leaving the old
  hash word in place; `getCheckpoint` returns a zero hash, also for records written before the
  upgrade, `CheckpointSaved` still emits the caller's hash, and `getStateRoot(uint64)` returns the
  root a proof would be checked against. `SignalService` itself keeps the Unzen behaviour for the
  networks that do not switch. No contract holds the Etna fork time.
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
  `EtnaSignalService` implementation and `usesBeaconRoots()` true. Each check reverts rather than
  returning false, because the `DelegateController` checks only call success.
- `script/layer2/DeployShastaL2Contracts.s.sol` (with the mainnet and Hoodi entry points) deploys,
  without upgrading the proxy, the switching L2 `EtnaSignalService` implementation (syncer the
  `Anchor` proxy, `usesBeaconRoots` true, the existing pauser) and the guard. It takes no fork time.
- `script/layer2/etna/BuildEtnaReadinessL2Message.s.sol`: `LibEtnaReadinessL2Message.buildActions`
  returns `[guard.checkBeforeUpgrade, signalService.upgradeTo(etnaImpl), guard.checkAfterUpgrade]`.
  There is no deadline or fork time; use execution ID 0. A failed check reverts the batch and leaves
  the message retriable with the proxy unchanged.

## Tests

Run from `packages/protocol`:

```bash
pnpm test:l1 --match-contract 'Etna'
FOUNDRY_INVARIANT_RUNS=256 pnpm test:l1 --match-contract 'Etna.*Invariant'
pnpm test:l2 --match-contract 'Etna|LibCometVote|DeployShastaL2Config'
FOUNDRY_INVARIANT_RUNS=256 pnpm test:l2 --match-contract 'EtnaStaking.*Invariant'
pnpm test:shared --match-contract 'SignalService|LibEtnaKeys'
FOUNDRY_PROFILE=layer1o forge build
python3 -m unittest discover -s test/layer2/core -p 'test_etna_genesis.py'
python3 -m unittest discover -s ../../testdata/etna_vectors -p 'test_vectors.py'
```

The gas suites write `snapshots/*.json` with `FORGE_SNAPSHOT_EMIT=true`, and `pnpm snapshot:l1`
writes `gas-reports/layer1-contracts.txt`. `EtnaStakingGas.t.sol` measures each staking transaction
with all 128 seats held and the block-start call with every seat penalized, released or both, which
must stay below the call's 30,000,000 gas; it records call-frame gas before refunds with the test
token `TestERC20`, not the production `BridgedTaikoToken`. It also checks that the `EtnaStaking`
implementation fits EIP-170. `EtnaInboxGas.t.sol` measures the Inbox's entry points; the recovery
that sets 128 fallback keys and `init` with 128 keys must fit EIP-7825's 2^24 with `DAO_PATH_EXTRA`
(7,250,000) added for the DAO path.

The DAO path tests skip without an L1 archive RPC and run only by hand. With one, they send the
recovery that sets 128 fallback keys through the live Aragon DAO, its optimistic token voting plugin
and the Standard and Emergency Multisigs on a mainnet fork, require each transaction to fit 2^24
and require each step to add at most `DAO_PATH_EXTRA` to the controller-only transaction. Re-run
them when the recovery payload, the fork block or the DAO stack changes:

```bash
L1_FORK_URL=<l1 archive rpc> FOUNDRY_PROFILE=layer1 \
  forge test --match-path test/layer1/etna/EtnaRecoveryDaoPathGas.t.sol -vv
```

`testdata/etna_vectors/README.md` explains how to regenerate the vectors.

## Switching from Unzen

[The switch preparation scripts](../../../script/layer1/etna/README.md) retain the existing L1
SignalService and deploy the Etna bootstrap, `EtnaStaking` on L2, dedicated verifier instances and
replacement implementations without upgrading live proxies, and emit the action lists of the
readiness and scheduling proposals and of a postponement, around reverting guard calls (SWITCH.md
sections 3 and 7). `InboxWithEtnaCutoffs` preserves Unzen's configuration and storage while applying
immutable proposal and FI cutoffs and exposes `proposeCutoff()`, the timestamp from which its
`propose` reverts; its `signalService` names the Etna Inbox proxy, so Unzen `prove` saves its
checkpoints through `EtnaInbox.saveCheckpoint` until the start write closes it. The L1 SignalService
upgrade is the `EtnaSignalService` with the Etna Inbox as its only syncer and `usesBeaconRoots`
false, keeping VERSION=1 and the shared signal/checkpoint storage, so the Unzen roots stay readable.
Before either root-only upgrade, the readiness proposal registers Unzen SGX, RISC0 and SP1 images
that take the inherited checkpoint from the parent block's anchor transaction. `setOrigin` reads the
real six-word Unzen CoreState ABI, and the scheduling batch's final guard check pins the EtnaInbox's
`originMultisig`.

## Out of scope

- The verifier-failure rollback (spec 8); it comes with the Inbox upgrade replacing the verifier,
  in one DAO upgrade that also upgrades the L1 SignalService and the L1 Bridge. After it no voided
  checkpoint can be read through the SignalService or proven against, while every other checkpoint
  stays usable, and every signal the SignalService cached, and every Bridge message left
  `RETRIABLE`, at or after the L1 block of the first bad landing is unusable until it is proven
  again against a checkpoint the SignalService holds after the rollback.
- DAO proposal submission: the scripts emit the actions and the guards revert on chain, but
  assembling, authorizing and executing the proposals is governance tooling.
- Snapshot verification and checkpoint import are client work. Missing-data retry rules, R₀
  finality and the checks of S's timestamp and L2 SignalService implementation (SYNC-9-5a,
  PROOF-6.2-46a) belong to clients and guests; the contract enforces its observable gates. Switch
  deployment rehearsal remains outstanding.
- Real proving guests. Tests use mock verifiers, so they show contract behaviour, not proof
  soundness; production needs a verifier that requires two proofs, at least one ZK (6.2).

The Inbox, the L1 SignalService, the L1 Bridge and the L2 `EtnaStaking` are upgradeable proxies
whose owner should be the DAO (on L2, its execution address) behind a timelock; an upgrade can
bypass any rule here (spec 1).

[spec]: https://github.com/taikoxyz/taiko-mono/blob/797a708e57badb02dc4e974dcaf9167232aa2969/packages/protocol/docs/etna/SPEC.md
[switch]: https://github.com/taikoxyz/taiko-mono/blob/797a708e57badb02dc4e974dcaf9167232aa2969/packages/protocol/docs/etna/SWITCH.md
[anchorless]: https://github.com/taikoxyz/taiko-mono/blob/797a708e57badb02dc4e974dcaf9167232aa2969/packages/protocol/docs/etna/ANCHORLESS.md
