# Etna contracts

Etna is a proof-of-stake validity rollup. A committee of TAIKO stakers orders and finalizes L2
blocks with stock CometBFT, anyone can land a proven batch on L1, and L1 recognizes only landed
checkpoints. These are its L1 contracts. Section numbers refer to the
[Etna PoS + ZK design specification](../../../docs/etna/SPEC.md); appendix A is its
encodings and appendix B its L1 storage layout.

## Contracts

- `iface/IEtnaInbox.sol`, `impl/EtnaInbox.sol`: `init` and the Etna start write (spec 10 steps
  5-5b), `land` (6.1), the forced inclusion queue and the protocol fee sweep (7.1), governance
  `recover` (8, 8.3, 8.4), the rules schedule (10.1) and Inbox slots 258–293 (appendix B).
- `impl/EtnaInboxBootstrap.sol`: the Inbox proxy's first implementation; it only sets the owner,
  so the proxy address exists before the registry that fixes it (10 step 1), and reports no
  Etna start, so the L1 SignalService can read it at any time.
- `iface/IEtnaStakingRegistry.sol`, `impl/EtnaStakingRegistry.sol`: registration and admission
  by displacement, exits, withdrawals, double-sign slashing, recovery's forced exits and
  per-block checkpoints (4.1).
- `libs/LibEntriesTree.sol`: `regLeaf` and `entriesRoot` (appendix A) as an incremental Merkle
  tree of depth 12, one leaf per slot.
- `libs/LibEtnaKeys.sol`: 33-byte secp256k1 key decompression, `ckAddr`, `entryKey` and 65-byte
  low-s signature checks (4.1, appendix A).
- `libs/LibCometVote.sol`: `chainDomain`, the 48-byte CometBFT `chain_id` and the CometBFT
  v0.40.0 vote sign bytes that double-sign evidence is checked against (3.1, 4.1, appendix A).
- `libs/LibEtnaForcedInclusion.sol`: the forced inclusion queue storage and fee (7.1).

## EtnaInbox

- The Etna start S is block 0 on a new network and the last Unzen block on a network that switches
  from Unzen ([SWITCH.md](../../../docs/etna/SWITCH.md)). The immutables `originWriter`,
  `unzenInbox` and `etnaForkTime` are all zero on a new network and all non-zero on a switching
  one; the constructor rejects a mix and an Unzen Inbox without code.
- `init`: owner only, sent through `upgradeToAndCall` from the bootstrap implementation. It checks
  every spec 10 deployment constraint it can see, checks that the registry's fixed Inbox is this
  proxy and that both use the same L2 chain id, and writes the appendix B initial values. On a
  new network it also performs the start write with S = 0 and the genesis hash and state root and
  saves the block-0 SignalService checkpoint; on a switching network both must be zero and it
  writes no start.
- `setOrigin(S, hash, stateRoot)`: the originWriter's start write on a switching network, once,
  from `etnaForkTime` on, with 0 < S < 2^48 and a non-zero hash and state root. It writes slots
  272–274 (L1_0 = its own block), generation 0's origin, the checkpoint (S, hash) and S's landing
  record, emits `StartWritten` and opens the forced inclusion queue. It writes no SignalService
  checkpoint: the one at S is the Unzen Inbox's.
- `etnaStart()`: (S, start hash), or (0, 0) before the start write; never reverts. The L1
  SignalService reads it to reject Unzen Inbox checkpoints above S.
- `land(input, leaves, proof)`: the spec 6.1 reference Solidity, check for check. Before the start
  write no landing passes, because `landings[0]` is unwritten. With K = 6, p, c and h are grid
  points counted from S; `leaves` are the cut leaves at the grid points inside (p, h), and if c > p
  the leaf at c is compared with c's slot 285 record before the immutable verifier checks the
  21-word statement with `verifyProof(0, statement, proof)` (0: no proposal age applies). On a
  switching network, while c is S, the landing first requires that the Unzen Inbox has finalized
  every proposal up to the start's hash and that the SignalService checkpoint at S holds that hash
  and the start's state root.
  The landing then moves the checkpoint, `activeCommitteeSnapshot` and the queue head, writes
  `landings[h]` with the actual parent c, saves the SignalService checkpoint and emits `Landed`.
  It pays nothing to anyone.
- `saveForcedInclusion(tx)`: after the start write, at most 8,192 bytes, for
  `fee × (threshold + pending) / threshold` Gwei, which stays in the Inbox; overpayment is
  refunded. An entry stores only the transaction hash, the L1 timestamp and the L1 block.
- `sweepProtocolFees()`: anyone sends the Inbox's whole balance to the immutable
  `protocolFeeRecipient`, the DAO treasury.
- `recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, exclusions, ...)`,
  whose last two arguments are `fiToClear` and `rules`: owner only after the start write, with all
  expected values matching current state, expectedC − S a multiple of K,
  `block.timestamp <= validUntil` and a non-zero `rules` equal to `nextRules + 1`. Recovery
  increments the uint256 authorization nonce. With R = `block.number`, each excluded entry's exit
  moves to min(existing, R) in the registry, each listed queue entry's hash becomes
  `keccak256("")`, the generation increments and its origin (c, R's number, R's timestamp) is
  written once to slot 290. It then clears the planned stop and, for a non-zero `rules`, sets
  `activeRules = nextRules = rules` and `rulesTime = 0`. The checkpoint, its record, the queue
  head and `activeCommitteeSnapshot` are kept.
- `scheduleRules(rules, time)` and `scheduleStop(time, grid)`: owner only after initialization;
  they write the rules schedule in slot 293 exactly as spec 10.1 steps 5a-5c, with `maxAnchorAge`
  as the deadline. A due `nextRules` is promoted first; a failed call keeps nothing. `recover`
  and both calls emit `RulesScheduleUpdated` with the new slot 293 word.
- `invalidateRecoveryNonce(expectedRecoveryNonce)`: owner only after initialization; checks and
  increments the nonce without wrapping, invalidating all unexecuted authorizations carrying it.
  Landing does not consume the nonce. A future verifier-failure rollback upgrade must preserve
  and increment its current value, so restoring an old checkpoint cannot revive authorization.

`land`, `recover`, `invalidateRecoveryNonce`, `setOrigin`, `scheduleRules`, `scheduleStop`,
`saveForcedInclusion` and `sweepProtocolFees` share one reentrancy lock and reject callbacks from
registry mutations.
Pause affects none of these entry points, nor the registry's (spec 1 requires this for `land`,
`saveForcedInclusion` and the registry). Only `saveForcedInclusion` accepts ETH;
`upgradeToAndCall` rejects it too.

## EtnaStakingRegistry

- `register(publicKey, amount, popSig)`: a 33-byte compressed consensus key with a proof of
  possession over the EIP-712 `Register(address owner)` digest for the caller, who becomes the
  owner for life. Each key registers once, ever. Each registration issues the next bond id
  (from 0, never reused) and takes the slot with the smallest value: 0 if empty, otherwise its
  bond's effective plus pending stake, ties going to the lowest slot. The stake must be at least
  `minStake` and above that value; a bond holding the slot is displaced (`BondDisplaced`): it
  leaves the slot, its exit becomes min(its exit, the current block), and it keeps everything
  else until it is confirmed and withdrawn. `bondForKey`, `bondInSlot` and `slotOfBond` return
  `(found, id)` pairs; `admissionThreshold` names the slot and value the next registration must
  beat; `bondAt` returns a bond's record whether or not it holds a slot.
- `requestExit`, `confirmExit`, `withdraw(bondId, to)`, `slashDoubleSign(bondId, voteA, voteB)`
  and the Inbox-only `forceExit` follow spec 4.1 and 8 step 2, whether or not the bond holds a
  slot; a call naming an unissued id reverts `UnknownBond`. Withdrawal zeros the bond's balance
  and keeps its key, activation and exit, and empties its slot if it holds one. Confirming an
  exit needs an initialized Inbox whose `activeCommitteeSnapshot` reaches the exit block;
  `slashDoubleSign` needs an initialized Inbox and accepts votes from the current or an earlier
  generation.
  Registry mutations revert while the Inbox holds its lock, except its authorized `forceExit`.
- `topUp(bondId, amount)`: the active entry's owner deposits one positive pending amount, even
  with all slots occupied or before Inbox initialization. It has no voting power or checkpoint
  effect. `activateTopUp(bondId)` is permissionless at readiness, after `activationDelay` L1
  blocks; activation writes the normal checkpoint and does not change historical committees.
  No deposit or activation is allowed after exit is set. Withdrawal and double-sign slashing
  account for **all** remaining effective and pending principal and clear the pending state.
- `forfeit(bondId, entryKey, incidentId, validUntil)`: registry owner only after initialization,
  once per lifetime entry key, with an inclusive timestamp deadline. Deducts
  `ceil((effStake + pendingTopUp) * forfeitBps / 10000)` from effective stake first, then pending
  funds, pays only `slashSink` and forces exit without resetting an existing confirmation clock.
  The flag survives withdrawal, displacement, recovery and verifier-failure rollback. There is no
  forfeiture nonce, revocation method, freeze or extra delay. Landing and recovery leave an
  unexecuted authorization usable until expiry; attribution and timely execution belong to DAO
  governance. Double-sign evidence can still take the remainder.
- `forceExit(bondId, entryKey)` derives the recovery execution block from `block.number` and
  checks `entryKey` against the bond's record, which a displaced or withdrawn bond keeps; a
  mismatch or an unissued id reverts the whole `recover`, and a displaced or withdrawn bond keeps
  its earlier exit (spec 8 step 2).
- Every L1 block that changes the entry in a slot ends with exactly one checkpoint
  (`l1Block`, `count`, `entriesRoot`); a change to a bond that holds no slot writes none. The
  Inbox proxy and the L2 chain id are immutables.

## Difference from the spec

- `init` takes `vp_unit`, `s_min`, `n_max` and `U` instead of the config hash (spec 10 step 5),
  checks their bounds and computes `committeeConfigHash` itself, so a configuration outside the
  spec bounds cannot be stored.

## Choices the spec leaves open

- The Inbox proxy starts on `EtnaInboxBootstrap`, so its address exists before the registry that
  fixes it. Once the registry exists, the owner calls `upgradeToAndCall(EtnaInbox, init(...))`,
  and `init` also requires the owner. Slot 258 then reads 3.
- `Landed` carries `VERSION = 1`; `Recovered` carries the new generation, c, R's number and
  timestamp, and both lists.
- Each field of a slot 290 origin is below 2^48.
- Evidence votes have type 1 or 2, a height in [1, 2^63), a round below 2^31, timestamp seconds
  read as an int64 within CometBFT's Timestamp range (negative values included), nanoseconds
  below 10^9 and a 65-byte low-s signature with V in {0, 1}.
- Registry storage that appendix B does not name (tree nodes, the admission index, the key and
  slot lookups, the bond records and the bond count) lives in the `taiko.etna.registry`
  namespace after `entries`, so nodes read only the two named slots.
- The admission index is a tournament tree over the 4,096 slots keyed by `value << 12 | slot`,
  so a slot's value (a bond's effective plus pending stake) must be below 2^244
  (`BalanceTooLarge`), far above TAIKO's supply. An update walks one leaf-to-root path and stops
  at the first unchanged node.
- `minStake` and `s_min` are independent; the deploy script defaults `minStake` to `s_min`.
- `activationDelay`, `exitDelay` and `withdrawalDelay` are each in [1, 2^32), so an oversized
  delay cannot make every registration or exit request revert.
- `maxBatchBlocks` is in [6, 65,532], with no multiple-of-6 rule. The upper end is the maximum U,
  and at that size the leaf calldata still fits one transaction's gas cap at today's EIP-7623
  calldata floor (spec 11).

## Storage

- Inbox: appendix B exactly. The named slots are 258, 268–274, 278–282, 284, 285, 290, 292 and 293;
  reserved slots 283, 286–289 and 291 are never read or written, and slots 251–257, 259–267 and
  275–277 are unused padding.
- Registry: the ERC-7201 namespace `taiko.etna.registry` with base R holds `checkpoints` at R
  and the slot-indexed `entries` at R + 1, the only slots nodes read, then the tree nodes, the
  admission index, the key and slot lookups, the bond records and the bond count. Bond owners
  and exit confirmations, keyed by bond id, live in the separate namespaces
  `taiko.etna.registry.owners` and `taiko.etna.registry.exit-confirmations`, outside
  `entriesRoot`.
- Pending deposits use `taiko.etna.registry.top-ups`, a bond-id mapping with a uint256 amount
  and a uint48 readiness block in the next word. Lifetime bool flags use an entry-key mapping
  in `taiko.etna.registry.forfeitures`. Neither enters the entries root or ordinary witnesses.
- Packed words in both contracts lay out their fields from the least-significant bit: `ckPrefix`
  takes 8 bits, every other field 48, and a wider value reverts.
- The machine-readable layout, with every slot, mapping derivation and packing table, is the
  `layout` section of `testdata/etna_vectors/vectors.json`; `EtnaVectors.t.sol` checks both
  contracts against it. `impl/*_Layout.sol` are generated by `pnpm layout:l1`.

## Deployment

`script/layer1/etna/DeployEtnaDevnet.s.sol` deploys a new network in the owner-initialized order
(the Inbox proxy on its bootstrap, the registry, then the owner's `upgradeToAndCall` with `init`),
with zero `originWriter`, `unzenInbox` and `etnaForkTime`; its NatSpec lists every environment
variable. Run from `packages/protocol`:

```bash
export FOUNDRY_PROFILE=layer1 S=script/layer1/etna/DeployEtnaDevnet.s.sol:DeployEtnaDevnet
forge script $S --sig 'deployInboxProxy()' --rpc-url "$L1_RPC" --broadcast # export INBOX_PROXY
forge script $S --sig 'deployRegistry()' --rpc-url "$L1_RPC" --broadcast # export STAKING_REGISTRY
# Validators register and activate; pick GENESIS_CUTOFF, compute committee 0's record hash,
# build the L2 genesis and compute block 0's hash and state root with the EL.
forge script $S --sig 'deployInbox()' --rpc-url "$L1_RPC" --broadcast
```

`deployInbox()` deploys the SignalService and the `EtnaInbox` implementation, then upgrades and
initializes the proxy if the deployer owns it, or logs that call for the owner. No contract
checks two spec 11 bounds, so the operator must: `REGISTRY_WITHDRAWAL_DELAY` no shorter than the
double-sign evidence window (suggested at least 50,400 L1 blocks, about 7 days) and
`MAX_ANCHOR_AGE` above the L1 finality delay.
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
`script/layer2/build_etna_genesis.py --base <genesis.json> --output <file>` adds the EIP-4788 and
EIP-2935 system contracts to the L2 genesis alloc (spec 10 step 3); the 100% base-fee share is
the per-block `extraData[0] = 100` rule that nodes and guests enforce, not a genesis field.

## Tests

Run from `packages/protocol`:

```bash
pnpm test:l1 --match-contract 'Etna|LibEntriesTree|LibEtnaKeys|LibCometVote'
FOUNDRY_INVARIANT_RUNS=256 pnpm test:l1 --match-contract 'Etna.*Invariant'
pnpm test:l2 --match-contract EtnaGenesisTest
python3 -m unittest discover -s test/layer2/core -p 'test_etna_genesis.py'
python3 -m unittest discover -s ../../testdata/etna_vectors -p 'test_vectors.py'
```

`testdata/etna_vectors/README.md` explains how to regenerate the vectors.

## Out of scope

- The verifier-failure rollback (spec 8); it comes with the Inbox upgrade replacing the verifier.
- The rest of the switch from Unzen: the start rewrite of spec 10 step 5c, which ships with the
  correcting Inbox upgrade, the L1 SignalService upgrade that accepts both Inboxes and rejects
  Unzen Inbox checkpoints above S, and the Unzen Inbox cutoffs (10 step 5d).
- Real proving guests. Tests use mock verifiers, so they show contract behaviour, not proof
  soundness; production needs a verifier that requires two proofs, at least one ZK (6.2).

The Inbox, the registry and the SignalService are upgradeable proxies whose owner should be the
DAO behind a timelock; an upgrade can bypass any rule here (spec 1).
