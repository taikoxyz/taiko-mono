# Etna contracts

Etna starts a new proof-of-stake L2 chain at block 0. A committee of TAIKO stakers orders and
signs blocks with CometBFT. Anyone can land proven batches on L1 and submit authenticated L2
base-fee claims for the batch's committed reward recipient.

| Contract                           | Role                                                                          |
| ---------------------------------- | ----------------------------------------------------------------------------- |
| `impl/EtnaInbox.sol`               | Fresh L1 UUPS proxy; lands V8 batches, saves checkpoints and reward receipts. |
| `impl/EtnaStakingRegistry.sol`     | Stakes, immutable L2 reward addresses, heartbeats, exits and checkpoints.     |
| `libs/LibEntriesTree.sol`          | Recipient-bound registry entries tree.                                        |
| `../../layer2/core/L2FeeVault.sol` | Plain immutable L2 treasury predeploy; pays proved receipt claims once.       |

This is a new-genesis format. It has no existing-chain migration, L1 reward pool, participation
accounting, DAO subsidy, balance sweep or automatic bridge payout. The Inbox retains L1 forced
inclusion fees. The vault has no owner, proxy, initializer, upgrade function or privileged transfer.

## Genesis initialization

The vault runtime commits the L1 Inbox address, and the Inbox initialization commits the L2
genesis hash/state root. Resolve this dependency by predicting the Inbox before building genesis:

1. Deploy the registry with `script/layer1/etna/DeployEtnaDevnet.s.sol:DeployEtnaDevnet.run()`.
   Validators call `register(pubkey, stake, nonzeroL2RewardRecipient)`. Wait for activation and
   finality, select a past `genesisCutoff`, and derive nonempty committee 0 and its V2 record.
2. Read the deployment wallet's current pending nonce `n` **after** those transactions. Predict
   the SignalService proxy at CREATE nonce `n + 1` and Inbox proxy at `n + 3`. The deployment
   uses four consecutive CREATEs: service implementation/proxy, then Inbox implementation/proxy.
   Keep that wallet's nonce unchanged until `deployInbox()` executes.
3. Export the vault with explicit `L1_CHAIN_ID` and predicted `L1_INBOX`. It constructs
   `new L2FeeVault(l1ChainId, inbox)` in Foundry's local VM and exports `address(vault).code`.
   Compiler `deployedBytecode` with unresolved immutable placeholders is not usable runtime.
4. Build alloc-only genesis from the canonical devnet JSON and exported runtime. Preserve every
   non-alloc field. The treasury address follows the pinned EL's `get_treasury_address(chainId)`:
   use the decimal chain-ID text as an address prefix, zero-fill, and append `10001`. For chain
   167001 this is `0x1670010000000000000000000000000000010001`. Set `BasefeeSharingPctg = 0`.
5. With an execution client supporting Etna on this custom genesis, obtain the actual block-0
   hash and state root and verify treasury runtime/immutable reads and both system predeploys.
   Supply those commitments, committee 0/config hashes and schedule inputs to `deployInbox()`.
   It initializes the Inbox atomically and saves block 0 in SignalService. Compare its returned
   proxy address with the immutable Inbox prediction; any mismatch must abort node startup and
   require rebuilding the genesis/commitments. Never continue using a different Inbox address.
6. Wait for the L1 initialization block to finalize, then build ABCI genesis and start the nodes.
   The first consensus block is L2 block 1. Verify canonical root/history writes after that block.

Run the exporter from `packages/protocol`, without `--broadcast` or a private key:

```bash
mkdir -p deployments
L1_CHAIN_ID=1 \
L1_INBOX=0x1111111111111111111111111111111111111111 \
ETNA_RUNTIME_OUTPUT=deployments/etna-vault-runtime.json \
FOUNDRY_PROFILE=layer2 forge script script/layer2/ExportEtnaGenesis.s.sol:ExportEtnaGenesis

python3 script/layer2/build_etna_genesis.py \
  --base /path/to/canonical-devnet.json \
  --runtime deployments/etna-vault-runtime.json \
  --output deployments/etna-genesis.json
```

The example Inbox is a placeholder for the predicted proxy. The exporter rejects a zero chain or
Inbox through the vault constructor. JSON contains explicit L1 identity and fully initialized
runtime. The builder normalizes alloc addresses to lowercase `0x` form, rejects duplicate normalized
addresses, and writes sorted JSON with a terminating newline. All other alloc entries are retained;
the treasury, EIP-4788 roots and EIP-2935 history allocations are replaced with zero balance,
nonce 1 and exact code. Existing storage at those three addresses is deliberately replaced.

Both system runtimes are copied from `taikoxyz/alethia-reth` revision
`1e25b4849259320fca1123de362bc38b0b090ece`, `crates/node/tests/fixtures/etna-genesis.json`.
The builder checks the roots runtime's byte SHA-256 is
`cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d`.
It adds no Taiko hardfork JSON fields and changes no canonical genesis configuration.

**Execution-client acceptance remains a separate prerequisite.** At the pinned EL revision,
`--devnet-etna-timestamp 0` works only for the canonical devnet genesis hash; adding vault alloc
changes that hash. Its custom JSON parser does not activate Taiko forks from extra fields such
as `etnaTime`. Thus this artifact alone cannot start an Etna custom genesis on that binary.
The client must build the fork table first and recompute the genesis header/root using that
actual schedule; a generic parser's cached pre-override block-0 hash may omit Osaka header fields.
Real EL activation, genesis commitments and block execution must be accepted in the companion
EL work and Task10/12 integration; the Foundry VM tests do not establish those properties.

The deployment script documents its exact environment variables. Both entry points use a
`PRIVATE_KEY` and optional `CONTRACT_OWNER`. `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`;
`deployInbox()` needs the registry/verifier/remote service addresses, L2 identity, batch and forced
fee parameters, genesis commitments, epoch schedule and committee hashes, forced inclusion delay
and maximum anchor age. It has no reward-pool or allocation-share inputs.

`init(owner, params)` requires nonzero block-0 hash/state root and committee/config hashes,
`epochLenL2 >= 3`, `epochLenL2 + 1 <= type(uint48).max`, `epochLenL1 > 0`, a past cutoff at or after
the registry's first checkpoint, a nonzero forced delay, and `maxAnchorAge >= 1152` seconds.
The node must also enforce `d_max > margin_v`, `epochLenL2 >= d_max - margin_v + 3`, bounded
schedule arithmetic, and `1 <= n_max <= 4096`. These parameters must agree before deployment.

## Configuration and format boundaries

Keep the chain ID, Inbox, registry and authenticated config identical across execution, consensus,
lander and proof inputs. The immutable vault's L1 identity must match the actual Inbox deployment.
Validate the vault address against the EL treasury derivation rather than a freely configured
fee-vault address. Ordinary gas estimation, EIP-7825 transaction caps, priority fees and blob fees
retain their existing semantics; only base fees committed for the landed execution range pay here.

The coordinated format is envelope 6, blob payload 5, journal schema 10, APP_VERSION 3,
committee encoding version 2 and config domain `ETNA_PARENT_ANCHOR_V3`. Reject old persisted
or signed jobs explicitly. Do not rewrite an old signed journal or discard its transaction nonce
to make it appear current. No real Etna guest is included: dummy/accept-all proofs are explicit
local-devnet scaffolding and cannot establish consensus, execution or fee-sum soundness.

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
| 280     | forced inclusion `queue` mapping                       | entry `i` at `keccak256(abi.encode(i, 280))`       |
| 281     | forced inclusion `head`, `tail`                        | `uint48` bits 0–47, `uint48` bits 48–95            |
| 282     | `forcedInclusionDelay`, `maxAnchorAge`                 | `uint64` bits 0–63, `uint64` bits 64–127 (seconds) |
| 283     | `rewardCommitments` mapping                            | `bytes32 batchId => bytes32 commitment`            |
| 284–300 | `__gap`                                                | —                                                  |

Forced inclusion entry `i` starts at `base = keccak256(abi.encode(i, 280))`: `txHash`
(`bytes32`) occupies `base`; `timestamp` (`uint48`, bits 0–47), `l1Block` (`uint64`, bits 48–111)
and `feeInGwei` (`uint64`, bits 112–175) share `base + 1`. The timestamp and block number come
from the L1 submission. Consumed entries remain stored.

`saveForcedInclusion(bytes tx)` requires active status and at most `MAX_FORCED_TX_BYTES = 8192`
bytes, stores `keccak256(tx)` and emits `ForcedInclusionSaved(uint48 indexed index, bytes tx)`.
Admission does not validate encoding or execution: empty/undecodable bytes are invalid forced
input under the consumption rule. `getCurrentForcedInclusionFee()` returns Gwei;
`getForcedInclusionState()` returns `(head, tail)`; `getForcedInclusions(start, maxCount)` returns
pending entries only, and returns an empty array outside `[head, tail)` or for zero `maxCount`.

A proposer retrieves the original bytes with `eth_getLogs` filtered to the proven `l1Block`,
Inbox address, event signature and indexed queue index. Decode the event and verify its bytes
against the proven `txHash` before caching or using them. No receipt proof is needed because
the storage proof authenticates the expected hash. Before due, this read is optional and bounded
to preserve time for an ordinary block: missing, inconsistent, oversized or unavailable event data,
read errors and timeouts may fall back to an ordinary block with empty witness `tx` bytes. The entry
proof remains mandatory under the candidate's anchor, and nonempty witness bytes remain
authenticated. At or after due, acquisition failure never permits retaining the cursor: the block
must include or legally skip the entry under the rules below. Cached bytes must match the selected
anchor and proven entry identity. Validators and cold replay authenticate an included transaction
directly from execution-block position zero; only skips need the separate preimage in the forced
witness. Neither path fetches submission calldata or logs during validation.

`migrationState()` retains its name as a compatibility getter for the ABCI status word.
It exposes no migration state machine. `activation()` returns the genesis record.

### `EtnaStakingRegistry`

All state lives in the ERC-7201 namespace `taiko.etna.registry`, at base slot
`R = keccak256(abi.encode(uint256(keccak256("taiko.etna.registry")) - 1)) & ~bytes32(uint256(0xff))`
`= 0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000`.

| Slot     | Content                                                                                 |
| -------- | --------------------------------------------------------------------------------------- |
| `R`      | `checkpoints.length`                                                                    |
| `R + 1`  | `entries.length` (the entry index is the bond id)                                       |
| `R + 2`  | `bondOwner`: `mapping(uint256 bondId => address)`                                       |
| `R + 3`  | `withdrawn`: `mapping(uint256 bondId => bool)`                                          |
| `R + 4`  | `keyHolder`: `mapping(bytes32 pubkey => uint256)`, the latest holder's bond id plus one |
| `R + 5`  | `tree`: `mapping(uint256 node => bytes32)`, the Merkle nodes                            |
| `R + 6`  | `freeSlots`: withdrawn bond ids awaiting reuse (contract-internal)                      |
| `R + 7`  | `bondedStake`: stake of entries whose exit was not requested (contract-internal)        |
| `R + 8`  | activation churn: one past the latest scheduled window (contract-internal)              |
| `R + 9`  | activation churn: the latest scheduled window's remaining capacity (contract-internal)  |
| `R + 10` | exit churn: one past the latest scheduled window (contract-internal)                    |
| `R + 11` | exit churn: the latest scheduled window's remaining capacity (contract-internal)        |
| `R + 12` | `registrationOwner`: `mapping(bytes32 key => address)` (contract-internal)              |

| Word                        | Content                                                                  | Packing                                      |
| --------------------------- | ------------------------------------------------------------------------ | -------------------------------------------- |
| `keccak256(R) + 2i`         | `checkpoints[i].l1Block`, `checkpoints[i].count`                         | `uint64` bits 0–63, `uint32` bits 64–95      |
| `keccak256(R) + 2i + 1`     | `checkpoints[i].entriesRoot`                                             | `bytes32`                                    |
| `keccak256(R + 1) + 4j`     | `entries[j].pubkey`                                                      | `bytes32`                                    |
| `keccak256(R + 1) + 4j + 1` | `entries[j].effStake` (TAIKO base units)                                 | `uint256`                                    |
| `keccak256(R + 1) + 4j + 2` | `activeFromL1`, `exitEffectiveL1`, `lastHeartbeatAt`, `lastHeartbeatSeq` | `uint64` bits 0–63, 64–127, 128–191, 192–255 |
| `keccak256(R + 1) + 4j + 3` | `entries[j].rewardRecipient`                                             | `address` bits 0–159                         |

`rewardRecipient` is the nonzero L2 reward address fixed at registration; it does not grant
bond-owner permissions. `exitEffectiveL1 = type(uint64).max` means no exit was requested. Entry leaf `j` is
`keccak256(abi.encode(bytes32("ETNA_REG_ENTRY_V2"), uint256(j), pubkey, effStake, activeFromL1,
exitEffectiveL1, lastHeartbeatAt, lastHeartbeatSeq, rewardRecipient))`. `entriesRoot` over `count` entries pads the
leaves with zero leaves to the next power of two and hashes pairs as `keccak256(left ‖ right)`;
one entry gives leaf 0 and no entry gives `bytes32(0)`. At most 4096 slots exist. A bond id
names a slot: after a bond is withdrawn, the next registration overwrites its entry, takes over
its id and keeps `count` unchanged. Snapshots read entries at a historical L1 block and verify them
against that checkpoint's root, so slot reuse is invisible to committee derivation. The node reads
only `R` through `R + 5`.

Registration also records its caller as the owner of the registration, under the key
`keccak256(abi.encode(bondId, activeFromL1))`. Slot reuse adds a new key and keeps the old one, so
`registrationOwnerOf(bondId, activeFromL1)` names the owner of the registration a committee member
came from, while `bondOwnerOf(bondId)` names the slot's current holder. Two registrations of one
slot share a key only when the activation, exit and withdrawal delays are all 0; the second then
reverts `RegistrationKeyTaken`.

## Contract obligations

- Initialization writes the genesis record, status 3, `genesisCutoff`, `genesisCommitteeRecordHash`,
  `committeeConfigHash`, `forcedInclusionDelay`, `maxAnchorAge` and
  `lastCheckpoint = (0, H*)`, and saves `(0, H*, S*)` in SignalService.
- The forced inclusion head only moves in a verified landing, to the cursor the statement binds,
  within the bounds in Landing. The proof guarantees that after every landing `head` equals the L2
  cursor at `lastCheckpoint.height`; both start at 0. Consumed entries stay in storage.
- `genesisCommitteeRecordHash` must be the record hash derived by the node at `genesisCutoff`: active entries
  with at least `max(s_min, vp_unit)`, lowest bond id per pubkey, top `n_max` by stake, and no
  heartbeat filter. The contract accepts the deployer's supplied record; the node verifies it.
  With slot reuse the lowest bond id is not always the earliest registration; it is a
  deterministic tie-break, and since registration keeps at most one non-exited entry per pubkey,
  the deduplication is defence in depth.
- Each L1 block changing an entry ends with one checkpoint. Same-block mutations overwrite the
  latest checkpoint; its `count` and root cover all used slots, including exited and withdrawn
  entries not yet reused.
- Registration rejects a key held by any entry whose exit is not yet effective. A key whose last
  holder's slot was reused by another key is free. The node also deduplicates eligible keys
  defensively.
- Registration reuses the most recently withdrawn slot before appending, so the 4096 capacity
  bounds entries holding stake at once. A withdrawn entry stays in its slot, exit effective, until
  it is overwritten.
- With a non-zero `churnWindow`, each window has an activation capacity and a separate exit
  capacity of `max(minChurnPerWindow, bondedStake · churnBps / 10000)`, scheduled as in EIP-7251:
  a request consumes capacity from the latest scheduled window on and takes effect at the start of
  the window where it is fully absorbed. A request larger than one window takes effect in full at
  once, so the limit bounds the average rate, not each window. Exits queue from
  `block.number + exitDelay` and never take effect before `activeFromL1 + exitDelay`. One large
  request delays everyone queued behind it for as long as its stake stays locked. Committee
  selection stays top `n_max` by stake.
- Future committees derive from the committed switch-parent anchor. There is no `committee(epoch)` getter,
  mapping, committee landing output or publication event. Landing is never an activation gate.

## Authenticated committee configuration

The canonical commitment is the eleven-word encoding (352 bytes):

```solidity
committeeConfigHash = keccak256(abi.encode(
    bytes32("ETNA_PARENT_ANCHOR_V3"), uint256(l2ChainId), address(stakingRegistry),
    uint256(vpUnit), uint256(sMin), uint64(nMax),
    uint64(heartbeatWindow), uint64(2), uint8(2),
    uint64(dMax), uint64(marginV)
));
```

Words 8 and 9 bind heartbeat lookahead 2 and committee record encoding version 2, which fixes the
membership, member-order and set-root rules. The last two bind the back-pressure parameters `d_max`
and `margin_v`, so every node of a chain must run the same unsettled cap; a node whose cap differs
cannot open the stored hash.
Supply this nonzero hash as `COMMITTEE_CONFIG_HASH` at deployment. Slot 269 remains an opaque
commitment; the node/guest must open it against its configured parameters and persist/check it
in authenticated genesis state. Authenticate `L1_0`, both epoch lengths and `genesisCutoff` from
Inbox storage independently. No lag or grid parameter belongs to this configuration.

Committee 0 alone uses the explicit `genesisCutoff` and plain slot-278 bootstrap record; slot 279
retains that cutoff. For every target epoch `t >= 1`, with checked arithmetic:

```text
H(t) = 1 + t * epochLenL2
S(t) = H(t) - 2
D(t) = H(t) - 3
snapshot(t) = committed EL block D(t)'s anchor.number
```

At switch `S(t)`, registry proofs use exactly the committed parent's anchor root and number,
never the candidate's new anchor or a fresh finalized head. Select the latest registry checkpoint,
authenticate its complete entry count/root, and evaluate `active_from <= snapshot < exit_effective`
at the parent anchor number, rather than the checkpoint's mutation height. Keep effective stake,
the lowest eligible bond id per pubkey, `nMax` ranking, voting-power division and existing overflow
caps, and list members in set-key order: ascending by
`keccak256(abi.encode(bytes32("ETNA_SET_KEY"), l2ChainId, pubkey))` of each member's consensus
public key. The committee's set root is the Merkle root over the members in that order. Existing
anchor progress ensures runtime anchors are at least `L1_0`, which is strictly after
`genesisCutoff`; no extra runtime genesis floor is needed.

The set becomes certain only after `D(t)` commits and offers less guaranteed advance notice than
fixed cutoffs. Different valid L2 anchor histories may select different sets; replaying the same
committed parent derives the same set. An empty set at that immutable snapshot halts at `S(t)`;
later registry updates cannot repair that parent and no advancing-snapshot/old-set fallback exists.
Outgoing-quorum, old-key/stake-retention/withdrawal and recovery-bootstrap limits remain.

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
  `lastHeartbeatAt` is at or after a window start it computes from its schedule: for epoch `e`'s
  committee, the start of the window before the one holding the first L1 block of epoch `e - 2`
  (or the snapshot block, if earlier). Epochs `e_0` to `e_0 + 2` apply no heartbeat filter.

The V2 set leaf appends the immutable L2 payout address:

```solidity
keccak256(abi.encode(bytes32("ETNA_SET_LEAF_V2"), uint256(l2ChainId), uint256(setVersion),
    uint256(index), pubkey, uint256(effStake), address(rewardRecipient)))
```

Set version is `k = targetEpoch - E0 + 1`, with `E0 = 0`; record epoch 7 therefore uses
set version 8. Inner nodes retain `ETNA_SET_NODE`, chain ID, set version, left and right ABI words. An odd last
node is promoted unchanged; an empty set root is zero and cannot authorize a committee. The
nine-word record uses `ETNA_COMMITTEE_V2`, chain ID, target epoch, cutoff L1 block, checkpoint
index, set root, total stake, total power and `uint8(2)`. The recipient is authenticated through
the set root while consensus public keys, power and set-key ordering retain their rules.

## Landing

```solidity
function land(LandInput calldata input, bytes calldata proof) external;
```

`LandInput` is `(uint64 lastHeight, bytes32 lastBlockHash, bytes32 lastStateRoot,
uint64 l1ReferenceBlockNumber, uint48 forcedInclusionHead, address feeRecipient,
address l2RewardRecipient, uint256 baseFeeAmount)`. Both recipients must be nonzero, including
for zero fees. `feeRecipient` receives only consumed L1 forced inclusion fees. The guest derives
`l2RewardRecipient` from the authenticated proposer of the final execution block and proves
`baseFeeAmount = sum(header.baseFeePerGas * header.gasUsed)` over `(parentHeight, lastHeight]`.

Landing requires active status, `parentHeight < lastHeight <= parentHeight + maxBatchBlocks`,
`lastHeight <= type(uint48).max`, ordered queue progress within the tail, at most one consumed
entry per new block, a past reference with an available block hash, and at least one blob. The
V8 statement contains exactly twenty ABI words / 640 bytes:

```solidity
keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V8"),
    block.chainid, l2ChainId, address(this), address(stakingRegistry),
    recoveryGeneration, parentHeight, parentHash, committeeConfigHash,
    lastHeight, lastBlockHash, lastStateRoot,
    l1ReferenceBlockNumber, l1ReferenceBlockHash,
    keccak256(abi.encodePacked(blobHashes)),
    forcedInclusionHeadBefore, forcedInclusionHeadAfter, feeRecipient,
    l2RewardRecipient, baseFeeAmount
))
```

Identities, generation, config, stored parent and queue head before come from the Inbox;
reference hash and ordered blobs come from L1 execution. `hashLandStatement` is an encoder,
so call through the proxy to bind that proxy's address; it does not authenticate arbitrary inputs.
After verification the Inbox atomically records the checkpoint, receipt and queue progress,
saves the SignalService checkpoint, and transfers consumed forced inclusion fees to `feeRecipient`.
Any failure rolls back all state. The recipient cannot reenter `land` or `saveForcedInclusion`.
No participation arrays, settlement lists, payable donation or L1 prover reward ledger remain.

The batch identity and receipt are independent of the caller and of proof timing:

```solidity
batchId = keccak256(abi.encode(bytes32("ETNA_L2_REWARD_BATCH_V1"),
    l1ChainId, l2ChainId, inbox, generation, parentHeight, parentHash, lastHeight, lastBlockHash));
commitment = keccak256(abi.encode(bytes32("ETNA_L2_REWARD_RECEIPT_V1"),
    batchId, l2RewardRecipient, baseFeeAmount));
receiptSlot = keccak256(abi.encode(batchId, uint256(283)));
```

A zero-fee batch still records a nonzero commitment. Copying a proof cannot redirect either
recipient. Changed reward recipient or amount changes the V8 statement and commitment while
retaining the same batch ID. Existing V7 and older landing formats are incompatible.

### Guest and consensus obligations

Every account proof must derive its trie path from the corresponding bound Inbox or registry
address. Authenticate storage under that proved account root and an authenticated L1 header.
Open `committeeConfigHash` exactly as above and authenticate the genesis schedule. Apply the
existing membership, lowest eligible bond id per key, stake ranking, set-key ordering, floor power
mapping and overflow rules at the authenticated snapshot. Keep heartbeat evaluation at the target
schedule instant with its two-epoch lookahead, capped at the snapshot window, including the nonzero
sequence guard and launch exemptions for epochs 0, 1 and 2. The lookahead does not select a snapshot.

At switch `S(t)`, require exactly one committee witness for `t` under the committed parent's exact
anchor root and number. Compare every derived record field, derive before returning validator
updates at FinalizeBlock, and persist at Commit. CometBFT activates them at `H(t)` with H+2 timing.
Non-switch blocks carry no runtime committee witness; epoch-first blocks have no extra publication
requirement. The committed anchor already passed canonical/finalized checks, so deterministic
Finalize/replay must not introduce L1 calls.

For a batch starting after a switch, the checkpoint's newer anchor cannot reconstruct a starting
set. Authenticate the checkpoint EL header against the contract-bound parent hash, then the minimal
consecutive descending EL hash/parentHash links through `D(t)` for every needed current/next signing
epoch. Read each snapshot number only from that authenticated header's generation-checked Etna
anchor extraData. Include checkpoint `p-1` at nonzero `p` to authenticate the base-fee grandparent
timestamp. With `epochLenL2=10`, checkpoint 15 needs headers `15 -> ... -> 8`; committee 1 derives
from header 8. Checkpoint 10 needs outgoing bootstrap committee 0 and pending committee 1 from
header 8. A separate unproved derivation hint is never authoritative.

Current/next starting epochs differ by at most one. The earliest required derivation header is at
most `epochLenL2 + 2` links behind the checkpoint. Use checked bounds, existing I/O/journal limits
and only required ancestors, without re-executing historical transactions/commits or preallocating
from unbounded caller input. EL RPC and Comet envelopes are both usable sources because the hash
links authenticate the headers. Missing history reports the required height; transient RPC failures
remain retryable, while broken links/height/generation/anchor/config/record/entries reject.

A starting committee may use a later authenticated checkpoint-parent proving root whose L1 number
covers its derived snapshot. Under that root prove the last immutable registry checkpoint at/before
the snapshot, its successor after it when present, array length and complete historical entries/root.
This recovers the derivation-parent snapshot without original-root metadata MPT proofs; historical
entry values still require RPC/cache data. The guest independently checks retained EL ancestry and
per-epoch provenance and recomputes all parent/current/pending sets. In-batch switch proofs still use
the actual embedded committed parent's exact root and snapshot number.

Verify the parent certificate and every current/pending certificate, current validator hash and
`nextValidatorHash` across `S/S+1/H` and arbitrary cuts. Require strictly more than two-thirds voting
power from distinct signers under `taiko-etna-<l2ChainId>-g<generation>`. Prove execution ancestry
from the stored parent to terminal hash/state root and blob data. The bound blobs carry payload
V5, `0x05 || zlib(rlp([[header_proto, envelope], ...]))` in the existing blob coding, with each
block's canonical CometBFT header and Etna envelope: header hashes are the certified block ids,
`data_hash` commits to the envelope and `last_block_id` links the batch. Envelope v6 carries a
forced witness `[index, entryProof, tx]` when the anchor proves a pending entry. Proposers leave
`tx` empty for ordinary and included blocks and carry the separate preimage only for skips.
Landing still publishes batch blobs; forced transaction admission uses calldata bytes.
Commits and signatures are proof witnesses, not blob data.
Every anchor and actual proving L1 root belongs to the header chain ending at the reference hash.
Reference headers may be recent even for old batches. Arbitrary batch cuts never depend on an
earlier batch's committee output.

### Forced inclusion obligations

The L2 chain tracks a cursor `c(h)`, the number of entries consumed after block `h`; `c(0) = 0`.
Each block consumes at most one entry, exactly `c(h-1)`, or keeps the cursor when no entry is
pending or the pending entry is not yet due. For block `h` with committed parent cursor `c` and
candidate anchor `A` (its own anchor or the inherited one), read `tail(A)` from `A`'s state.
If `c >= tail(A)`, forbid a forced witness. Otherwise require exactly entry `c`'s
witness `[index, entryProof, tx]`, authenticate the Inbox account and both entry slots under
`A.stateRoot`, and enforce `tx.length <= 8192`. The witness's `tx` byte string may be empty:
pre-due peeks need no preimage, and inclusion authenticates execution-block transaction zero
instead. Nonempty witness bytes always require `keccak256(tx) == entry.txHash`, including
redundant bytes in historical envelopes. Before any due skip, require that hash equality even
for empty bytes: omission can only prove an actually empty admission, never skip a nonempty
entry. Authenticate entries and `tail` (slots 280–281) under `A` and `D` and `M` (slot 282) under
the genesis proof. Read `tail(A)` from each anchor, never genesis:
`saveForcedInclusion` can follow `init` in the same L1 block, so the queue need not be empty at
`L1_0`. Block 1 always carries its own anchor witness.

Due means `A.timestamp >= entry.timestamp + D`, evaluated with widened or checked arithmetic;
an overflowing timestamp-plus-delay is not yet due. There is no expiry, including after fourteen
days. Canonical means exactly one complete EIP-2718 transaction envelope, including legacy
transactions, whose decoding consumes all input and whose re-encoding reproduces the exact bytes.
Use the codec compatible with the pinned EL. Empty, undecodable or failed-round-trip bytes are
invalid forced input; do not duplicate signature, nonce, balance, gas or fee validation.
At or after due, a block that neither includes nor legally skips the entry is invalid; it cannot
retain the cursor. Log acquisition failure or an unavailable singleton verdict does not relax this
rule.

| Condition                                                                        | Action                                                                                                |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Canonical block transaction 0 is at most 8192 bytes and hashes to `entry.txHash` | Include; advance cursor by one, before or after due; no duplicate witness preimage needed.            |
| Not included, not due                                                            | Peek; keep the cursor; no preimage needed.                                                            |
| Not included, due, authenticated noncanonical/undecodable preimage               | Skip; advance cursor by one without an EL build.                                                      |
| Not included, due, authenticated canonical preimage                              | Require a successful singleton EL build with an empty transaction result, then advance cursor by one. |

Only position zero counts as inclusion. A different transaction with the same sender and nonce,
or the forced transaction at a later position, cannot justify skipping a transaction the singleton
build retains. Inclusion may share a block with later mempool transactions. An included transaction
may revert during EVM execution: receipt success is not part of the rule. Examples: a canonical
transaction first in a pre-due mixed block advances once; invalid bytes before due retain the
cursor; those same bytes at the due boundary skip once; age alone never consumes an entry.

For a canonical skip, build the singleton list `[tx]` on the same committed parent with the same
deterministic payload attributes as the candidate, changing only the provided list. Use the pinned
legacy provided-list behavior and a completed build result. A nonempty result rejects the skip.
Build errors, timeouts, unavailable parent state, cancellation and incomplete results never prove
invalidity and never authorize consumption. No semantic reason gets special deferral after due:
fee, nonce, balance, signature, unsupported-type, declared gas-limit and zk-gas failures all use
this rule. A combined forced-plus-mempool build can stop at zk-gas exhaustion; after a permitted
skip, rebuild an ordinary mempool block with its full budget instead of publishing an empty result
solely because that combined build stopped.

The whole candidate still passes normal header and EL payload validation. Every block requires
`block.timestamp - A.timestamp <= M` and the existing anchor, generation, back-pressure and
committee rules. A proposer with no finalized anchor fresh enough for `M` proposes nothing, so
a longer L1 finality stall pauses L2. ProcessProposal, hot/cold FinalizeBlock, proposer final-block
checking and lander validation must agree on the classification and completed singleton verdict.
Canonical skips need parent state; unavailable cold rebuilding remains an actionable
`forced_rebuild_unavailable` failure.

A future guest must enforce the same MPT, hash, exact canonical round-trip, position and due
checks and prove that the batch consumes exactly `[forcedInclusionHeadBefore,
forcedInclusionHeadAfter)` in order. An EL-dependent skip additionally needs an execution witness
and guest execution of the singleton list on the authenticated parent with the candidate's
attributes. `debug_executionWitnessForTxList` is the existing witness-generation entry point.
This change implements no real guest or prover, and dummy proofs do not establish soundness.
`feeRecipient` is a public input the guest binds but does not constrain.

The existing status, generation, anchor progress and back-pressure checks remain. In particular,
`height - checkpoint <= d_max - margin_v` can still stop block production during a landing
outage, and `epochLenL2 >= unsettledCap + 3` remains the schedule bound. Committee authorization
is autonomous, while landing progress still matters for overall liveness.

## L2 base-fee claims

The treasury receives EL base-fee credits without executing contract code. Its immutable
`l1ChainId` and `l1Inbox` are fixed in genesis runtime. Anyone submits:

```solidity
claim(Receipt receipt, uint256 anchorTimestamp, bytes[] accountProof, bytes[] storageProof)
```

`Receipt` carries the eight batch-identity fields plus recipient and amount (ten fields total). The vault requires its immutable L1 identity,
`block.chainid`, increasing heights and nonzero recipient. It reads the authenticated L1 state
root from EIP-4788 at `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` by raw 32-byte timestamp
with no function selector. The account proof authenticates the fixed Inbox account, then the
storage proof authenticates the exact slot-283 receipt commitment under that account's storage
root. Empty account proof, zero root and absent/mismatched storage are rejected.

After authentication the vault consumes `claimed[batchId]` and pays exactly the committed amount
to the committed recipient. A transfer failure reverts consumption so a later attempt can retry.
The reentrancy lock protects all claim paths, including callbacks, and repeated claims fail. A
zero amount consumes the receipt and emits `RewardClaimed` without calling the recipient. Extra
or forced Ether gives no new entitlement. Insufficient balance reverts and leaves the claim
retryable; funds are never shared by vote, swept wholesale or paid to the proof submitter.

The EIP-4788 roots ring retains 8191 timestamps. Claims may use any retained later authenticated
state root that still proves the immutable Inbox receipt; the receipt does not expire on L1.
L1 proofs and sufficient treasury funding are operational dependencies; no subsidy or bridge
keeper is introduced. Recovery must avoid recreating already-paid logical execution fees under
a new generation. New generation IDs prevent receipt collisions but do not alone prevent
cross-generation economic double payment; recovery coordination remains outside this change.

## Shared vectors and verification

`testdata/etna_vectors/generate.py` uses independent `cast` ABI/hash/slot commands. Its schema-2
JSON pins the V3 eleven-word config, recipient-bound registry leaves/four-word storage, V2 set
leaves and committee records, complete twenty-word V8 preimages, batch identity, commitment,
slot-283 location, exact land/claim selectors, and a zero-fee batch. Integers are decimal strings.
Set cases cover empty rejection input, singleton, odd-width and five-member trees.

Regenerate twice and compare SHA-256. Export runtime and build genesis twice with identical
explicit inputs and compare bytes; changing either L1 immutable must change runtime, and changing
L2 chain ID must change the treasury allocation. `EtnaGenesis.t.sol` installs the exported runtime
and canonical system bytecode in Foundry, uses the exact privileged system caller for writes,
reads roots/history and claims a real trie-proved receipt. The Python tests verify alloc-only
preservation, normalization, rejected ambiguity, runtime hash and deterministic JSON. These are
EVM/unit checks; they do not replace real EL custom-genesis activation/block execution acceptance.

Run from `packages/protocol`:

```bash
python3 test/layer2/core/test_etna_genesis.py
pnpm test:l1
pnpm test:l2
pnpm test:shared
```
