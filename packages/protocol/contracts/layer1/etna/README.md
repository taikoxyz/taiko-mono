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
   `genesisCutoff`, committee record hash, `committeeConfigHash`, forced inclusion delay and
   maximum anchor age. It deploys fresh SignalService and EtnaInbox proxies.
   The Inbox is initialized atomically in the proxy constructor and saves a block-0 checkpoint to
   SignalService. SignalService authorizes the predicted Inbox proxy address.
5. Once the L1 initialization block is final, run `abci-genesis` and start CometBFT and the EL.
   The first consensus block is L2 block 1. Configure the EL's Etna fork from genesis.

`init(owner, params)` requires non-zero genesis hash, state root, committee record hash and committee config hash;
`epochLenL2 >= 3`; `epochLenL1 > 0`; a past `genesisCutoff` at or after the registry's first
checkpoint; `forcedInclusionDelay > 0`; `maxAnchorAge >= 1152 seconds`; and
`forcedInclusionDelay + maxAnchorAge + 384 seconds <= 14 days`. It runs once;
implementation contracts have initializers disabled. SignalService must
authorize this proxy, or initialization reverts without retaining ownership or genesis state.

The genesis hash, state root, committee record and config hash are trusted bootstrap inputs. The deployer must
check that they match the L2 genesis file and the registry snapshot. The contract fixes
`genesisHeight = 0`; there is no freeze, drain, upgrade from an existing Inbox, or legacy bond exit.

The deployment script's NatSpec lists its environment variables. Both calls use `PRIVATE_KEY` and
optional `CONTRACT_OWNER`; `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`. `deployInbox()` needs
`STAKING_REGISTRY`, `REMOTE_SIGNAL_SERVICE` (L2), `ETNA_PROOF_VERIFIER`, `L2_CHAIN_ID`,
`MAX_BATCH_BLOCKS`, `FORCED_INCLUSION_FEE_GWEI`, `FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD`,
`GENESIS_BLOCK_HASH`, `GENESIS_STATE_ROOT`, `EPOCH_LEN_L2`, `EPOCH_LEN_L1`, `GENESIS_CUTOFF`,
`COMMITTEE_RECORD_HASH`, `COMMITTEE_CONFIG_HASH`, `FORCED_INCLUSION_DELAY` and `MAX_ANCHOR_AGE`
(both in seconds). Use the same deployer for the four consecutive CREATEs
of the Inbox deployment; the script predicts the final proxy using its current nonce.

No Etna guest exists yet, so a devnet's `EtnaInbox` uses a stand-in proof verifier such as the
accept-all `contracts/layer1/devnet/OpVerifier.sol`. As `land` is permissionless, anyone can then
land any batch and write arbitrary SignalService checkpoints (forged L2 to L1 messages), and move
the forced inclusion head to the tail to collect every pending fee without including the entries.
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
- Set a non-zero registry `churnWindow` outside throwaway devnets, together with `churnBps` and a
  `minChurnPerWindow` floor of at least `minStake`. Zero disables the churn limit. `bondedStake`
  starts at 0, so before genesis only the floor activates per window: register the genesis set
  early enough, or deploy with `churnWindow = 0` and enable the limit by an upgrade later
  (`bondedStake` is tracked either way). Upgrading a registry deployed before `bondedStake` existed
  must seed it first, or exits of older entries underflow.
- Size `minStake` so that holding all 4096 slots (`4096 · minStake` locked for as long as the slots
  are held) is prohibitive.
- The genesis snapshot must contain live eligible validators. A cutoff close to the L1
  initialization block reduces the chance of entries exiting or going offline before startup.
- `forcedInclusionFeeInGwei` and `forcedInclusionFeeDoubleThreshold` are non-zero implementation
  immutables. As in Shasta, a new entry costs
  `forcedInclusionFeeInGwei * (threshold + pending) / threshold` Gwei (rounded down), so the fee
  doubles once `threshold` entries are pending. The landing that consumes an entry pays its fee to
  the `feeRecipient` that landing names. Size the fee to what an entry costs the lander: each
  forced inclusion block re-publishes the entry's whole 128 KiB blob in the landing blobs (about
  one extra landing blob, paid by the lander), and each due entry takes its own L2 block. The base
  fee should cover about one to two landing blobs plus the entry's storage proof, which also
  travels in the landing blobs, and the doubling threshold should be small.
- `forcedInclusionDelay` (seconds) is fixed at genesis in slot 282; the node and guest read it
  from storage. An entry is due at an L2 block whose anchor timestamp is at least the entry's
  timestamp plus the delay; before that, validators may include it early. Initialization requires
  `D > 0`, `M >= 1152 seconds` and `D + M + 384 seconds <= 14 days`, where `D` is the delay and
  `M` is the maximum anchor age. Thus `M <= 14 days - D - 384 seconds`. The 384-second margin is
  one Ethereum epoch (32 slots of 12 seconds), leaving room for a normal finalized-anchor update
  before expiry. Merely requiring `D < 14 days` admits a due window shorter than an L1 slot or
  an anchor update, so the first due anchor can already expire the entry and discard its list.
  The coupled bound also prevents a stale anchor from staying not due until the block timestamp
  reaches `entry.timestamp + 14 days` while satisfying the freshness rule.
- `maxAnchorAge` (seconds) is fixed at genesis in slot 282. Every L2 block requires
  `block.timestamp - anchor.timestamp <= maxAnchorAge`. Its 1152-second minimum budgets three
  Ethereum epochs for normal finality lag; this is a deployment safeguard, not an upper bound
  on actual finality lag. Choose it above the expected lag, including `l1_finality_extra_depth`,
  RPC latency and the desired stall tolerance, while respecting the coupled expiry bound.
  An L1 finality stall longer than it pauses L2 until finality resumes. The rule bounds how
  far a block's anchor trails the block's derived timestamp, not real time: a pending entry is due
  at any block whose timestamp has reached `entry.timestamp + forcedInclusionDelay + maxAnchorAge`,
  so a longer value delays forced transactions more. Block timestamps follow BFT time, which a
  large enough coalition can hold back (see Open items). The proposed default is 2 hours; Ethereum
  finality stalls have lasted about an hour.
- These parameter checks reserve a usable window under normal anchor and block progress. They
  do not guarantee inclusion during a long L1/L2 outage, when earlier queued entries cannot be
  drained before expiry, or when a voting coalition holds BFT time back. The 384-second margin
  is a normal anchor update budget, not a bound on finality stalls or missed checkpoint slots.
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
| 280     | forced inclusion `queue` mapping                       | entry `i` at `keccak256(abi.encode(i, 280))`       |
| 281     | forced inclusion `head`, `tail`                        | `uint48` bits 0–47, `uint48` bits 48–95            |
| 282     | `forcedInclusionDelay`, `maxAnchorAge`                 | `uint64` bits 0–63, `uint64` bits 64–127 (seconds) |
| 283–300 | `__gap`                                                | —                                                  |

Forced inclusion entry `i` starts at `base = keccak256(abi.encode(i, 280))`: `feeInGwei` (`uint64`
bits 0–63) at `base`, `blobHashes.length` (always 1) at `base + 1`, `offset` (`uint24` bits 0–23)
and `timestamp` (`uint48` bits 24–71) at `base + 2`, and `blobHashes[0]` at `keccak256(base + 1)`.

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
one entry gives leaf 0 and no entry gives `bytes32(0)`. At most 4096 slots exist. A bond id
names a slot: after a bond is withdrawn, the next registration overwrites its entry, takes over
its id and keeps `count` unchanged. Snapshots read entries at a historical L1 block and verify them
against that checkpoint's root, so slot reuse is invisible to committee derivation. The node reads
only `R` through `R + 5`.

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

The canonical commitment is the nine-word encoding (288 bytes):

```solidity
committeeConfigHash = keccak256(abi.encode(
    bytes32("ETNA_PARENT_ANCHOR_V1"), uint256(l2ChainId), address(stakingRegistry),
    uint256(vpUnit), uint256(sMin), uint64(nMax),
    uint64(heartbeatWindow), uint64(2), uint8(1)
));
```

The last words bind heartbeat lookahead 2 and retained membership/MEM-08 algorithm version 1.
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
the lowest eligible bond id per pubkey, `nMax` ranking, MEM-08 order/root, voting-power division and
existing overflow caps. Existing anchor progress ensures runtime anchors are at least `L1_0`,
which is strictly after `genesisCutoff`; no extra runtime genesis floor is needed.

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
  `lastHeartbeatAt` is at or after a window start it computes from its schedule (`MEM-13`).
  Epochs `e_0` to `e_0 + 2` apply no heartbeat filter.

## Landing

`LandInput` has exactly `lastHeight`, `lastBlockHash`, `lastStateRoot`, `l1ReferenceBlockNumber`,
`forcedInclusionHead`, the forced inclusion cursor after the batch, and `feeRecipient`, the
receiver of the consumed entries' fees. With `p` and `parentHash` the stored checkpoint and `head`,
`tail` the stored queue, `land` requires active status, `p < lastHeight <= p + maxBatchBlocks`,
`lastHeight <= type(uint48).max` and a non-zero `feeRecipient` (`ZeroFeeRecipient` otherwise,
whether or not the batch consumes entries). It also requires `head <= forcedInclusionHead <= tail`
and `forcedInclusionHead - head <= lastHeight - p`, since each forced inclusion is its own block;
otherwise it reverts `InvalidForcedInclusionHead`. The reference must be a past L1 block with a
nonzero hash available from `blockhash` (256 blocks) or the EIP-2935 history contract (8191
blocks). At least one transaction blob is required.

Landing saves the terminal checkpoint in the Inbox and SignalService, moves `head` to
`forcedInclusionHead`, emits `BatchLanded`, and calls
`proofVerifier.verifyProof(0, statementHash, proof)`. Failure rolls back all writes. Only after
verification, and only if the head moved, does it pay the consumed entries' fees,
`sum(queue[i].feeInGwei) * 1 gwei` for `i` in `[head, forcedInclusionHead)`, to `feeRecipient`,
not `msg.sender`, and emit `ForcedInclusionsConsumed(headBefore, headAfter, feesWei, recipient)`.
A recipient that rejects the payment fails the landing. `land` and `saveForcedInclusion` share one
reentrancy lock, so the recipient cannot re-enter either. The statement binds `feeRecipient`, so
whoever copies a public landing transaction (calldata and blob sidecar) and lands it first still
pays the original recipient, and a copy naming another recipient fails verification. The
eighteen-word V6 preimage (576 bytes) is:

```solidity
statementHash = keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V6"),
    block.chainid, l2ChainId, address(this), address(stakingRegistry),
    recoveryGeneration, p, parentHash, committeeConfigHash,
    lastHeight, lastBlockHash, lastStateRoot,
    l1ReferenceBlockNumber, l1ReferenceBlockHash,
    keccak256(abi.encodePacked(blobHashes)),
    forcedInclusionHeadBefore, forcedInclusionHeadAfter, feeRecipient
));
```

The two heads are `uint48`: `forcedInclusionHeadBefore` is the stored `head` and
`forcedInclusionHeadAfter` is `LandInput.forcedInclusionHead`; `feeRecipient` is the `address`
from `LandInput`. Both identities, config hash, generation, parent and head before come from the
contract. The reference hash and ordered blob hashes come from the actual L1 execution context.
`hashLandStatement` derives identities and config internally but accepts raw generation, parent,
head before and terminal inputs for encoding; it does not authenticate them. Call it through the
proxy to bind that proxy's address. V5 digests, seventeen-word V6 digests without `feeRecipient`,
four- and five-field `LandInput`s, fixed-cutoff configuration openings, envelope-3 histories, V2
blob payloads and journal-schema-4 jobs are incompatible with this prelaunch version. The envelope
version is 4, the blob payload version 3 and the journal schema 5; record encoding stays 1. No
deployed-chain migration is provided. Reject old signed jobs without discarding their nonce,
cancelling or automatically replacing their transaction.

### Guest and consensus obligations

Every account proof must derive its trie path from the corresponding bound Inbox or registry
address. Authenticate storage under that proved account root and an authenticated L1 header.
Open `committeeConfigHash` exactly as above and authenticate the genesis schedule. Apply the
existing membership, lowest eligible bond id per key, stake ranking, MEM-08 ordering, floor power
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
V3, `0x03 || zlib(rlp([[header_proto, envelope], ...]))` in the existing blob coding, with each
block's canonical CometBFT header and Etna envelope: header hashes are the certified block ids,
`data_hash` commits to the envelope and `last_block_id` links the batch. A forced inclusion block's
envelope carries its entry's whole blob. Commits and signatures are proof witnesses, not blob data.
Every anchor and actual proving L1 root belongs to the header chain ending at the reference hash.
Reference headers may be recent even for old batches. Arbitrary batch cuts never depend on an
earlier batch's committee output.

### Forced inclusion obligations

The L2 chain tracks a cursor `c(h)`, the number of entries consumed after block `h`; `c(0) = 0`. A
forced inclusion block consumes exactly entry `c(h-1)` and sets `c(h) = c(h-1) + 1`; every other
block keeps the cursor. Genesis initialization enforces `D > 0`, `M >= 1152 seconds` and
`D + M + 384 seconds <= E`, with `D = forcedInclusionDelay`, `E = 14 days` and `M = maxAnchorAge`.
The 384-second margin reserves one normal Ethereum finalized-anchor update before expiry.
Deployment must additionally budget extra finality depth, RPC delay and expected queue throughput.

For block `h` with parent cursor `c` and anchor `A` (its own anchor or the inherited one), with
`tail(A)` the queue tail in `A`'s state:

- Entry `c` is due iff `c < tail(A)` and `A.timestamp >= entry.timestamp + D`, and expired iff
  `c < tail(A)` and `A.timestamp >= entry.timestamp + E`.
- If entry `c` is due, block `h` must be a forced inclusion block for entry `c`. If it is pending
  but not due, block `h` may include it early or be ordinary. If `c >= tail(A)`, block `h` must be
  ordinary. Skipping or reordering entries is invalid.
- Every block, forced or ordinary, requires `block.timestamp - A.timestamp <= M`, with the
  timestamp the existing rules derive. A proposer whose newest finalized anchor is older than `M`
  proposes nothing, so an L1 finality stall longer than `M` pauses L2.
- A forced inclusion block keeps the ordinary header, anchor, generation, back-pressure and
  committee rules and carries the entry's witness. Its transactions are exactly what the EL
  produces with `execute_provided_transactions` from the entry's list: it skips undecodable or
  unrecoverable transactions, unsupported types, invalid transactions and those whose gas limit
  exceeds the remaining block gas, and stops at zk gas exhaustion.

Reject an entry whose proven `blobHashes` length is not exactly 1; the store never writes one, so
this is defence in depth. The list of a non-expired entry comes from its blob `B`: require
`kzg_to_versioned_hash(blob_to_kzg_commitment(B)) == entry.blobHashes[0]`, decode the blob as Shasta
derivation does, and decode Shasta's forced inclusion `DerivationSourceManifest` at `entry.offset`
with at most one block, stopping decompression at 1 MiB. A manifest with exactly one block gives
that block's `transactions` and ignores its other fields; any other manifest (default, zero or
several blocks, over the cap) gives an empty list. An expired entry gives an empty list and needs
no blob. The EL `txList` is the RLP list of those transactions.

The guest checks, per block, these rules, the witness presence rules, the KZG binding, the list
derivation and the EL semantics, and that the batch consumes exactly entries
`[forcedInclusionHeadBefore, forcedInclusionHeadAfter)` in order. Entry facts and `tail` are
authenticated by storage proofs (slots 280–281) under anchors already authenticated by the
reference header chain; `D` and `M` (slot 282) under the genesis proof. Read `tail(A)` from each
anchor's state, never from genesis: `saveForcedInclusion` can follow `init` in the same L1 block,
so the queue need not be empty at `L1_0`. Block 1 always carries its own anchor witness.
`feeRecipient` is a public input the guest binds but does not constrain.

The existing status, generation, anchor progress and back-pressure checks remain. In particular,
`height - checkpoint <= d_max - margin_v` can still stop block production during a settlement
outage, and `epochLenL2 >= unsettledCap + 3` remains the schedule bound. Committee authorization
is autonomous, while settlement progress still matters for overall liveness.

The fixed Solidity vector pins the six-field ABI, nine-word config and V6 statement against an
independent `cast abi-encode` encoding. Tests use an explicitly dummy verifier for batching,
statement binding and rollback; they do not prove the authoritative guest rules. Dummy proof
`0x00` remains explicit; no real ZK guest is part of this change, and host/contract integration
checks do not establish production ZK soundness. Empty-roster liveness and old-key/withdrawal
assumptions remain unchanged.

## Open items

- The Etna guest is a follow-up; the blob encoding and lander are in #22280. No prover rewards, slashing or stall
  recovery exist here; `recoveryGeneration` stays 0. The staking withdrawal delay must cover the
  evidence and landing windows once slashing is introduced.
- Registry capacity: withdrawn slots are reused, so cycling registration and exit no longer
  consumes capacity. Holding all 4096 slots still blocks new registrations for as long as
  `4096 · minStake` stays locked; `minStake` sizing is the bound. A slot whose owner exits but
  never withdraws stays occupied.
- No Ed25519 proof of possession is required for registration.
- The spec's separate heartbeat key, signed payload and relayed heartbeats are not implemented;
  the bond owner heartbeats directly. Epochs 0, 1 and 2 have no heartbeat eligibility filter.
- Forced inclusion is enforced only by the guest and by honest validators; no guest exists yet,
  so a stand-in verifier lets any lander skip entries and collect their fees.
- Anchor freshness does not keep block timestamps up with real time. Etna enables no
  proposer-based timestamps (PBTS), so BFT time is the voting-power-weighted median of the
  precommit timestamps a proposer includes in its block's last commit. A coalition with more than
  1/2 of the voting power sets that median outright. One with more than 1/3 can too: it withholds
  its votes from honest proposals, so only its own proposals are decided, and includes in them
  only enough honest precommits to clear 2/3 (the exact threshold lies between 1/3 and 1/2,
  depending on stake granularity). Either coalition can hold block timestamps back and, while
  satisfying freshness, keep anchors stale and delay forced inclusions; each block still advances
  the timestamp by at least one second. A delay that reaches the 14-day expiry becomes a drop: the
  entry is then consumed by an empty block. Freshness only bounds anchor lag relative to the
  derived block timestamp, and pauses L2 during L1 finality stalls longer than `maxAnchorAge`.
  A validator-local clock check (PBTS-style timeliness) would raise the bound; it is an open,
  launch-blocking decision and is not implemented. An L1-clock check at landing would instead
  make batches delayed by a long lander outage unlandable.
- An L2-to-L1 fee sweep remains separate work.
