# Etna contracts

Etna starts as a new proof-of-stake chain at L2 block 0. A committee of TAIKO stakers orders and
signs L2 blocks with CometBFT, and anyone can land proven batches on L1.

| Contract                           | Role                                                                                     |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| `impl/EtnaInbox.sol`               | A fresh UUPS proxy initialized with L2 genesis and committee 0; lands proven batches.    |
| `impl/EtnaStakingRegistry.sol`     | Validators stake TAIKO, heartbeat, exit and withdraw. Its checkpoints define committees. |
| `libs/LibEntriesTree.sol`          | The incremental Merkle tree behind the registry checkpoints.                             |
| `../../layer2/core/L2FeeVault.sol` | The L2 fee recipient; the owner can withdraw collected fees.                             |

The ABCI node in taikoxyz/taiko-mono#22280 reads the Inbox and registry with EIP-1186 proofs.
Its interface is `crates/abci/src/l1/layout.rs`. This PR preserves that storage interface; it
implements no Shasta-to-Etna migration. The protocol specification is #22262.

## Genesis initialization

1. Deploy the staking registry with `DeployEtnaDevnet.run()`. Validators register, then wait for
   their activation delay and L1 finality.
2. Choose a finalized registry snapshot at `genesisCutoff` and compute committee 0 with
   `taiko-client abci-committee-record`. At least one validator must be eligible there.
3. Prepare the L2 genesis file, including the fee vault or its planned deployment, and obtain its
   block-0 hash and state root. Set the node's fee-vault address consistently. If the genesis
   contracts embed L1 addresses, predict them before computing that hash: for deployment-wallet
   nonce `n`, the L1 SignalService proxy is CREATE at `n + 1` and the Inbox proxy at `n + 3`.
   Keep the wallet's nonce unchanged until `deployInbox()` runs.
4. Call `DeployEtnaDevnet.deployInbox()` with the genesis hash, state root, epoch lengths,
   `genesisCutoff`, committee record hash and `committeeConfigHash`. It deploys fresh SignalService and EtnaInbox proxies.
   The Inbox is initialized atomically in the proxy constructor and saves a block-0 checkpoint to
   SignalService. SignalService authorizes the predicted Inbox proxy address.
5. Once the L1 initialization block is final, run `abci-genesis` and start CometBFT and the EL.
   The first consensus block is L2 block 1. Configure the EL's Etna fork from genesis.

`init(owner, params)` requires non-zero genesis hash, state root, committee record hash and committee config hash;
`epochLenL2 >= 3`; `epochLenL1 > 0`; and a past `genesisCutoff` at or after the registry's first
checkpoint. It runs once; implementation contracts have initializers disabled. SignalService must
authorize this proxy, or initialization reverts without retaining ownership or genesis state.

The genesis hash, state root, committee record and config hash are trusted bootstrap inputs. The deployer must
check that they match the L2 genesis file and the registry snapshot. The contract fixes
`genesisHeight = 0`; there is no freeze, drain, upgrade from an existing Inbox, or legacy bond exit.

The deployment script's NatSpec lists its environment variables. Both calls use `PRIVATE_KEY` and
optional `CONTRACT_OWNER`; `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`. `deployInbox()` needs
`STAKING_REGISTRY`, `REMOTE_SIGNAL_SERVICE` (L2), `ETNA_PROOF_VERIFIER`, `L2_CHAIN_ID`,
`MAX_BATCH_BLOCKS`, `GENESIS_BLOCK_HASH`, `GENESIS_STATE_ROOT`, `EPOCH_LEN_L2`, `EPOCH_LEN_L1`,
`GENESIS_CUTOFF`, `COMMITTEE_RECORD_HASH` and `COMMITTEE_CONFIG_HASH`. Use the same deployer for the four consecutive CREATEs
of the Inbox deployment; the script predicts the final proxy using its current nonce.

No Etna guest exists yet, so a devnet's `EtnaInbox` uses a stand-in proof verifier such as the
accept-all `contracts/layer1/devnet/OpVerifier.sol`. As `land` is permissionless, anyone can then
land any batch and write arbitrary SignalService checkpoints (forged L2 to L1 messages).
Such a verifier is for ephemeral devnets only; selecting it must be explicit. Fixtures provide
the config hash and use the dummy proof provider, which does not enforce guest constraints.

## Configuration checks

- Keep node `inbox`, `registry` and `fee_vault` addresses equal to the deployed proxies, and
  `l2ChainId` equal to the node's chain id.
- Registry `heartbeatWindow` must equal node `heartbeat_window`, and `minStake` must be at least
  node `max(s_min, vp_unit)`. Choose `vp_unit` large enough that the entire TAIKO supply cannot
  exceed CometBFT's maximum voting power.
- Choose `epochLenL2 >= D_MAX - MARGIN_V + 3`, the node's back-pressure requirement. The contract
  checks only the minimum of 3 because those node parameters are not on-chain.
- The genesis snapshot must contain live eligible validators. A cutoff close to the L1
  initialization block reduces the chance of entries exiting or going offline before startup.
- The registry and Inbox owners can upgrade the contracts; use the intended chain governance.

## Node-facing storage

Packed fields use Solidity's low-order-first packing. The node's existing `activation` record is
now the genesis record: `B* = 0`, `H*` and `S*` are the L2 block-0 hash and state root, and `L1_0`
is the L1 proxy-initialization block. `h_first(e) = 1 + e * epochLenL2`.

### `EtnaInbox`

Slots 0–250 are the `EssentialContract` prefix. Other reserved slots keep the existing ABCI
interface stable; they do not contain Shasta state.

| Slot    | Content                                                | Packing                                            |
| ------- | ------------------------------------------------------ | -------------------------------------------------- |
| 251–257 | reserved                                               | —                                                  |
| 258     | initialized status                                     | `uint8` bits 0–7: 3 after initialization, 0 before |
| 259–267 | reserved                                               | —                                                  |
| 268     | `recoveryGeneration`                                   | `uint64` bits 0–63                                 |
| 269     | `committeeConfigHash`                                  | `bytes32`; trusted genesis config commitment       |
| 270     | `lastCheckpoint.height`                                | `uint64` bits 0–63; initially 0                    |
| 271     | `lastCheckpoint.blockHash`                             | `bytes32`; initially the genesis hash              |
| 272     | `genesisHeight`, `l1Block`, `epochLenL2`, `epochLenL1` | four `uint64` values, in that order                |
| 273     | `genesisBlockHash`                                     | `bytes32`                                          |
| 274     | `genesisStateRoot`                                     | `bytes32`                                          |
| 275–277 | reserved                                               | —                                                  |
| 278     | `genesisCommitteeRecordHash`                           | `bytes32`; direct genesis committee commitment     |
| 279     | `genesisCutoff`                                        | `uint64` bits 0–63                                 |
| 280–300 | `__gap`                                                | —                                                  |

`migrationState()` retains its name as a compatibility getter for the ABCI status word.
It exposes no migration state machine. `activation()` returns the genesis record.

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

- Initialization writes the genesis record, status 3, `genesisCutoff`, `genesisCommitteeRecordHash`,
  `committeeConfigHash` and
  `lastCheckpoint = (0, H*)`, and saves `(0, H*, S*)` in SignalService.
- `genesisCommitteeRecordHash` must be the record hash derived by the node at `genesisCutoff`: active entries
  with at least `max(s_min, vp_unit)`, lowest bond id per pubkey, top `n_max` by stake, and no
  heartbeat filter. The contract accepts the deployer's supplied record; the node verifies it.
- Each L1 block changing an entry ends with one checkpoint. Same-block mutations overwrite the
  latest checkpoint; its `count` and root cover all entries, including exited ones.
- Registration rejects a key held by any entry whose exit is not yet effective. The node also
  deduplicates eligible keys defensively.
- Future committees derive from fixed L1 cutoffs. There is no `committee(epoch)` getter,
  mapping, committee landing output or publication event. Landing is never an activation gate.

## Authenticated committee configuration

The canonical commitment is the eleven-word encoding (352 bytes):

```solidity
committeeConfigHash = keccak256(abi.encode(
    bytes32("ETNA_FIXED_CUTOFF_V1"), uint256(l2ChainId), address(stakingRegistry),
    uint64(cutoffGrid), uint64(cutoffLag), uint256(vpUnit), uint256(sMin), uint64(nMax),
    uint64(heartbeatWindow), uint64(2), uint8(1)
));
```

The last words bind lookahead 2 and record/algorithm version 1. Supply this nonzero hash as
`COMMITTEE_CONFIG_HASH` at deployment. The node independently opens it against its configured
parameters and persists it in authenticated genesis state. It must also authenticate `L1_0`, both
epoch lengths and `genesisCutoff` from Inbox storage.

For committee 0, `cutoff(0) = genesisCutoff`. For every `t >= 1`:

```text
base(t) = L1_0 + max(t - 2, 0) * epochLenL1
lagged(t) = max(base(t) - cutoffLag, 0)
cutoff(t) = max(genesisCutoff, floor(lagged(t) / cutoffGrid) * cutoffGrid)
```

Arithmetic is checked, and `cutoffGrid` must be nonzero. Select the last registry checkpoint at
or before this cutoff, authenticate its metadata, complete entry count and entries root, and
prove the next checkpoint's height is after the cutoff when it exists. A later proving header
can authenticate the immutable historical checkpoint; its height must cover the cutoff. No
failure advances the cutoff and no implicit empty-roster fallback exists.

## Heartbeats

`W` is the registry's `heartbeatWindow` in L1 blocks; the initial epoch `e_0` is 0.

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

`LandInput` has exactly `lastHeight`, `lastBlockHash`, `lastStateRoot` and
`l1ReferenceBlockNumber`. With `p` and `parentHash` the stored checkpoint, `land` requires active
status, `p < lastHeight <= p + maxBatchBlocks`, and `lastHeight <= type(uint48).max`. The reference
must be a past L1 block with a nonzero hash available from `blockhash` (256 blocks) or the
EIP-2935 history contract (8191 blocks). At least one transaction blob is required.

Landing saves the terminal checkpoint in the Inbox and SignalService, emits `BatchLanded`, and
calls `proofVerifier.verifyProof(0, statementHash, proof)`. Failure rolls back all writes. The
fifteen-word V4 preimage (480 bytes) is:

```solidity
statementHash = keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V4"),
    block.chainid, l2ChainId, address(this), address(stakingRegistry),
    recoveryGeneration, p, parentHash, committeeConfigHash,
    lastHeight, lastBlockHash, lastStateRoot,
    l1ReferenceBlockNumber, l1ReferenceBlockHash,
    keccak256(abi.encodePacked(blobHashes))
));
```

Both identities, config hash, generation and parent come from the contract. The reference hash
and ordered blob hashes come from the actual L1 execution context. `hashLandStatement` derives
identities and config internally but accepts raw generation, parent and terminal inputs for
encoding; it does not authenticate them. Call it through the proxy to bind that proxy's address.
V3 digests and old wire histories are incompatible with this prelaunch version.

### Guest and consensus obligations

Every account proof must derive its trie path from the corresponding bound Inbox or registry
address. Authenticate storage under that proved account root and an authenticated L1 header.
Open `committeeConfigHash` exactly as above and authenticate the genesis schedule. Apply the
existing membership, earliest eligible bond per key, stake ranking, MEM-08 ordering, floor power
mapping and overflow rules to each fixed snapshot. Keep heartbeat evaluation at the target
schedule instant, capped at the cutoff window, including the nonzero sequence guard and launch
exemptions for epochs 0, 1 and 2.

At switch `S(t) = 1 + t * epochLenL2 - 2`, require exactly one committee witness for `t` under
the committed parent's anchor and explicitly require `cutoff(t) <= parentAnchor.number`. Compare
every derived record field, return validator updates at FinalizeBlock and persist at Commit.
CometBFT activates them at `H(t) = 1 + t * epochLenL2`. Non-switch blocks carry no runtime
committee witness; epoch-first blocks have no extra requirement. Envelope version is 2.

The guest must verify the parent certificate, every current/next validator hash around H+2,
commits with strictly more than two-thirds voting power under
`taiko-etna-<l2ChainId>-g<generation>`, execution ancestry from the stored parent to terminal
hash/state root, and blob data. Every anchor belongs to the header chain ending at the reference
hash. Reference headers may be recent even for old batches. A batch can start/end at arbitrary
valid heights and never depends on an earlier batch's committee output.

The existing status, generation, anchor progress and back-pressure checks remain. In particular,
`height - checkpoint <= d_max - margin_v` can still stop block production during a settlement
outage, and `epochLenL2 >= unsettledCap + 3` remains the schedule bound. Committee authorization
is autonomous, while settlement progress still matters for overall liveness.

The fixed Solidity vector pins the four-field ABI, eleven-word config and V4 statement against
independent ethers encoding. Tests use an explicitly dummy verifier for batching, statement
binding and rollback; they do not prove the authoritative guest rules. No real ZK guest is part
of this change. Empty-roster liveness and old-key/withdrawal assumptions remain unchanged.

## Open items

- The Etna guest, blob encoding and lander are follow-ups. No prover rewards, slashing or stall
  recovery exist here; `recoveryGeneration` stays 0. The staking withdrawal delay must cover the
  evidence and landing windows once slashing is introduced.
- Registry capacity griefing: entries are never reclaimed, so exited/withdrawn bonds consume
  the 4096-entry capacity forever. Repeated registration and exit can permanently prevent new
  validators from joining. Pruning/compaction, a registration cost or a launch gate is required
  before mainnet; changing the capacity also requires changing the node's pinned tree depth.
- No Ed25519 proof of possession is required for registration.
- The spec's separate heartbeat key, signed payload and relayed heartbeats are not implemented;
  the bond owner heartbeats directly. Epochs 0, 1 and 2 have no heartbeat eligibility filter.
- Forced inclusions, fee accounting and an L2-to-L1 fee sweep remain separate work.
