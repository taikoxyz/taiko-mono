# Etna contracts

Etna starts as a new proof-of-stake chain at L2 block 0. A committee of TAIKO stakers orders and
signs L2 blocks with CometBFT, and anyone can land proven batches on L1.

| Contract                           | Role                                                                                                |
| ---------------------------------- | --------------------------------------------------------------------------------------------------- |
| `impl/EtnaInbox.sol`               | A fresh UUPS proxy initialized with L2 genesis and committee 0; lands proven batches.               |
| `impl/EtnaStakingRegistry.sol`     | Validators stake TAIKO, heartbeat, exit and withdraw. Its checkpoints define committees.            |
| `impl/EtnaRewardPool.sol`          | Receives swept L2 fees and splits them to validators and provers once an epoch's last commit lands. |
| `libs/LibEntriesTree.sol`          | The incremental Merkle tree behind the registry checkpoints.                                        |
| `../../layer2/core/L2FeeVault.sol` | The L2 fee recipient; anyone can sweep its whole balance to the reward pool.                        |

The ABCI node in taikoxyz/taiko-mono#22280 reads the Inbox and registry with EIP-1186 proofs.
Its interface is `crates/abci/src/l1/layout.rs`. This PR preserves that storage interface; it
implements no Shasta-to-Etna migration. The protocol specification is #22262; Fees and rewards
lists where the fee loop departs from it.

## Genesis initialization

1. Deploy the staking registry with `DeployEtnaDevnet.run()`. Validators register, then wait for
   their activation delay and L1 finality.
2. Choose a finalized registry snapshot at `genesisCutoff` and compute committee 0 with
   `taiko-client abci-committee-record`. At least one validator must be eligible there.
3. Prepare the L2 genesis file, including the fee vault or its planned deployment, and obtain its
   block-0 hash and state root. Set the node's fee-vault address consistently. The vault's
   immutable constructor inputs are the L2 Bridge, the L1 chain id and the L1 reward pool proxy,
   and the pool in turn names the vault's L2 address, so fix both addresses before either is
   deployed. If the genesis contracts embed L1 addresses, as a genesis vault does, predict them
   before computing that hash: for deployment-wallet nonce `n`, the L1 SignalService proxy is
   CREATE at `n + 1`, the Inbox proxy at `n + 3` and the reward pool proxy at `n + 5`. Keep the
   wallet's nonce unchanged until `deployInbox()` runs.
4. Call `DeployEtnaDevnet.deployInbox()` with the genesis hash, state root, epoch lengths,
   `genesisCutoff`, committee record hash, `committeeConfigHash`, forced inclusion delay and
   maximum anchor age, and the reward inputs: the L1 Bridge, the L2 fee vault, both allocation
   shares and the landing reward per block. It deploys fresh SignalService, EtnaInbox and
   EtnaRewardPool proxies. The Inbox is initialized atomically in the proxy constructor and saves
   a block-0 checkpoint to SignalService. SignalService authorizes the predicted Inbox proxy
   address, the Inbox implementation names the predicted pool proxy, and the pool, created last,
   names the Inbox proxy.
5. Once the L1 initialization block is final, run `abci-genesis` and start CometBFT and the EL.
   The first consensus block is L2 block 1. Configure the EL's Etna fork from genesis.

`init(owner, params)` requires non-zero genesis hash, state root, committee record hash and committee config hash;
`3 <= epochLenL2 <= 429,496`; `epochLenL1 > 0`; a past `genesisCutoff` at or after the
registry's first checkpoint; `forcedInclusionDelay > 0`; and `maxAnchorAge >= 1152 seconds`. Neither parameter has
an expiry-derived upper bound. Initialization runs once; implementation contracts have initializers disabled. SignalService must
authorize this proxy, or initialization reverts without retaining ownership or genesis state.
The node bounds the epoch lengths and its unsettled cap further; see Configuration checks.

The genesis hash, state root, committee record and config hash are trusted bootstrap inputs. The deployer must
check that they match the L2 genesis file and the registry snapshot. The contract fixes
`genesisHeight = 0`; there is no freeze, drain, upgrade from an existing Inbox, or legacy bond exit.

The deployment script's NatSpec lists its environment variables. Both calls use `PRIVATE_KEY` and
optional `CONTRACT_OWNER`; `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`. `deployInbox()` needs
`STAKING_REGISTRY`, `REMOTE_SIGNAL_SERVICE` (L2), `ETNA_PROOF_VERIFIER`, `L2_CHAIN_ID`,
`MAX_BATCH_BLOCKS`, `FORCED_INCLUSION_FEE_GWEI`, `FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD`,
`GENESIS_BLOCK_HASH`, `GENESIS_STATE_ROOT`, `EPOCH_LEN_L2`, `EPOCH_LEN_L1`, `GENESIS_CUTOFF`,
`COMMITTEE_RECORD_HASH`, `COMMITTEE_CONFIG_HASH`, `FORCED_INCLUSION_DELAY` and `MAX_ANCHOR_AGE`
(both in seconds), plus the pool's `L1_BRIDGE`, `L2_FEE_VAULT`, `ALLOC_VALIDATOR_PPM` and
`ALLOC_PROVER_PPM` (shares of the free balance per frozen epoch, summing to at most 1,000,000) and
`PROPOSER_BONUS_PPM` (the part of each validator share paid as proposer bonus, at most 1,000,000;
300,000 on devnets, see Proposer bonus) and the Inbox's `LANDING_REWARD_PER_BLOCK` (wei, may be
0). Use the same deployer for the six
consecutive CREATEs of the Inbox deployment; the script predicts the Inbox and pool proxies from
its current nonce and reverts if either differs. On L2, `DeployL2FeeVault` reads `PRIVATE_KEY`, a
required `CONTRACT_OWNER`, `L2_BRIDGE`, `L1_CHAIN_ID` and `REWARD_POOL`.

No Etna guest exists yet, so a devnet's `EtnaInbox` uses a stand-in proof verifier such as the
accept-all `contracts/layer1/devnet/OpVerifier.sol`. As `land` is permissionless, anyone can then
land any batch and write arbitrary SignalService checkpoints (forged L2 to L1 messages), move
the forced inclusion head to the tail to collect every pending fee without including the entries,
and report any participation and committee, steering each epoch's validator share to any
registration owner. Such a verifier is for ephemeral devnets only; selecting it must be explicit.
Fixtures provide the config hash and use the dummy proof provider, which does not enforce guest
constraints.

## Configuration checks

- Keep node `inbox`, `registry` and `fee_vault` addresses equal to the deployed proxies, and
  `l2ChainId` equal to the node's chain id. The pool's `l2FeeVault` must be the node's
  `fee_vault`, the vault's `rewardPool` the pool proxy and its `l1ChainId` this L1, and
  `L1_BRIDGE` an L1 Bridge that verifies L2 messages against this deployment's SignalService (see
  Fees and rewards).
- Size the vault's `minRelayFee` (`SWEEP_MIN_RELAY_FEE`) to cover one relayed L1 `processMessage`
  of a sweep at the expected L1 gas price. It is an implementation immutable; changing it takes an
  upgrade.
- Registry `heartbeatWindow` must equal node `heartbeat_window`, and `minStake` must be at least
  node `max(s_min, vp_unit)`. Choose `vp_unit` large enough that the entire TAIKO supply cannot
  exceed CometBFT's maximum voting power.
- Keep the node's unsettled cap `U = d_max - margin_v` at least 1, that is `d_max > margin_v`.
  With `U = 0`, block 1 already exceeds the cap against the block-0 checkpoint that `init` saves,
  so the chain never starts. The contract cannot check this: `d_max` and `margin_v` are bound only
  inside the opaque `committeeConfigHash`, which it does not open. `abci-committee-record`
  rejects `U = 0` before deployment, and `abci`, `abci-genesis` and the lander reject it too.
- Choose `epochLenL2 >= U + 3`, the node's back-pressure requirement. The node also requires the
  first epoch transition to fit the protocol's `uint48` ranges. Epoch 1's first height,
  `epochLenL2 + 1`, must not exceed `type(uint48).max`, the last height `land` accepts; the
  429,496 cap below already guarantees it. Its minimum anchor, `L1_0 + epochLenL1` with `L1_0`
  the L1 block that initializes the Inbox, must not exceed `type(uint48).max` either, the largest
  anchor number the Etna `extraData` encodes. Later transitions are not range-checked: at
  practical values the `uint48` limits lie millions of years ahead. The contract checks only
  `3 <= epochLenL2 <= 429,496` and `epochLenL1 > 0`. `abci`, `abci-genesis` and the lander reject
  a schedule outside these bounds, but only after initialization has fixed it, so check the
  expected `L1_0 + epochLenL1` before calling `deployInbox()`.
- `init` rejects `epochLenL2` above 429,496 (`InvalidEpochLength`), and so does the node. The pool
  totals each member's proposer scores for an epoch in a checked `uint32`, and one member
  proposing every block of a longer epoch could reach `10,000 * epochLenL2 > 2^32 - 1`; the
  overflow would revert that epoch's landings and halt landing.
- Pace the schedule. This is the deployer's obligation, not a validity rule. A block of epoch `e`
  needs an L1-finalized anchor at or after `L1_0 + e * epochLenL1`, so L2 pauses at an epoch
  boundary (`epoch_not_open_on_l1`) whenever it produces `epochLenL2` blocks faster than L1
  produces `epochLenL1` blocks, and resumes once L1 finality catches up. To avoid these pauses,
  keep `epochLenL1` L1 slots (12 s each on Ethereum) no longer than `epochLenL2` L2 blocks at the
  fastest intended block rate; every L2 block advances the timestamp by at least one second.
  Back-pressure paces settlement the same way: L2 pauses (`back_pressure`) while `U` blocks are
  unlanded, so choose `U` above the number of blocks produced during one landing round trip
  (proving, `land` inclusion and the landing's L1 finality) unless such pauses are intended.
- `n_max` may not exceed 360: the client rejects a larger value. The landing that carries an
  epoch's last commit settles the whole epoch inline, and it must fit in one L1 transaction, which
  Osaka caps at 16,777,216 gas (EIP-7825); the lander caps its gas limit there. In the worst case,
  where one landing writes every member's count and proposer score for the epoch and credits
  every registration owner for the first time, the pool frame costs about 39.1k gas per member
  (5,005,164 measured for 128), and the settlement list, counts and scores add about 160 bytes of
  calldata per member, on top of the landing's own verification, checkpoint and forced inclusion
  costs (see Settlement gas). Measured as a whole transaction (execution plus intrinsic and
  calldata gas), that freezing landing needs 5,499,792 gas at 128 members, 14,865,689 at 360 and
  16,478,834 at 400, about 40.3k per member more. At the 360 cap it leaves about 1.91M (11%) of
  headroom. The hard ceiling is about 407 members: above it the landing cannot be included at
  all, landing halts, back-pressure then halts L2, and only a pool upgrade recovers. A production
  landing settles at most one epoch, because `epochLenL2 >= d_max - margin_v + 3` keeps every batch
  shorter than an epoch, so the bound applies per landing. The contracts cannot check it: `n_max`
  is bound only inside the opaque `committeeConfigHash`.
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
  `forcedInclusionFeeInGwei * (threshold + pending) / threshold` Gwei (rounded down and capped at
  `uint64.max`), so the fee doubles once `threshold` entries are pending. This preserves the
  existing fee curve and overflow behavior. Admission requires that fee multiplied by `1 gwei`
  in wei and refunds excess Ether to the caller; a failed refund reverts the submission. The
  landing that consumes an entry pays its stored fee to the statement-bound `feeRecipient`.
  Size the fee and doubling threshold for the transaction bytes, envelope/storage proof and
  landing/execution costs. Forced entries no longer carry a 128 KiB blob or require their own
  transaction-only L2 block.
- `forcedInclusionDelay` (seconds) is fixed at genesis in slot 282; the node and guest read it
  from storage. An entry is due at an L2 block whose anchor timestamp is at least the entry's
  timestamp plus the delay, evaluated without integer wraparound. Before due, validators may
  include it early but may not skip it. Initialization requires `D > 0` and `M >= 1152 seconds`,
  where `D` is the delay and `M` is the maximum anchor age. Entries never expire, and there is
  no expiry-derived upper bound on either parameter.
- `maxAnchorAge` (seconds) is fixed at genesis in slot 282. Every L2 block requires
  `block.timestamp - anchor.timestamp <= maxAnchorAge`. Its 1152-second minimum budgets three
  Ethereum epochs for normal finality lag; this is a deployment safeguard, not an upper bound
  on actual finality lag. Choose it above the expected lag, including `l1_finality_extra_depth`,
  RPC latency and the desired stall tolerance.
  An L1 finality stall longer than it pauses L2 until finality resumes. The rule bounds how
  far a block's anchor trails the block's derived timestamp, not real time: a pending entry is due
  at any block whose timestamp has reached `entry.timestamp + forcedInclusionDelay + maxAnchorAge`,
  so a longer value delays forced transactions more. Block timestamps follow BFT time, which a
  large enough coalition can hold back (see Open items). The proposed default is 2 hours; Ethereum
  finality stalls have lasted about an hour.
- Removing expiry prevents an outage or suppressed BFT time from deleting a pending transaction
  merely because it is old. It does not guarantee a wall-clock inclusion deadline, sufficient
  queue throughput during outages, or settlement against a quorum willing to stop landing.
- `allocValidatorPpm + allocProverPpm` may not exceed 1,000,000; whatever a freeze does not
  allocate stays in the free balance for later epochs. `landingRewardPerBlock` is paid per landed
  block and capped by the prover reward ledger, so `maxBatchBlocks` times it bounds one landing's
  reward. The ledger drains only through these rewards, at `landingRewardPerBlock` per landed
  block, so a zero reward with a non-zero `allocProverPpm` strands every proving share in the
  Inbox; `DeployEtnaDevnet` rejects that combination (`ProverShareWithoutLandingReward`). All
  three are implementation immutables; changing them takes an upgrade.
- The registry, Inbox, reward pool and fee vault owners can upgrade the contracts; use the
  intended chain governance. An upgrade is the only privileged way to move the pool's or the
  vault's Ether.

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
| 283     | `proverRewardLedger` (contract-internal)               | `uint256`, wei                                     |
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
- Each epoch is frozen and settled exactly once, in the verified landing whose commit range
  reaches its last height. The pool's balance always covers `reservedTotal`, and an empty pool or
  prover reward ledger never fails a landing.

## Authenticated committee configuration

The canonical commitment is the eleven-word encoding (352 bytes):

```solidity
committeeConfigHash = keccak256(abi.encode(
    bytes32("ETNA_PARENT_ANCHOR_V2"), uint256(l2ChainId), address(stakingRegistry),
    uint256(vpUnit), uint256(sMin), uint64(nMax),
    uint64(heartbeatWindow), uint64(2), uint8(1),
    uint64(dMax), uint64(marginV)
));
```

Words 8 and 9 bind heartbeat lookahead 2 and retained membership/MEM-08 algorithm version 1. The
last two bind the back-pressure parameters `d_max` and `margin_v`, so every node of a chain must
run the same unsettled cap; a node whose cap differs cannot open the stored hash.
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

```solidity
function land(
    LandInput calldata input,
    EpochParticipation[] calldata participation,
    CommitteeMember[][] calldata settlements,
    bytes calldata proof
) external payable;
```

`land` is permissionless. `LandInput` has exactly `lastHeight`, `lastBlockHash`, `lastStateRoot`,
`l1ReferenceBlockNumber`, `forcedInclusionHead`, the forced inclusion cursor after the batch, and
`feeRecipient`, the receiver of the consumed entries' fees and of the landing reward. With `p` and
`parentHash` the stored checkpoint, `L = lastHeight`, and `head`, `tail` the stored queue, `land`
requires active status, `p < L <= p + maxBatchBlocks`, `L <= type(uint48).max` and a non-zero
`feeRecipient` (`ZeroFeeRecipient` otherwise, whether or not the batch consumes entries). It also
requires `head <= forcedInclusionHead <= tail` and `forcedInclusionHead - head <= L - p`, since
each block consumes at most one entry; otherwise it reverts `InvalidForcedInclusionHead`. The
reference must be a past L1 block with a nonzero hash available from `blockhash` (256 blocks) or
the EIP-2935 history contract (8191 blocks). At least one transaction blob is required.

`EpochParticipation` is
`(uint64 epoch, bytes32 committeeHash, uint32[] signedCounts, uint32[] proposerScores)` and
`CommitteeMember` is `(uint32 bondId, uint64 activeFromL1, uint256 effStake)`. A committee is
listed in MEM-08 order and hashed as `keccak256(abi.encode(CommitteeMember[]))`; `signedCounts`
and `proposerScores` use the same member indices. Block `h + 1` carries the canonical commit of
height `h` in its `last_commit` and height 0 has none, so the batch `(p, L]` carries the commits of
`[c0, c1] = [max(p, 1), L - 1]`. Epoch `e` holds heights
`[e * epochLenL2 + 1, (e + 1) * epochLenL2]`. `participation` must be empty when `c0 > c1`, as
for the first batch `(0, 1]`. Otherwise it holds exactly one part per epoch from
`(c0 - 1) / epochLenL2` to `(c1 - 1) / epochLenL2`, in ascending order, and no signed count may
exceed the number of `[c0, c1]` heights in its part's epoch. Each part has as many proposer scores
as signed counts, and its scores sum to at most `10,000` times those heights: each height's
carrying block scores at most 10,000, for one proposer. The sum bound, stricter than bounding each
score alone, keeps an epoch's scores within what its bonus can pay, so even a dummy verifier
cannot make the pool credit more than an epoch's validator share. Anything else reverts
`InvalidParticipation` before the proof is verified. This shape check only narrows what a dummy
verifier admits; the guest makes counts, scores and committee hashes authoritative.
`settlements` holds the committee of each epoch the batch completes, in ascending order (see Fees
and rewards). It is not part of the statement: the pool checks each list against the committee
hash that the participation bound.

After those checks, landing runs in this order; any revert rolls back every write:

1. Hash the V7 statement below.
2. Move `head` to `forcedInclusionHead`, save the terminal checkpoint in the Inbox and
   SignalService, and emit `BatchLanded`.
3. Call `proofVerifier.verifyProof(0, statementHash, proof)`.
4. Call `rewardPool.recordLanding(L, epochLenL2, participation, settlements)`. For each part the
   pool adds the counts and scores and, if the batch completes that epoch, freezes and settles it;
   each
   frozen epoch's proving share arrives through the Inbox's `receive` into the prover reward
   ledger (slot 283).
5. Add `msg.value` to the ledger and debit the reward
   `min(landingRewardPerBlock * (L - p), ledger)`.
6. Send the consumed entries' fees, `sum(queue[i].feeInGwei) * 1 gwei` for `i` in
   `[head, forcedInclusionHead)`, plus the reward to `feeRecipient`, not `msg.sender`, in one
   transfer that is skipped when the sum is 0. Then emit
   `ForcedInclusionsConsumed(headBefore, headAfter, feesWei, recipient)` if the head moved, and
   `LandingRewardPaid(recipient, amount, ledgerAfter)` on every landing, even for a zero amount.

A recipient that rejects the payment fails the landing; an empty ledger pays nothing and does not
block landing. `land` and `saveForcedInclusion` share one reentrancy lock, so the recipient cannot
re-enter either. The Inbox's `receive` accepts Ether only from the reward pool
(`UnauthorizedRewardSender` otherwise) and stays outside the lock, because the pool sends proving
shares while `land` holds it. The statement binds `feeRecipient` and the participation, so whoever
copies a public landing transaction (calldata and blob sidecar) and lands it first still pays the
original recipient, and a copy naming another recipient or other counts fails verification. The
nineteen-word V7 preimage (608 bytes) is:

```solidity
statementHash = keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V7"),
    block.chainid, l2ChainId, address(this), address(stakingRegistry),
    recoveryGeneration, p, parentHash, committeeConfigHash,
    lastHeight, lastBlockHash, lastStateRoot,
    l1ReferenceBlockNumber, l1ReferenceBlockHash,
    keccak256(abi.encodePacked(blobHashes)),
    forcedInclusionHeadBefore, forcedInclusionHeadAfter, feeRecipient,
    keccak256(abi.encode(participation))
));
```

The first eighteen words are the V6 words under the V7 tag. The two heads are `uint48`:
`forcedInclusionHeadBefore` is the stored `head` and `forcedInclusionHeadAfter` is
`LandInput.forcedInclusionHead`; `feeRecipient` is the `address` from `LandInput`. The last word,
`participationHash`, hashes the `participation` argument as passed; for the empty array it is
`keccak256(abi.encode(uint256(32), uint256(0)))`. Both identities, config hash, generation,
parent and head before come from the contract. The reference hash and ordered blob hashes come
from the actual L1 execution context. `hashLandStatement` takes `participation` after `input`; it
derives identities and config internally but accepts raw generation, parent, head before,
terminal inputs and participation for encoding, and it neither authenticates them nor checks the
participation's shape. Call it through the proxy to bind that proxy's address. V6 and earlier
digests, V7 words without the participation hash, two-argument `land` calls, four- and
five-field `LandInput`s, fixed-cutoff configuration openings, envelopes before version 5, blob
payloads before version 4 and journals before schema 9 are incompatible with this prelaunch
version. The envelope version is 5, the landing blob payload version 4 and the journal schema 9;
record encoding stays 1. No deployed-chain migration is provided. Reject old signed jobs without
discarding their nonce, cancelling or automatically replacing their transaction.

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
V4, `0x04 || zlib(rlp([[header_proto, envelope], ...]))` in the existing blob coding, with each
block's canonical CometBFT header and Etna envelope: header hashes are the certified block ids,
`data_hash` commits to the envelope and `last_block_id` links the batch. Envelope v5 carries a
forced witness `[index, entryProof, tx]` when the anchor proves a pending entry. Proposers leave
`tx` empty for ordinary and included blocks and carry the separate preimage only for skips.
Landing still publishes batch blobs; forced transaction admission uses calldata bytes.
Commits and signatures are proof witnesses, not blob data.
Every anchor and actual proving L1 root belongs to the header chain ending at the reference hash.
Reference headers may be recent even for old batches. Arbitrary batch cuts never depend on an
earlier batch's committee output.

For validator participation, output each epoch of the commit range `[c0, c1]` as one part. Its
committee is the set derived above, listed as `CommitteeMember` entries in MEM-08 order with
`bondId`, `activeFromL1` and `effStake` taken from the authenticated registry entries, and
`committeeHash = keccak256(abi.encode(members))`. `signedCounts[i]` is the number of heights `h`
of `[c0, c1]` in that epoch whose canonical commit carries a verified `BlockIDFlagCommit`
signature of member `i`; nil votes and absent signatures do not count. The canonical commit of
height `h` is block `h + 1`'s `last_commit`, bound by that block's certified header, never a
separately fetched commit for the same height, whose signature set can differ. Each height's
commit rides in exactly one batch, so each signature counts once.

For each such height `h`, block `h + 1` scores
`floor(10_000 * includedEffStake / totalEffStake)`, where `includedEffStake` sums the `effStake` of
the members counted for `h` and `totalEffStake` that of the whole committee of `h`'s epoch. The
score goes to the member whose CometBFT address (the first 20 bytes of SHA-256 of its Ed25519 key,
as in the validator set) equals the `proposer_address` of block `h + 1`'s certified header; if no
member of the epoch's committee has that address, which can happen only when `h` is the last
height of its epoch and block `h + 1` is the next epoch's first block, the score is dropped.
`proposerScores[i]` sums member `i`'s scores over the part's heights. Bind
`participationHash = keccak256(abi.encode(EpochParticipation[]))` as the statement's last word.

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
`height - checkpoint <= d_max - margin_v` can still stop block production during a settlement
outage, and `epochLenL2 >= unsettledCap + 3` remains the schedule bound. Committee authorization
is autonomous, while settlement progress still matters for overall liveness.

The shared vector (`testdata/etna_vectors`, computed with `cast abi-encode` and read by both
`EtnaInboxLand.t.sol` and the lander) pins the six-field ABI, eleven-word config, a one-epoch
participation hash with signed counts and proposer scores, the empty participation hash and the V7
statement. Tests use an explicitly
dummy verifier for batching, statement binding, participation shape, settlement and rollback; they
do not prove the authoritative guest rules. Dummy proof
`0x00` remains explicit; no real ZK guest is part of this change, and host/contract integration
checks do not establish production ZK soundness. Empty-roster liveness and old-key/withdrawal
assumptions remain unchanged.

## Fees and rewards

L2 fees reach validators and landers through one loop that needs no keeper or privileged role:

```text
L2 block fees (whole base fee and priority fees)
  -> L2FeeVault, the coinbase of every Etna block
  -> sweep: one L2 Bridge message to EtnaRewardPool on L1
  -> EtnaRewardPool, in the landing that carries an epoch's last commit:
       validator share -> credits of the committee's registration owners, who withdraw them
       proving share   -> the Inbox's prover reward ledger
  -> every landing: landingRewardPerBlock per landed block, from the ledger, to feeRecipient
```

### Fee vault

`L2FeeVault` is the node's `fee_vault` constant: the coinbase and suggested fee recipient of every
Etna block, which the EL credits with the whole base fee and the priority fees without running
code. Its constructor takes `(l2Bridge, l1ChainId, rewardPool, minRelayFee)`, all non-zero
immutables, and `init(owner)` sets the owner, who can upgrade it. It has no `receive`, so direct
transfers revert, and no `withdraw`. Ether forced in without a call, such as by `selfdestruct`, is
swept as fees.

`sweep()` is permissionless and payable, and the caller chooses only when to sweep. It sends the
whole balance except `msg.value` through the L2 Bridge as one message: `to` and `destOwner` are
`rewardPool`, `destChainId` is `l1ChainId`, `srcOwner` is the vault, `value` is the amount,
`gasLimit` is `SWEEP_GAS_LIMIT`, `fee` is `msg.value` and `data` calls
`onMessageInvocation(abi.encode(sweepNonce))`. It adds the amount to `sweptTotal` (slot 251),
increments `sweepNonce` (slot 252) and emits `FeesSwept(nonce, amount, relayFee, msgHash)`. An
empty vault sends nothing, changes nothing and returns 0, and then rejects a relay fee
(`EmptyVaultWithFee`).

The relay fee `msg.value` must be at least the immutable `minRelayFee` (`RelayFeeTooLow`) and at
most `type(uint64).max` (`RelayFeeTooLarge`). The minimum makes every sweep cost real Ether that
pays its relayer, so nobody can split the fees into messages worth less than their delivery. A
caller may pay more, for example during an L1 gas spike, and all of `msg.value` becomes the fee.

The message gas limit is the constant `SWEEP_GAS_LIMIT = 1,000,000`. The L1 Bridge keeps its
minimum for this message, 808,704 gas, and forwards the rest to the pool's invocation. The pool's
first arrival, its most expensive because `arrivedTotal` goes from zero to non-zero, succeeds from
a limit of 834,088 (measured with a real L1 Bridge in a forge test, with its accounts and storage
already warm; a cold first arrival costs roughly 10-15k more), so every sweep reaches `DONE` on its
first relayed `processMessage` without a `retryMessage`. The limit is far below what a relayer can
forward under the L1 transaction gas cap.

### Reward pool

`EtnaRewardPool` is a UUPS proxy whose implementation fixes `inbox`, `stakingRegistry`,
`l1Bridge`, `l2FeeVault`, `l2ChainId`, `allocValidatorPpm`, `allocProverPpm` and
`proposerBonusPpm`; the two allocation shares sum to at most 1,000,000 and the bonus part is at
most 1,000,000 (`InvalidAllocation` otherwise). `init(owner)` sets the owner, who can
upgrade it. Nothing in the pool is pausable. Its free balance is `balance - reservedTotal`.

- Arrivals. `onMessageInvocation` requires the L1 Bridge as caller and a Bridge `context()` whose
  `from` is `l2FeeVault` and whose `srcChainId` is `l2ChainId` (`UnauthorizedSender` otherwise).
  It adds the value to `arrivedTotal`, a statistic, and emits
  `FeesArrived(msgHash, sweepNonce, amount)`. Any other Ether, such as the Bridge's refund of an
  unused relay fee to the pool as `destOwner`, arrives through `receive` as a donation and emits
  `Donation(from, amount)`. Both raise the free balance.
- Recording. Only the Inbox calls `recordLanding`, after verification. For each part the committee
  hash must be non-zero (`ZeroCommitteeHash`) and the epoch not yet frozen (`EpochAlreadyFrozen`);
  the first report stores the hash and every later one must match it (`CommitteeMismatch`). Counts
  and proposer scores are added to packed `uint32` totals with checked arithmetic.
- Freezing. Epoch `e` is complete when the batch carries the commit of its last height
  `(e + 1) * epochLenL2`, that is, when `L - 1 >= (e + 1) * epochLenL2`, so each epoch freezes in
  exactly one landing. Each complete part, in order, takes the next `settlements` entry: there must
  be exactly one entry per complete part (`SettlementCountMismatch`), and each list must hash to the
  stored committee hash (`CommitteeMismatch`). With `free` the free balance just before that
  epoch's freeze, `alloc = free * allocValidatorPpm / 1e6` and
  `provingShare = free * allocProverPpm / 1e6`. An epoch frozen earlier in the same landing
  lowers a later one's base; when the shares sum to 1,000,000, the later epoch gets only the
  earlier one's unpaid remainder.
- Settlement. `bonusAlloc = alloc * proposerBonusPpm / 1e6` and `baseAlloc = alloc - bonusAlloc`.
  Member `i` weighs `effStake_i * signedCount_i`; its base part is
  `mulDiv(baseAlloc, weight, totalWeight)`, or nothing when the total weight is zero, and its bonus
  part is `mulDiv(bonusAlloc, proposerScore_i, max(10_000 * epochLenL2, totalScore))`, both rounded
  down, where `totalScore` sums the committee members' scores; counts and scores at indices past
  the committee are ignored. The Inbox keeps `totalScore` at most `10_000 * epochLenL2`, and the
  maximum guards the pool if recorded scores ever exceeded it: the bonus parts never sum to more
  than `bonusAlloc`, so the pool stays solvent. A member whose sum is non-zero is credited it
  to `registrationOwnerOf(bondId, activeFromL1)`, emitting `ValidatorRewarded` with the sum; a
  member whose registration has no owner is skipped. The credited sum is the epoch's `paid` and
  joins `reservedTotal`. `alloc - paid` (rounding remainders, ownerless shares and the bonus no
  proposer earned) never leaves the free balance. The proving share is then sent to the Inbox, and
  `EpochFrozen(e, alloc, paid, provingShare)` is emitted.
- Withdrawal. `withdrawRewards(to)` sends all of the caller's credits to a non-zero `to`, releases
  their reservation and emits `RewardsWithdrawn`; a rejected transfer reverts, and a caller without
  credits gets 0. Credits belong to the registration owner, not to the slot's current `bondOwner`.
- `checkInvariants()` returns whether `balance >= reservedTotal`; `freeBalance`, `epochRecord`,
  `signedCountOf`, `proposerScoreOf` and `creditsOf` expose the rest.

### Proposer bonus

The proposer of block `h + 1` chooses which precommits for height `h` its `last_commit` carries,
beyond the 2/3 it needs, and those signatures are what the base part pays for. To make leaving
one out cost the proposer, the bonus part pays each block's proposer for the stake its
`last_commit` includes, as Cosmos's proposer reward does:

- Each block `h + 1` (`h >= 1`) scores `floor(10_000 * includedEffStake / totalEffStake)` with the
  committee of `h`'s epoch: 10,000 when every member's precommit is included. The score goes to the
  member whose CometBFT address is the block's `proposer_address`. A block whose proposer is not
  in that committee, possible only for the first block of an epoch (it carries the previous
  epoch's last commit but is proposed by the new committee), scores for nobody.
- An epoch of `epochLenL2` heights can score at most `10_000 * epochLenL2`, and each member
  receives that fraction of `bonusAlloc` its scores earned. The pool divides by the committee's
  score total instead when it is larger, which the Inbox's bound rules out, so the bonus never
  exceeds `bonusAlloc`. The bonus that no proposer earned (omitted stake, dropped boundary
  scores, rounding) stays in the free balance for later epochs, rather than going to the other
  members.
- The base part is the rest of the validator share, split by stake times signed heights exactly
  as without a bonus.

Devnets set `proposerBonusPpm = 300,000`. The share must outweigh what omitting a precommit
gains through the base part. Let every member propose its stake's share of the blocks and sign
every height, except that one omitter with stake share `a` leaves precommits of stake share `c`
out of its own blocks; it must keep `1 - c` above 2/3, so `c < 1/3`. The omitted members' signed
heights fall to `1 - a` of the epoch, so the omitter's base share rises from `a` to
`a / (1 - a * c)`, and its blocks score `10,000 * (1 - c)` instead of 10,000, so its bonus share
falls from `a` to `a * (1 - c)`. With bonus share `β`, omitting pays
`(1 - β) * a / (1 - a * c) + β * a * (1 - c)` against `a` for signing, so it is unprofitable
exactly when `β > β* = a / (1 + a * (1 - c))`. `β*` grows with both `a` and `c` and approaches
`3/11` (about 27.3%) as both approach 1/3, so a 30% bonus makes omission unprofitable for every
single omitter below 1/3. For example, with A at 30%, B at 37% and C at 33% of the stake, A
leaving C's precommit out of its own blocks (A and B still clear 2/3) raises A's base part from
30% to `3000 / 9010` (about 33.3%) of `baseAlloc`, and drops the score of A's blocks from 10,000
to 6,700, so A's bonus falls from 30% to 20.1% of `bonusAlloc`. Here `β*` is about 25%; at 30%
omitting costs A about 2.2% of its reward, while C still loses about 16%.

### Landing reward

The Inbox's prover reward ledger (slot 283) receives frozen epochs' proving shares and each
landing's `msg.value`. Each landing pays `min(landingRewardPerBlock * (L - p), ledger)` to
`feeRecipient` together with the consumed forced inclusion fees (Landing, steps 5 and 6). Because
the price is per block, splitting a range into more landings earns nothing extra, and a proving
share frozen by a landing already funds that landing's own reward. Anyone holding pool credits can
also fund the ledger with `withdrawRewards(inbox)`, which the Inbox accepts because the pool sends
it. Landing rewards are the ledger's only outflow, at most `landingRewardPerBlock` per landed
block.

### Settlement gas

Settling an epoch costs one `registrationOwnerOf` call, one credit write and one event per credited
member, and reads the epoch's packed counts and scores. For a 128-member epoch the pool frame
measured about 5.01M gas in the worst case, where one landing writes all 128 members' counts and
scores and credits every owner for the first time; the settlement of a later epoch, once every
owner already holds credits, measured about 1.3M gas as a whole isolated transaction. The landing
also carries about 20 KB of committee and participation calldata (five words per member).

The lander of the freezing landing pays all of this, so its gas limit must cover it. A gas
estimate alone may not: the pool skips the crediting loop when the epoch's allocation is zero, so
an estimate taken while the pool is empty leaves out the crediting, the first writes of the
epoch's record and of `reservedTotal`, the proving share's transfer into the Inbox ledger and the
then non-zero landing reward, and a sweep or donation arriving before inclusion runs the landing
out of gas. Measured as whole transactions paying a fresh fee recipient, a freezing landing costs
250,935 gas with an empty pool and 425,371 with a funded one for a one-member committee, and
261,792 and 528,894 for four members: about 143k per landing and 31k per member that the empty
estimate misses. The lander in #22280 therefore adds 40,000 gas per settled member and 200,000
once per landing that settles an epoch to its estimate, on top of 20% headroom. A landing that
reverts below its gas limit can still have run out of gas in the pool, behind two proxies: each
call frame keeps 1/64 of its gas and the top-level revert refunds it, so the lander treats a
canonical failed landing that used at least 15/16 of its limit as out of gas and rebuilds.

The contracts do not bound the committee size. The committee configuration's `n_max` caps it, and
the client rejects an `n_max` above 360. The lander caps the landing's gas limit at EIP-7825's
16,777,216; at 360 members the worst-case freezing landing needs about 14.9M, and the hard
ceiling at which it no longer fits is about 407 members (see Configuration checks).

### Deviations from #22262

- The vault keeps no `feeCredits`/`feeSwept` ledger and sweeps its whole balance, so forced-in
  Ether counts as fees: Etna has no anchor transaction or system call that could separate them.
- The pool is a separate contract rather than part of staking, so the registry's node-facing
  storage stays unchanged.
- An epoch freezes when its last commit lands, not at `evidenceClose(e)`, and needs no freeze
  cascade: there is no slashing.
- Participation counts signed heights per member rather than a head-certificate signature bitmap.
- Committee hashes reach L1 through the V7 statement; there is no `commitSet` committee root.
- The freezing landing settles the whole epoch into owner credits; there is no per-member
  `claimValidatorReward`, so a recipient that rejects Ether cannot block anyone else.
- The landing reward is priced per block and paid to `feeRecipient`, not per batch to
  `msg.sender`.
- Proving shares move into the Inbox ledger at the freeze, without a separate transfer call.
- There is no withdrawal-root attestation split (`PROVING_ATTEST_PPM`).
- The vault and pool are upgradeable like the other contracts, so an upgrade can redirect their
  Ether.
- A sweep's relay fee is at least the immutable `minRelayFee` rather than exactly the canonical
  fee, so callers can outbid it during L1 gas spikes; the message gas limit is the fixed
  `SWEEP_GAS_LIMIT`, and the caller chooses only when to sweep.
- Rewards count the signatures in block `h + 1`'s `last_commit`, a set its proposer chooses above
  the 2/3 threshold, and there is no counting of extra valid precommits. A Cosmos-style proposer
  bonus, which #22262 does not have, pays `proposerBonusPpm` of each validator share to proposers
  by the stake their `last_commit`s include, so omitting a precommit costs the omitter too (see
  Proposer bonus and Open items).

## Open items

- The Etna guest is a follow-up; the blob encoding and lander are in #22280. No slashing or stall
  recovery exist here; `recoveryGeneration` stays 0. The staking withdrawal delay must cover the
  evidence and landing windows once slashing is introduced.
- `EpochAlreadyFrozen` and the per-epoch committee hash binding in the reward pool assume that
  each height lands exactly once. A future GOV-04-style stall recovery that re-lands heights or
  re-derives an epoch's committee mid-epoch must migrate the pool's epoch records, signed counts
  and proposer scores; otherwise the re-landed epochs revert `EpochAlreadyFrozen` or
  `CommitteeMismatch` and landing halts. Re-landing an open epoch's heights would also add their
  counts and scores twice. The pool stays solvent regardless: its bonus denominator is at least
  the committee's score total, so the bonus parts never exceed `bonusAlloc`. But double-counted
  scores would still distort the epoch's bonus shares, and double-counted counts its base shares,
  so such a recovery must still migrate the pool's state.
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
  the timestamp by at least one second. Entries never expire, so holding time back cannot
  turn age into deletion, but there is still no wall-clock inclusion deadline or guarantee of
  settlement against a quorum willing to stop landing. Freshness only bounds anchor lag relative to the
  derived block timestamp, and pauses L2 during L1 finality stalls longer than `maxAnchorAge`.
  A validator-local clock check (PBTS-style timeliness) would raise the bound; it is an open,
  launch-blocking decision and is not implemented. An L1-clock check at landing would instead
  make batches delayed by a long lander outage unlandable.
- These scripts deploy no L1 Bridge, and sweeps need one. `Bridge.signalService` is immutable, so
  `L1_BRIDGE` must be a Bridge built on this deployment's SignalService proxy, whose resolver names
  the Etna L2 Bridge, which holds enough Ether to release each sweep's value, and which has no
  Ether quota or a quota above the largest sweep: a `quotaManager` cap below a sweep's value makes
  every `processMessage` of it revert, leaving it `NEW` until governance raises the quota. The
  pool fixes `l1Bridge` at deployment, so a Bridge deployed later needs a predicted address or a
  pool upgrade. Until a sweep is processed on L1, its value is not released and rewards pause;
  nothing accrues as debt.
- The proposer of block `h + 1` chooses which precommits beyond the 2/3 threshold enter its
  `last_commit`, so it can omit a validator's signature and lower that validator's count for
  height `h`. Omitting a precommit is not attributable, but the proposer bonus makes it cost the
  omitter. With A at 30%, B at 37% and C at 33% of the voting power, A omitting C whenever A
  proposes (A and B still clear 2/3) would raise A's reward by about 11% without a bonus; with a
  30% bonus it lowers A's by about 2.2%, while C still loses about 16%. In general a single
  omitter with stake share `a` that omits stake share `c` profits only while the bonus share is
  below `a / (1 + a * (1 - c))` (see Proposer bonus): about 25% in this example, and under 3/11
  (about 27.3%) for every omitter and omitted stake below 1/3, so a 30% bonus leaves no single
  omitter below 1/3 a profit. A coalition above 1/3 can use the vote withholding that suppresses
  BFT time (above) to have only its own proposals decided and exclude the victim entirely: with A
  at 34%, B at 33% and C at 33%, C earns nothing, and A, whose blocks then all score 6,700, about
  55.6% with a 30% bonus. The protocol does not prevent this; having the guest count extra valid
  precommits beyond those in `last_commit` would.
- Shares are fixed fractions of the free balance at the freeze, so a lander can time the freezing
  landing before or after a large sweep arrives, moving value between that epoch and later ones;
  the total is unchanged.
- Each sweep costs at least `minRelayFee`, which must cover one L1 `processMessage` at expected L1
  gas prices. During a gas spike above that expectation, a sweep paying only the minimum may not
  be worth relaying, and its value stays unreleased until a relayer accepts the fee.
- Under a dummy verifier, one landing with a wrong committee hash binds that epoch: every later
  honest landing that reports the epoch reverts `CommitteeMismatch`, and freezing the epoch needs
  a committee list matching the bound hash. A dummy verifier also lets any lander report
  arbitrary participation and committees.
- `withdrawRewards(inbox)` turns pool credits into a donation to the prover reward ledger. If a fee
  recipient does this while being paid, that landing's `LandingRewardPaid.ledgerAfter` understates
  the ledger.
