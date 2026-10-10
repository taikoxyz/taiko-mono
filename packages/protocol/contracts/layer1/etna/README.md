# Etna L1 contracts

Etna replaces Shasta's proposer and prover flow with a proof-of-stake chain: a committee of TAIKO
stakers orders and signs L2 blocks with CometBFT, and anyone may later land proven batches of those
blocks on L1. This directory holds the L1 side.

| Contract                           | Role                                                                                                                                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `impl/EtnaInbox.sol`               | The new implementation of the existing Shasta Inbox proxy: activates Etna from the last finalized Shasta block, lands proven batches (`land`) and keeps the legacy Shasta bond exit. |
| `impl/EtnaStakingRegistry.sol`     | A new UUPS proxy: validators stake TAIKO against an Ed25519 consensus key, send heartbeats, exit and withdraw. Committees are derived from its checkpoints.                          |
| `libs/LibEntriesTree.sol`          | The incremental Merkle tree behind the registry's `entriesRoot`.                                                                                                                     |
| `../../layer2/core/L2FeeVault.sol` | On L2: the coinbase of every Etna block, holding fees until the owner withdraws them.                                                                                                |

The Etna node (taiko-client-rs `crates/abci`, taikoxyz/taiko-mono#22280) reads the Inbox and the
registry straight from storage with EIP-1186 storage proofs, so the slots below are an interface,
not an implementation detail. Its side of this interface is `crates/abci/src/l1/layout.rs`. The
protocol itself is specified in taikoxyz/taiko-mono#22262; requirement IDs such as `MEM-13` below
refer to that specification.

## Terms

- **`B*` (genesis height):** the last finalized Shasta L2 block, which becomes the Etna genesis.
  **`H*`** is its block hash and **`S*`** its state root.
- **`H_0`:** the first Etna block, `B* + 1`.
- **`L1_0`:** the L1 block in which `activateEtna` ran.
- **`L` (`epochLenL2`):** the epoch length in L2 blocks. Epoch `e` starts at L2 block
  `h_first(e) = B* + 1 + e * L`. **`epochLenL1`** is the epoch length in L1 blocks.
- **`e_0`:** the first epoch, always 0.
- **Committee record:** the members and voting power of one epoch's committee, which the node
  derives from a registry checkpoint; the Inbox stores its hash, the **record hash**.
- **`genesisCutoff`:** the L1 block whose registry checkpoint defines the epoch-0 committee.
- **`W` (`heartbeatWindow`):** the heartbeat window in L1 blocks. Window `k` covers L1 blocks
  `k * W` to `(k + 1) * W - 1`; its start is `k * W`.
- **Landing:** submitting a proven batch of Etna blocks to `EtnaInbox.land`; the caller is the
  **lander**, and the program whose proof `land` verifies is the **guest**.

## Rollout order

1. Deploy the registry. Validators register and heartbeat.
2. On L2, deploy `L2FeeVault`; its address becomes the node's `fee_vault` chain constant. The L2
   Anchor and SignalService upgrade of taikoxyz/taiko-mono#22222 follows its own ordering.
3. DAO proposal 1: upgrade the Inbox proxy to the Shasta implementation that has `freeze()` and call
   it, in one `upgradeToAndCall`. From then on `propose` and `saveForcedInclusion` revert, while
   `prove`, the bond functions and the views keep working.
4. Wait for the drain: every Shasta proposal proven (the proving window is 4 hours on mainnet).
5. DAO proposal 2: `upgradeToAndCall(EtnaInbox, activateEtna(params))`, with `genesisHeight = B*`
   and the `committeeRecordHash` the Etna node tooling computes from the registry at
   `genesisCutoff` (a past L1 block at or after the registry's first checkpoint).
6. Validators run `abci-genesis` and start CometBFT. alethia-reth's Etna fork timestamp must fall
   after `B*`'s timestamp and at or before the first proof-of-stake block.

`activateEtna` requires, in order: the Inbox is frozen; it is drained
(`lastFinalizedProposalId + 1 == nextProposalId`); the L1 SignalService holds a checkpoint at `B*`
whose block hash is the Shasta last finalized block hash; `epochLenL2 >= 3` and `epochLenL1 > 0`;
`genesisCutoff < block.number` and the registry's first checkpoint is at or before it;
`committeeRecordHash != 0`.

On a devnet, `script/layer1/etna/DeployEtnaDevnet.s.sol` performs step 1 and deploys the two
implementations of steps 3 and 5, logging both owner calls; `script/layer2/DeployL2FeeVault.s.sol`
performs step 2. Each script's NatSpec lists its environment variables.

## Node-facing storage

Packed fields follow Solidity's packing: the first field takes the lowest bits of the word.

### `EtnaInbox` (the Inbox proxy)

Slots 0–250 are the `EssentialContract` prefix, unchanged. The Shasta variables keep their slots so
the upgrade preserves them.

| Slot    | Content                                                                      | Packing                                                             |
| ------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 251     | Shasta `activationTimestamp` (no longer used)                                | `uint48`                                                            |
| 252–253 | Shasta core state (frozen; `activateEtna` reads its finalization)            | struct                                                              |
| 254     | Shasta proposal hashes (no longer used)                                      | mapping                                                             |
| 255–256 | Shasta forced inclusion queue (no longer used)                               | struct                                                              |
| 257     | Shasta bond balances, kept for the legacy bond exit                          | struct                                                              |
| 258     | `migrationState`, `frozenAtL1Block`, `drainedAtL1Block`                      | `uint8` bits 0–7, `uint64` bits 8–71, `uint64` bits 72–135          |
| 259–267 | reserved (#22262 migration features not built here)                          | —                                                                   |
| 268     | `recoveryGeneration`                                                         | `uint64` bits 0–63; the rest is reserved for stall recovery         |
| 269     | reserved (#22262 config registry)                                            | —                                                                   |
| 270     | `lastCheckpoint.height`                                                      | `uint64` bits 0–63                                                  |
| 271     | `lastCheckpoint.blockHash`                                                   | `bytes32`                                                           |
| 272     | `genesisHeight` (`B*`), `l1Block` (`L1_0`), `epochLenL2` (`L`), `epochLenL1` | `uint64` bits 0–63, 64–127, 128–191, 192–255                        |
| 273     | `genesisBlockHash` (`H*`)                                                    | `bytes32`                                                           |
| 274     | `genesisStateRoot` (`S*`)                                                    | `bytes32`                                                           |
| 275–277 | reserved (#22262 publication register)                                       | —                                                                   |
| 278     | `committee`: `mapping(uint64 epoch => bytes32 recordHash)`                   | `committee[e]` at `keccak256(abi.encode(uint256(e), uint256(278)))` |
| 279     | `genesisCutoff`                                                              | `uint64` bits 0–63                                                  |
| 280–300 | `__gap`                                                                      | —                                                                   |

`migrationState` is 0 (none), 1 (frozen, written by the Shasta `freeze()`) or 3 (Etna active);
value 2 is reserved by #22262. The node reads only bits 0–7 of slot 258.

### `EtnaStakingRegistry`

All state lives in the ERC-7201 namespace `taiko.etna.registry`, at base slot
`R = keccak256(abi.encode(uint256(keccak256("taiko.etna.registry")) - 1)) & ~bytes32(uint256(0xff))`
`= 0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000`.

| Slot    | Content                                                                                 |
| ------- | --------------------------------------------------------------------------------------- |
| `R`     | `checkpoints.length`                                                                    |
| `R + 1` | `entries.length` (the entry index is the bond id)                                       |
| `R + 2` | `bondOwner`: `mapping(uint256 bondId => address)`                                       |
| `R + 3` | `withdrawn`: `mapping(uint256 bondId => bool)`                                          |
| `R + 4` | `keyHolder`: `mapping(bytes32 pubkey => uint256)`, the latest holder's bond id plus one |
| `R + 5` | `tree`: `mapping(uint256 node => bytes32)`, the Merkle nodes                            |

| Word                        | Content                                                                  | Packing                                      |
| --------------------------- | ------------------------------------------------------------------------ | -------------------------------------------- |
| `keccak256(R) + 2i`         | `checkpoints[i].l1Block`, `checkpoints[i].count`                         | `uint64` bits 0–63, `uint32` bits 64–95      |
| `keccak256(R) + 2i + 1`     | `checkpoints[i].entriesRoot`                                             | `bytes32`                                    |
| `keccak256(R + 1) + 3j`     | `entries[j].pubkey`                                                      | `bytes32`                                    |
| `keccak256(R + 1) + 3j + 1` | `entries[j].effStake` (TAIKO base units)                                 | `uint256`                                    |
| `keccak256(R + 1) + 3j + 2` | `activeFromL1`, `exitEffectiveL1`, `lastHeartbeatAt`, `lastHeartbeatSeq` | `uint64` bits 0–63, 64–127, 128–191, 192–255 |

`exitEffectiveL1 = type(uint64).max` means no exit was requested. Entry leaf `j` is
`keccak256(abi.encode(bytes32("ETNA_REG_ENTRY"), uint256(j), pubkey, effStake, activeFromL1,
exitEffectiveL1, lastHeartbeatAt, lastHeartbeatSeq))`. `entriesRoot` over `count` entries pads the
leaves with zero leaves to the next power of two and hashes pairs as `keccak256(left ‖ right)`;
one entry gives leaf 0 and no entry gives `bytes32(0)`. At most 4096 entries exist.

## Contract obligations

The node verifies what the contracts store but relies on the contracts for the following. A
contract that breaks one cannot make nodes accept a block their proofs contradict, but it can stop
the chain, mostly for good: a height's L1 snapshot is fixed once its parent is committed, and only
a recovery generation gets past it.

- **Activation writes.** `activateEtna` writes, in one call: the activation record (272–274),
  `migrationState = 3` (258), `genesisCutoff` (279), `committee[0]` (278) and
  `lastCheckpoint = (B*, H*)` (270–271). `committee[0]` must be the record hash of the committee the
  registry derives at `genesisCutoff`: every active bonded entry, without the heartbeat filter.
  Without the checkpoint the node cannot accept `H_0`, since it refuses heights too far beyond the
  last landed checkpoint, so the chain never starts; without the rest the genesis does not verify.
- **One registry checkpoint per changing L1 block.** Every L1 block that changes an entry ends with
  exactly one checkpoint (changes in the same block overwrite its `count` and `entriesRoot`), so
  `checkpoints[i].l1Block` strictly increases. The node's snapshot search relies on that order, and
  it reads checkpoint `i`'s entries at any L1 block before `checkpoints[i + 1].l1Block`.
- **Complete checkpoints.** A checkpoint's `count` and `entriesRoot` cover every entry, exited ones
  included, in bond id order, as they stand at the end of its `l1Block`.
- **Heartbeat records.** `lastHeartbeatAt` and `lastHeartbeatSeq` follow the heartbeat rule below.
- **Unique pubkeys.** `register` refuses a pubkey held by an entry whose exit is not yet effective.
  The node also keeps only the lowest bond id among eligible entries sharing a pubkey, as defence in
  depth.
- **Committee records come only from `activateEtna` and `land`.** `committee[0]` is set at
  activation; `committee[e + 1]` is set only by `land`, from a proven batch containing
  `h_first(e)`, and never overwritten (`land` asserts the slot is empty). A missing `committee[e]`
  holds the chain at epoch `e`'s first block until a batch lands it; a conflicting value would stop
  the chain there.

## Heartbeats

- Only the bond owner calls `heartbeat(bondId)`, and only while `block.number < exitEffectiveL1`.
- The heartbeat names the current window: `windowStart = floor(block.number / W) * W`.
- It is accepted if the entry has none yet (`lastHeartbeatSeq == 0`, in any window, window 0
  included) or if `windowStart > lastHeartbeatAt`. So at most one heartbeat per window, and
  `lastHeartbeatAt` only increases; a second one in the same window reverts
  `HeartbeatAlreadyRecorded`.
- It writes `lastHeartbeatAt = windowStart` and `lastHeartbeatSeq += 1`, updates the tree and the
  block's checkpoint, and emits `HeartbeatRecorded(bondId, windowStart, seq)`.
- Registration is not a heartbeat: both fields start at 0. A first heartbeat in window 0 leaves
  `lastHeartbeatAt` at 0, so `lastHeartbeatSeq > 0`, not `lastHeartbeatAt > 0`, tells whether an
  entry has a heartbeat.
- From epoch `e_0 + 3` on, the node counts an entry as live when `lastHeartbeatSeq > 0` and
  `lastHeartbeatAt` is at or after a window start it computes from its schedule (`MEM-13`).
  Epochs `e_0` to `e_0 + 2` apply no heartbeat filter.

## Landing

`land(input, proof)` is permissionless. With `p` and `parentHash` the last checkpoint's height and
block hash, it requires, in order:

1. Etna is active (`EtnaNotActive`).
2. `p < lastHeight <= p + maxBatchBlocks` and `lastHeight <= type(uint48).max`, the SignalService
   key width (`NoProgress`, `BatchTooLarge`, `HeightOverflow`).
3. One record per epoch `e` with `h_first(e)` in `(p, lastHeight]`, in ascending order, with
   `epoch == e + 1` and a non-zero hash; anything missing, extra, reordered or zero reverts
   `CommitteeRecordsMismatch`. Each becomes `committee[e + 1]`.
4. `anchorNumber < block.number`, with its hash from `blockhash` up to 256 blocks back or from the
   EIP-2935 history contract up to 8191 blocks back, and non-zero (`AnchorUnavailable`).
5. The transaction carries at least one blob (`BlobsRequired`); all of its blob hashes are bound.

It then sets `lastCheckpoint = (lastHeight, lastBlockHash)`, saves
`(lastHeight, lastBlockHash, lastStateRoot)` in the L1 SignalService (which keeps the Bridge's L2 to
L1 path working), emits `BatchLanded`, and calls `proofVerifier.verifyProof(0, statementHash, proof)`,
which reverts on a bad proof and undoes everything. The statement is:

```solidity
statementHash = keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V1"),
    block.chainid,                 // uint256
    l2ChainId,                     // uint64
    recoveryGeneration,            // uint64
    p, parentHash,                 // uint64, bytes32
    lastHeight, lastBlockHash, lastStateRoot,
    anchorNumber, anchorHash,      // uint64, bytes32
    keccak256(abi.encode(records)),
    keccak256(abi.encodePacked(blobHashes))
));
```

`hashLandStatement` returns the same hash for given inputs, and
`test_hashLandStatement_MatchesTheFixedVector` (`test/layer1/etna/EtnaInboxLand.t.sol`) pins one
vector for the lander and the guest.

The guest's obligations: a valid proof attests that

- heights `p + 1` to `lastHeight` form a chain from `parentHash` to `lastBlockHash` with post-state
  `lastStateRoot`, each executed under the Etna rules;
- each height has a CometBFT commit signed by more than 2/3 of its epoch committee's voting power,
  under the CometBFT chain id `taiko-etna-<l2ChainId>-g<recoveryGeneration>`;
- every block's L1 anchor lies on the L1 header chain ending at `anchorHash`, and the last block's
  anchor number is `anchorNumber`;
- each record is the committee record derived from the registry witness carried in block
  `h_first(e)`;
- the blocks' data is encoded in the bound blobs.

## Open items

- **O1.** Forced inclusions still queued at the freeze are never included; their fees stay in the
  Inbox.
- **O2.** The guest's statement semantics and the blob encoding are fixed with the guest and
  lander follow-ups.
- **O3.** Landers are not paid until prover rewards exist (#22262 `L1-11`).
- **O4.** `recoveryGeneration` stays 0 until stall recovery exists (#22262 `GOV-04`); the statement
  already binds it.
- **O5.** `activateEtna` cannot check the node's `L >= D_MAX - MARGIN_V + 3` (`D_MAX` is the node's
  maximum number of unlanded blocks, `MARGIN_V` its safety margin); with a smaller `L` the node
  refuses the genesis.
- **O6.** The EIP-2935 window limits a batch's last anchor to 8191 L1 blocks (about 27 hours) before
  it lands.
- **O7.** The 4096-entry cap counts exited entries; pruning or compaction is a follow-up.
- **O8.** No Ed25519 proof of possession: anyone may register any free key; pubkey uniqueness and
  the node's lowest-bond-id rule limit the damage.
- **O9.** Once slashing exists, the registry's `withdrawalDelay` must exceed the time to land a
  batch plus the evidence window.
- **O10.** `ProverWhitelist` and the proposer checker become unused after activation.
- **O11.** The specification's separate heartbeat key (with rotation and retirement), its signed
  heartbeat payload and relayed heartbeats are not built; the bond owner heartbeats directly. The
  node's eligibility rule already matches the fields recorded here.
- **O12.** `committee[0]` and the records of epochs 1 and 2 apply no heartbeat filter; the tool
  computing the activation's `committeeRecordHash` must follow the same rule.
