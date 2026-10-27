# Etna contracts

Etna is a proof-of-stake validity rollup. A committee of TAIKO stakers orders and finalizes L2
blocks with stock CometBFT, anyone can land a proven batch on L1, and L1 recognizes only landed
checkpoints. These are its L1 contracts. Section numbers refer to the Etna PoS + ZK design
specification; appendix A is its encodings and appendix B its L1 storage layout.

## Contracts

- `iface/IEtnaInbox.sol`, `impl/EtnaInbox.sol`: genesis `init` (spec 10 step 5), `land` (6.1),
  the forced inclusion queue and the protocol fee sweep (7.1), governance `recover` (8, 8.3, 8.4)
  and Inbox slots 258–291 (appendix B).
- `impl/EtnaInboxBootstrap.sol`: the Inbox proxy's first implementation; it only sets the owner,
  so the proxy address exists before the registry that fixes it (10 step 1).
- `iface/IEtnaStakingRegistry.sol`, `impl/EtnaStakingRegistry.sol`: registration, exits,
  withdrawals, double-sign slashing, recovery's forced exits and per-block checkpoints (4.1).
- `libs/LibEntriesTree.sol`: `regLeaf` and `entriesRoot` (appendix A) as an incremental Merkle
  tree of depth 12, one leaf per slot.
- `libs/LibEtnaKeys.sol`: 33-byte secp256k1 key decompression, `ckAddr`, `entryKey` and 65-byte
  low-s signature checks (4.1, appendix A).
- `libs/LibCometVote.sol`: `chainDomain`, the 48-byte CometBFT `chain_id` and the CometBFT
  v0.40.0 vote sign bytes that double-sign evidence is checked against (3.1, 4.1, appendix A).
- `libs/LibEtnaForcedInclusion.sol`: the forced inclusion queue storage and fee (7.1).

## EtnaInbox

- `init`: owner only, sent through `upgradeToAndCall` from the bootstrap implementation. It checks
  every spec 10 deployment constraint it can see, checks that the registry's fixed Inbox is this
  proxy and that both use the same L2 chain id, writes the appendix B initial values and saves
  the block-0 SignalService checkpoint.
- `land(input, leaves, proof)`: the spec 6.1 reference Solidity, check for check, plus an
  initialization check. With K = 6, p, c and h are grid points; `leaves` are the cut leaves at
  the grid points inside (p, h), and if c > p the leaf at c is compared with c's slot 285 record
  before the immutable verifier checks the 21-word statement with
  `verifyProof(0, statement, proof)` (0: no proposal age applies).
  The landing then moves the checkpoint, `activeCommitteeSnapshot` and the queue head, writes
  `landings[h]` with the actual parent c, saves the SignalService checkpoint and emits `Landed`.
  It pays nothing to anyone.
- `saveForcedInclusion(tx)`: at most 8,192 bytes, for `fee × (threshold + pending) / threshold`
  Gwei, which stays in the Inbox; overpayment is refunded. An entry stores only the transaction
  hash, the L1 timestamp and the L1 block.
- `sweepProtocolFees()`: anyone sends the Inbox's whole balance to the immutable
  `protocolFeeRecipient`, the DAO treasury.
- `recover(expectedGeneration, expectedC, exclusions, fiToClear)`: owner only and atomic. With
  R = `block.number`, each excluded entry's exit moves to min(existing, R) in the registry, each
  listed queue entry's hash becomes `keccak256("")`, the generation increments and its origin
  (c, R's number, R's timestamp) is written once to slot 290. The checkpoint, its record, the
  queue head and `activeCommitteeSnapshot` are kept.

`land`, `recover`, `saveForcedInclusion` and `sweepProtocolFees` share one reentrancy lock.
Pause affects none of these entry points, nor the registry's (spec 1 requires this for `land`,
`saveForcedInclusion` and the registry). Only `saveForcedInclusion` accepts ETH;
`upgradeToAndCall` rejects it too.

## EtnaStakingRegistry

- `register(publicKey, amount, popSig)`: a 33-byte compressed consensus key with a proof of
  possession over the EIP-712 `Register(address owner)` digest for the caller, who becomes the
  owner for life. Each key registers once, ever. There are 4,096 slots; a bond id is a slot, and
  released slots are reused last in, first out.
- `requestExit`, `confirmExit`, `withdraw(bondId, to)`, `slashDoubleSign(bondId, voteA, voteB)`
  and the Inbox-only `forceExit` follow spec 4.1 and 8 step 2. Confirming an exit needs an
  initialized Inbox whose `activeCommitteeSnapshot` reaches the exit block; `slashDoubleSign`
  needs an initialized Inbox and accepts votes from the current or an earlier generation.
- `forceExit(bondId, entryKey)` derives the recovery execution block from `block.number`.
- Every L1 block that changes an entry ends with exactly one checkpoint
  (`l1Block`, `count`, `entriesRoot`). The Inbox proxy and the L2 chain id are immutables.

## Choices the spec leaves open

- Every domain tag is `bytes32` right-zero-padded ASCII, including the unversioned
  `ETNA_SET_NODE`.
- The Inbox proxy starts on `EtnaInboxBootstrap`, so its address exists before the registry that
  fixes it. Once the registry exists, the owner calls `upgradeToAndCall(EtnaInbox, init(...))`,
  and `init` also requires the owner. Slot 258 then reads 3.
- `init` takes `vp_unit`, `s_min`, `n_max` and `U`, checks their bounds and computes
  `committeeConfigHash` itself, so a configuration outside the spec bounds cannot be stored.
- `land` adds only an initialization check to the reference Solidity, and in particular no bound
  on the snapshot.
- `Landed` carries `VERSION = 1`; `Recovered` carries the new generation, c, R's number and
  timestamp, and both lists.
- Each field of a slot 290 origin is below 2^48.
- Evidence votes have type 1 or 2, a height in [1, 2^63), a round below 2^31, timestamp seconds
  read as an int64 within CometBFT's Timestamp range (negative values included), nanoseconds
  below 10^9 and a 65-byte low-s signature with V in {0, 1}. An all-zero block id is a nil vote,
  and a nil and a non-nil vote in the same round conflict.
- `confirmExit` and `withdraw` revert while the Inbox holds its reentrancy lock, so no exit
  confirmation or withdrawal can run inside a landing or a recovery.
- A released slot's leaf is the leaf of an all-zero entry, not zero.
- A repeated `confirmExit` succeeds and never moves `exitConfirmedAtL1`.
- The registry checks each exclusion's `entryKey` inside `forceExit`; a mismatch or a released
  slot reverts the whole `recover`.
- Registry storage that appendix B does not name (tree nodes, free slots, used keys) lives in the
  `taiko.etna.registry` namespace after `entries`, so nodes read only the two named slots.
- `minStake` and `s_min` are independent; the deploy script defaults `minStake` to `s_min`.
- `activationDelay`, `exitDelay` and `withdrawalDelay` are each in [1, 2^32), so an oversized
  delay cannot make every registration or exit request revert.
- `maxBatchBlocks` is at least 6, with no multiple-of-6 rule.

## Storage

- Inbox: appendix B exactly. The named slots are 258, 268–274, 278–282, 284, 285 and 290;
  reserved slots 283, 286–289 and 291 are never read or written, and slots 251–257, 259–267 and
  275–277 are unused padding.
- Registry: the ERC-7201 namespace `taiko.etna.registry` with base R holds `checkpoints` at R
  and `entries` at R + 1, the only slots nodes read, then the tree nodes, the free slots and the
  used keys. Bond owners and exit confirmations live in the separate namespaces
  `taiko.etna.registry.owners` and `taiko.etna.registry.exit-confirmations`, outside
  `entriesRoot`.
- Packed words in both contracts lay out their fields from the least-significant bit: `ckPrefix`
  takes 8 bits, every other field 48, and a wider value reverts.
- The machine-readable layout, with every slot, mapping derivation and packing table, is the
  `layout` section of `testdata/etna_vectors/vectors.json`; `EtnaVectors.t.sol` checks both
  contracts against it. `impl/*_Layout.sol` are generated by `pnpm layout:l1`.

## Deployment

`script/layer1/etna/DeployEtnaDevnet.s.sol` deploys in the owner-initialized order (the Inbox
proxy on its bootstrap, the registry, then the owner's `upgradeToAndCall` with `init`); its
NatSpec lists every environment variable. Run from `packages/protocol`:

```bash
export FOUNDRY_PROFILE=layer1 S=script/layer1/etna/DeployEtnaDevnet.s.sol:DeployEtnaDevnet
forge script $S --sig 'deployInboxProxy()' --rpc-url "$L1_RPC" --broadcast # export INBOX_PROXY
forge script $S --sig 'deployRegistry()' --rpc-url "$L1_RPC" --broadcast # export STAKING_REGISTRY
# Validators register and activate; pick GENESIS_CUTOFF, compute committee 0's record hash,
# build the L2 genesis and compute block 0's hash and state root with the EL.
forge script $S --sig 'deployInbox()' --rpc-url "$L1_RPC" --broadcast
```

`deployInbox()` deploys the SignalService and the `EtnaInbox` implementation, then upgrades and
initializes the proxy if the deployer owns it, or logs that call for the owner.
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
- The switch from Unzen to Etna (spec 12 item 9); these contracts start a new chain at L2 block 0.
- The protocol upgrade activation mechanism (spec 10.1, 12 item 10).
- Real proving guests. Tests use mock verifiers, so they show contract behaviour, not proof
  soundness; production needs a verifier that requires two proofs, at least one ZK (6.2).

The Inbox, the registry and the SignalService are upgradeable proxies whose owner should be the
DAO behind a timelock; an upgrade can bypass any rule here (spec 1).
