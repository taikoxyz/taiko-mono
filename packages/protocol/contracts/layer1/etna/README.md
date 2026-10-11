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
   `genesisCutoff` and committee record hash. It deploys fresh SignalService and EtnaInbox proxies.
   The Inbox is initialized atomically in the proxy constructor and saves a block-0 checkpoint to
   SignalService. SignalService authorizes the predicted Inbox proxy address.
5. Once the L1 initialization block is final, run `abci-genesis` and start CometBFT and the EL.
   The first consensus block is L2 block 1. Configure the EL's Etna fork from genesis.

`init(owner, params)` requires non-zero genesis hash, state root and committee record hash;
`epochLenL2 >= 3`; `epochLenL1 > 0`; and a past `genesisCutoff` at or after the registry's first
checkpoint. It runs once; implementation contracts have initializers disabled. SignalService must
authorize this proxy, or initialization reverts without retaining ownership or genesis state.

The genesis hash, state root and committee record are trusted bootstrap inputs. The deployer must
check that they match the L2 genesis file and the registry snapshot. The contract fixes
`genesisHeight = 0`; there is no freeze, drain, upgrade from an existing Inbox, or legacy bond exit.

The deployment script's NatSpec lists its environment variables. Both calls use `PRIVATE_KEY` and
optional `CONTRACT_OWNER`; `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`. `deployInbox()` needs
`STAKING_REGISTRY`, `REMOTE_SIGNAL_SERVICE` (L2), `ETNA_PROOF_VERIFIER`, `L2_CHAIN_ID`,
`MAX_BATCH_BLOCKS`, `GENESIS_BLOCK_HASH`, `GENESIS_STATE_ROOT`, `EPOCH_LEN_L2`, `EPOCH_LEN_L1`,
`GENESIS_CUTOFF` and `COMMITTEE_RECORD_HASH`. Use the same deployer for the four consecutive CREATEs
of the Inbox deployment; the script predicts the final proxy using its current nonce.

No Etna guest exists yet, so a devnet's `EtnaInbox` uses a stand-in proof verifier such as the
accept-all `contracts/layer1/devnet/OpVerifier.sol`. As `land` is permissionless, anyone can then
land any batch: write arbitrary SignalService checkpoints (forged L2 to L1 messages) and conflicting
committee records (a permanent halt at that epoch). Such a verifier is for devnets only.

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
| 269     | reserved                                               | —                                                  |
| 270     | `lastCheckpoint.height`                                | `uint64` bits 0–63; initially 0                    |
| 271     | `lastCheckpoint.blockHash`                             | `bytes32`; initially the genesis hash              |
| 272     | `genesisHeight`, `l1Block`, `epochLenL2`, `epochLenL1` | four `uint64` values, in that order                |
| 273     | `genesisBlockHash`                                     | `bytes32`                                          |
| 274     | `genesisStateRoot`                                     | `bytes32`                                          |
| 275–277 | reserved                                               | —                                                  |
| 278     | `committee`                                            | `mapping(uint64 epoch => bytes32 recordHash)`      |
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

- Initialization writes the genesis record, status 3, `genesisCutoff`, `committee[0]` and
  `lastCheckpoint = (0, H*)`, and saves `(0, H*, S*)` in SignalService.
- `committee[0]` must be the record hash derived by the node at `genesisCutoff`: active entries
  with at least `max(s_min, vp_unit)`, lowest bond id per pubkey, top `n_max` by stake, and no
  heartbeat filter. The contract accepts the deployer's supplied record; the node verifies it.
- Each L1 block changing an entry ends with one checkpoint. Same-block mutations overwrite the
  latest checkpoint; its `count` and root cover all entries, including exited ones.
- Registration rejects a key held by any entry whose exit is not yet effective. The node also
  deduplicates eligible keys defensively.
- `committee[e + 1]` is written only by `land`, from a proven batch covering `h_first(e)`, and
  cannot be overwritten. Missing records hold the node at its switch height; conflicting records
  halt it.

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

`land(input, proof)` is permissionless. With `p` and `parentHash` the last checkpoint's height and
block hash, it requires, in order:

1. The proxy is initialized (`EtnaNotActive`).
2. `p < lastHeight <= p + maxBatchBlocks` and `lastHeight <= type(uint48).max`, the SignalService
   key width (`NoProgress`, `BatchTooLarge`, `HeightOverflow`).
3. One record per epoch `e` with `h_first(e)` in `(p, lastHeight]`, in ascending order, with
   `epoch == e + 1` and a non-zero hash; anything missing, extra, reordered or zero reverts
   `CommitteeRecordsMismatch`. Each becomes `committee[e + 1]`, which must still be empty
   (`CommitteeAlreadyRecorded`).
4. `anchorNumber < block.number`, with its hash from `blockhash` up to 256 blocks back or from the
   EIP-2935 history contract (`0x0000F90827F1C53a10cb7A02335B175320002935`) up to 8191 blocks back,
   and non-zero (`AnchorUnavailable`).
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
  under the CometBFT chain id `taiko-etna-<l2ChainId>-g<recoveryGeneration>`; the first epoch's
  committee is `committee[0]` from initialization;
- every block's L1 anchor lies on the L1 header chain ending at `anchorHash`, the hash of
  `anchorNumber`. So `anchorNumber` is any L1 block at or after the last block's anchor number: a
  lander picks a recent one, and a landing outage longer than the 8191-block EIP-2935 window does
  not strand the batch;
- each record is the committee record derived from the registry witness carried in block
  `h_first(e)`;
- the blocks' data is encoded in the bound blobs.

Notes for guests:

- `keccak256(abi.encode(records))` hashes the ABI encoding of a dynamic array, which starts with
  the `0x20` offset word, then the length, then each record as two words (`epoch`, `recordHash`).
- The statement does not bind `address(this)`, so the Inbox and registry addresses are constants
  of the guest program image: a proof for another Inbox needs another image.

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
