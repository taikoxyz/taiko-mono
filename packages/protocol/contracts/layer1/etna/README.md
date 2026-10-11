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
3. The first block's epoch is `startEpoch = p / epochLenL2`, since the batch starts at `p + 1`
   and epoch `e` starts at `1 + e * epochLenL2`. Before writing any outputs, the contract reads
   `startCommitteeRecordHash = committee[startEpoch]` and requires it to be non-zero
   (`StartingCommitteeNotRecorded`). This input comes from contract storage, never calldata.
4. One record per epoch `e` with `h_first(e)` in `(p, lastHeight]`, in ascending order, with
   `epoch == e + 1` and a non-zero hash; anything missing, extra, reordered or zero reverts
   `CommitteeRecordsMismatch`. Each becomes `committee[e + 1]`, which must still be empty
   (`CommitteeAlreadyRecorded`).
5. `anchorNumber < block.number`, with its hash from `blockhash` up to 256 blocks back or from the
   EIP-2935 history contract (`0x0000F90827F1C53a10cb7A02335B175320002935`) up to 8191 blocks back,
   and non-zero (`AnchorUnavailable`).
6. The transaction carries at least one blob (`BlobsRequired`); all of its blob hashes are bound.

It then sets `lastCheckpoint = (lastHeight, lastBlockHash)`, saves
`(lastHeight, lastBlockHash, lastStateRoot)` in the L1 SignalService (which keeps the Bridge's L2 to
L1 path working), emits `BatchLanded`, and calls `proofVerifier.verifyProof(0, statementHash, proof)`,
which reverts on a bad proof and undoes everything. The statement is:

```solidity
statementHash = keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V2"),
    block.chainid,                 // uint256
    l2ChainId,                     // uint64
    recoveryGeneration,            // uint64
    p, parentHash,                 // uint64, bytes32
    startCommitteeRecordHash,      // bytes32, read from committee[p / epochLenL2]
    lastHeight, lastBlockHash, lastStateRoot,
    anchorNumber, anchorHash,      // uint64, bytes32
    keccak256(abi.encode(records)),
    keccak256(abi.encodePacked(blobHashes))
));
```

The V2 domain separates this encoding from V1, which did not bind the starting committee.
`hashLandStatement` is a raw encoding helper with an explicit starting-record argument. It does
not authenticate that argument; `land` supplies the value read from storage. The fixed vector in
`test/layer1/etna/EtnaInboxLand.t.sol` pins all fields for the guest and lander.

### Verification constraints

The trusted inputs are the parent checkpoint, generation and starting committee record read by
`land`, plus the L1 anchor hash and actual transaction blob hashes. The terminal block/state roots
and new committee records are claims whose correctness the proof must establish. The verifier
must accept only an Etna program that enforces the following V2 constraints:

1. **Authenticate the context.** Reconstruct the L1 header whose RLP hash is the bound
   `anchorHash`, then authenticate all other block anchors through its parent-header chain. Verify
   Inbox/registry account and storage proofs against those headers' state roots. The epoch schedule
   and genesis record must match the authenticated Inbox state; selection parameters and contract
   addresses must match the trusted program configuration. A witness cannot choose another registry,
   epoch length, cutoff rule or voting-power unit.
2. **Open the starting commitment.** Hash the full starting committee record and require equality
   with `startCommitteeRecordHash`, with `targetEpoch == p / epochLenL2`. Its supplied members must
   reconstruct the canonical MEM-08 set root, total stake and voting power. The record encoding is
   the node's `committee::record_hash`:

   ```solidity
   recordHash = keccak256(abi.encode(
       bytes32("ETNA_COMMITTEE_V1"),
       l2ChainId,          // uint256
       targetEpoch,       // uint64
       cutoffL1Block,     // uint64
       checkpointIndex,   // uint64
       setRoot,           // bytes32, selected committee; not registry entriesRoot
       totalStake,        // uint256
       totalPower,        // uint64
       encodingVersion    // uint8
   ));
   ```

3. **Derive committee outputs.** At `h_first(e)`, use the **parent block's** authenticated L1
   anchor to compute the prescribed snapshot cutoff, floored at `genesisCutoff`. For L2 block 1,
   the parent anchor is the genesis record's L1 initialization block `L1_0`. Authenticate the
   registry checkpoint selected at that cutoff, reconstruct `entriesRoot` from its complete entry
   list, and apply the same
   eligibility, key deduplication, size cap and power mapping as the node. The resulting record for
   `e + 1` must equal the corresponding committed `records` output. These are future records to be
   landed by this transaction; they are not independently trusted committees.
4. **Verify every switch.** At `h_switch(t) = h_first(t) - 2`, reproduce the node's switch gate
   using that block's own authenticated L1 anchor: its Inbox proof must show both
   `lastCheckpoint.height >= h_first(t - 1)` and `committee[t] == derivedRecordHash`. This is
   required even if the derivation happened inside this batch. When the derivation was before the
   batch, open the already-landed on-chain record to recover its members; do not invent a committee
   or treat it as this batch's output. A freshly derived output cannot by itself authorize a switch
   before it has landed on L1. Apply the validator update with CometBFT's H+2 timing, so the new
   committee signs from `h_first(t)`.
5. **Verify execution, finality and data.** Authenticate the parent EL header against `parentHash`
   to obtain its state root. Verify the consecutive EL blocks and all Etna header rules, the
   CometBFT commits with strictly more than 2/3 of the correct committee's voting power under
   `taiko-etna-<l2ChainId>-g<generation>`, and the data commitment to the bound blob hashes. The
   resulting terminal height, block hash, state root and committee outputs must reproduce the bound
   V2 statement exactly.

For example, with `L = 10`, a previous landing of blocks 1–5 has already stored `committee[1]`,
derived at block 1. A new batch 6–12 starts under `committee[0]`: its bound starting record is C0.
At switch block 9, the guest proves the block's L1 anchor already contains committee 1 and a
checkpoint covering block 1; committee 1 then signs from block 11. Block 11 derives committee 2,
which is the new batch's output. The starting record C0, previously landed C1 and output C2 have
different roles and must all satisfy their respective checks.

Consequently a single genesis batch covering blocks 1–11 cannot satisfy the switch gate unless
committee 1 has already landed in an earlier transaction, which would advance the parent checkpoint.
The valid path splits before switch block 9, lands committee 1, then produces the later blocks with
an L1 anchor proving it. Contract tests using a mock verifier exercise statement encoding, batching
and rollback; accepting a large mock batch does not establish that its consensus proof is valid.

Notes for guests:

- `keccak256(abi.encode(records))` hashes a dynamic-array ABI encoding: the `0x20` offset word,
  length, then each record as two words (`epoch`, `recordHash`).
- Inbox and registry addresses are fixed by the trusted program image because the statement does
  not bind `address(this)`. Another Inbox requires another image/configuration.
- `anchorNumber` may be a recent L1 block after all batch anchors, so a landing outage longer than
  the EIP-2935 window need not strand old blocks. Every storage witness must still authenticate
  against an anchor on that header chain; current tentative writes cannot serve as past L1 proofs.

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
