# Etna contracts

Etna starts a new proof-of-stake L2 chain at block 0. A committee of TAIKO stakers orders and
signs blocks with CometBFT. Anyone can land proven batches on L1 and submit authenticated L2
base-fee claims for the batch's committed reward recipient.

| Contract                           | Role                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| `impl/EtnaInbox.sol`               | Fresh L1 UUPS proxy; lands V10 batches, saves checkpoints and reward receipts. |
| `impl/EtnaStakingRegistry.sol`     | Stakes, immutable L2 reward addresses, heartbeats, exits and checkpoints.      |
| `libs/LibEntriesTree.sol`          | Recipient-bound registry entries tree.                                         |
| `../../layer2/core/L2FeeVault.sol` | Plain immutable L2 treasury predeploy; pays proved receipt claims once.        |

This is a new-genesis format. It has no existing-chain migration, L1 reward pool, participation
accounting, DAO subsidy, balance sweep or automatic bridge payout. The Inbox holds each L1 forced
inclusion fee until a landing consumes its entry, then pays it to that landing's `feeRecipient`.
The vault has no owner, proxy, initializer, upgrade function or privileged transfer.
Its payout authority nevertheless depends on the immutable L1 Inbox address: the Inbox's owner
can upgrade its UUPS implementation, and the selected verifier must soundly verify receipts.
An Inbox upgrade or an unsound verifier can authorize arbitrary rewards and exhaust the treasury.
An accept-all devnet verifier lets anyone create arbitrary reward receipts subject to the Inbox's
structural range/blob/reference checks and obtaining an anchored L1 storage proof. Verifier
behavior and any administration of that particular implementation are separate trust dependencies;
selecting a verifier address does not by itself grant that verifier upgrade powers.

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
4. Build alloc-only genesis from the canonical devnet JSON, exported runtime and trusted matching
   compiler artifact. Preserve every non-alloc field except the derived top-level `stateRoot`,
   which must be discarded after changing alloc; leave the canonical input fixture unchanged.
   The treasury address follows the pinned EL's `get_treasury_address(chainId)`:
   use the decimal chain-ID text as an address prefix, zero-fill, and append `10001`. For chain
   167001 this is `0x1670010000000000000000000000000000010001`. Set `BasefeeSharingPctg = 0`:
   consensus and the future guest must enforce `extraData[0] == 0` for **every execution block**,
   not only genesis, so the pinned EL credits all execution base fees to the treasury.
5. With an execution client supporting Etna on this custom genesis, obtain the actual block-0
   hash and state root and verify treasury runtime/immutable reads and both system predeploys.
   Supply those commitments, committee 0/config hashes and schedule inputs to `deployInbox()`,
   together with the **same** `L1_CHAIN_ID` and `L1_INBOX` used for export. Before broadcasting,
   it checks the chain ID against `block.chainid` and that the current nonce still predicts that
   Inbox. Never substitute a fresh prediction to bypass this guard; rebuild genesis if it fails.
   This checks the declared export identity, not arbitrary runtime/genesis files. It initializes
   the Inbox atomically and saves block 0 in SignalService. Compare its returned
   proxy address with the immutable Inbox prediction; any mismatch must abort node startup and
   require rebuilding the genesis/commitments. Never continue using a different Inbox address.
6. Wait for the L1 initialization block to finalize. Verify `abci-genesis`, authenticated config
   and EL genesis match the intended deployment, then start the nodes successfully. The first
   consensus block is L2 block 1; verify canonical root/history writes after it. Where practical,
   confirm a first successful finalized landing as public evidence before binding. An accept-all
   dummy proof provides integration evidence, not proof of semantic startup correctness.
7. Only after those checks, the registry owner explicitly calls `bindInbox(inbox)` once.
   `deployInbox()` always prints this deferred action and never binds, even for an owner-deployer.
   The call checks reciprocal registry identity and an initialized checkpoint, not node config,
   EL genesis or semantic startup correctness. Binding cannot be undone or redirected. Before
   binding, an unverified/wrong candidate may be discarded and redeployed; repeat the prediction,
   vault export and genesis checks for the replacement identity. Withdrawals fail closed while
   unbound; registration, consensus and landing continue without binding. No per-epoch binding
   action is needed.

Run the exporter from `packages/protocol`, without `--broadcast` or a private key:

```bash
mkdir -p deployments
# Fresh trusted artifact, with AST enabled by profile.layer2; export with the same profile.
FOUNDRY_PROFILE=layer2 forge build --force
L1_CHAIN_ID=1 \
L1_INBOX=0x1111111111111111111111111111111111111111 \
ETNA_RUNTIME_OUTPUT=deployments/etna-vault-runtime.json \
FOUNDRY_PROFILE=layer2 forge script script/layer2/ExportEtnaGenesis.s.sol:ExportEtnaGenesis

python3 script/layer2/build_etna_genesis.py \
  --base /path/to/canonical-devnet.json \
  --runtime deployments/etna-vault-runtime.json \
  --vault-artifact out/layer2/L2FeeVault.sol/L2FeeVault.json \
  --output deployments/etna-genesis.json
```

The example Inbox is a placeholder for the predicted proxy. The exporter rejects a zero chain or
Inbox through the vault constructor. JSON contains explicit L1 identity and fully initialized
runtime. `--vault-artifact` must be the trusted local compiler output from the same source and
profile used for export, with AST and `deployedBytecode.immutableReferences`. The builder binds
the intended source/contract, declaration IDs, names and types to every compiler-provided 32-byte
immutable location; it rejects missing, overlapping, out-of-range or unresolved references and
compares the **entire** reconstructed runtime, including nonimmutable bytes. Compiler zero-filled
runtime, identity-only metadata edits and partial immutable patches are rejected before output.
Do not obtain the trusted artifact from the untrusted runtime JSON or treat its self-attested
metadata as authority. Reconstruction relies on the current reviewed constructor only checking
nonzero inputs and directly assigning `l1ChainId` and `l1Inbox`; if those semantics change, update
this validation or execute the constructor in a local EVM. It does not validate arbitrary
constructor semantics. The client's stripped runtime artifacts are a separate interface: its
Rust harness executes real creation bytecode and does not use this Python artifact input.

The builder normalizes alloc addresses to lowercase `0x` form, rejects duplicate normalized
addresses, and writes sorted JSON with a terminating newline. All other alloc entries are retained;
the treasury, EIP-4788 roots and EIP-2935 history allocations are replaced with zero balance,
nonce 1 and exact code. Existing storage at those three addresses is deliberately replaced.

Both system runtimes are copied from `taikoxyz/alethia-reth` revision
`1e25b4849259320fca1123de362bc38b0b090ece`, `crates/node/tests/fixtures/etna-genesis.json`.
The builder checks the roots runtime's byte SHA-256 is
`cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d`.
It adds no Taiko hardfork JSON fields and changes no canonical genesis configuration.

The companion [EL change](https://github.com/taikoxyz/alethia-reth/pull/251), revision
`5d4d21ac472c024703082ba46c6eacfa3b8ec1bf`, supports `--devnet-etna-timestamp 0` for an
alloc-only custom genesis whose non-alloc configuration fields equal canonical devnet. Generated
JSON omits the stale derived `stateRoot`; the original canonical fixture is unchanged. It rebuilds
the chain spec before computing block 0, including the Cancun/Prague header fields omitted by a stale
pre-override header. The source of the unchanged system runtime bytes above remains pinned
independently. Verify the actual EL block-0 hash/root and execution; a Foundry VM check alone
cannot establish those properties. See the [companion client](https://github.com/taikoxyz/taiko-mono/pull/22280)
for real fee-routing and receipt-claim acceptance.

The deployment script documents its exact environment variables. Both entry points use a
`PRIVATE_KEY` and optional `CONTRACT_OWNER`. `run()` needs `TAIKO_TOKEN` and `REGISTRY_*`;
`deployInbox()` needs the original exported L1 identity, registry/verifier/remote service addresses,
L2 identity, batch and forced fee parameters, genesis commitments, epoch schedule and committee hashes, forced inclusion delay
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

The coordinated format is landing statement V10, envelope 6, blob payload 6, journal schema 12, APP_VERSION 4,
committee encoding version 2 and config domain `ETNA_PARENT_ANCHOR_V4`. Reject old persisted
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
| 284     | `activeCommitteeSnapshot`                              | `uint64`; latest landed active committee cutoff    |
| 285–300 | `__gap`                                                | —                                                  |

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

| Slot    | Content                                                                                 |
| ------- | --------------------------------------------------------------------------------------- |
| `R`     | `checkpoints.length`                                                                    |
| `R + 1` | `entries.length` (the entry index is the bond id)                                       |
| `R + 2` | `bondOwner`: `mapping(uint256 bondId => address)`                                       |
| `R + 3` | `withdrawn`: `mapping(uint256 bondId => bool)`                                          |
| `R + 4` | `keyHolder`: `mapping(bytes32 pubkey => uint256)`, the latest holder's bond id plus one |
| `R + 5` | `tree`: `mapping(uint256 node => bytes32)`, the Merkle nodes                            |
| `R + 6` | `freeSlots`: withdrawn bond ids awaiting reuse (contract-internal)                      |
| `R + 7` | `bondedStake`: stake of entries whose exit was not requested (contract-internal)        |
| `R + 8` | `inbox`: one-time bound Inbox address authenticating stake withdrawal eligibility       |

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
only `checkpoints` at `R` and `entries` at `R + 1`.

`bondOwnerOf(bondId)` names the slot's current holder and controls its bond permissions.
Historical committee membership and payout addresses are authenticated by the historical
checkpoint's entries root, not an owner-history mapping. Same-block reuse is allowed when the
activation, exit and withdrawal delays permit it; the reused slot may have a new payout address.

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
- An entry activates `activationDelay` blocks after registration. Its exit takes effect
  `exitDelay` blocks after the later of the exit request and the activation. There is no
  activation or exit rate limit; committee selection is top `n_max` by stake.
- Future committees derive from the committed switch-parent anchor. There is no `committee(epoch)` getter,
  mapping, committee landing output or publication event. Landing is never an activation gate.

## Authenticated committee configuration

The canonical commitment is the eleven-word encoding (352 bytes):

```solidity
committeeConfigHash = keccak256(abi.encode(
    bytes32("ETNA_PARENT_ANCHOR_V4"), uint256(l2ChainId), address(stakingRegistry),
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
Outgoing-quorum and recovery-bootstrap limits remain. Stake retention is enforced by the
settled active committee cutoff below; historical certificates remain verifiable.

## Stake withdrawals and settled committee turnover

`requestExit()` keeps its existing schedule and eligibility behavior. `withdraw()` requires both
`block.number >= exitEffectiveL1 + withdrawalDelay` and the bound Inbox's
`activeCommitteeSnapshot >= exitEffectiveL1`. The second condition proves that the exited bond
is absent from the committee governing an already-landed block; later anchored snapshots cannot
select that bond again. Slot reuse creates a different bond incarnation and leaves historical
registry checkpoints intact.

The Inbox initializes its cutoff to `genesisCutoff`. V10 binds the authenticated cutoff of the
committee actually signing the terminal block. Under the implemented normal genesis-only schedule,
epoch zero uses `genesisCutoff` and runtime epoch `t` uses the anchor of `D(t)=H(t)-3`.
At switch `S(t)` and `S(t)+1`, the outgoing set still authorizes blocks, so its cutoff remains
unchanged; `H(t)` activates the incoming set. A future authenticated recovery schedule may replace
this normal provenance, including within the same numeric epoch. Recovery remains unimplemented.
A fresh terminal anchor, a recent proving reference, or an already-derived pending committee
cannot substitute for the actual signing committee's cutoff or unlock stake.
The Inbox rejects cutoff regression and cutoff beyond the L1 reference. It relies on the bound
proof for exact committee provenance, including a cutoff advance within one numeric epoch. No real
guest is implemented in this PR; statement-bound verifier fixtures test contract acceptance and
atomic rollback, not guest proof soundness.

Settlement stalls intentionally delay refunds even after the L1 wait matures. There is no owner
bypass or rebind function, and no new slashing/recovery mechanism. Both the existing proxy upgrade
trust and verifier soundness remain relevant: a malicious replacement could defeat these checks.

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
address l2RewardRecipient, uint256 baseFeeAmount, uint64 activeCommitteeSnapshot)`. Both
recipients must be nonzero, including for zero fees. `feeRecipient` receives only consumed L1
forced inclusion fees. The lander selects `l2RewardRecipient` independently of block proposers;
the V10 statement and receipt bind that exact address. `activeCommitteeSnapshot` is the selection
snapshot of the committee governing `lastHeight`; the proof must authenticate it. Consensus and
the future guest must enforce `extraData[0] == 0` on every execution block. The guest must bind this nonzero recipient and prove `baseFeeAmount` equals the actual EL
base-fee credits to the immutable treasury over `(parentHeight, lastHeight]`, authenticating all
charges and destinations by reexecution. Under that per-block zero-sharing invariant and the
pinned EL rules, this equals `sum(header.baseFeePerGas * header.gasUsed)`. Fee credit is accounting
for execution charges, not the treasury's net balance delta: exclude claims, ordinary or forced
Ether and all other balance effects. Separately, each block's beneficiary must equal the registered recipient of the original proposer in its certified CometBFT
header, under that height's committee, including valid blocks retained across rounds. Real EL
regressions exercise the header fee identity; no real guest is implemented.

Landing requires active status, `parentHeight < lastHeight <= parentHeight + maxBatchBlocks`,
`lastHeight <= type(uint48).max`, ordered queue progress within the tail, at most one consumed
entry per new block, a past reference with an available block hash, an `activeCommitteeSnapshot`
that neither regresses nor exceeds `l1ReferenceBlockNumber`, and at least one blob. The V10
statement contains exactly twenty-one ABI words / 672 bytes:

```solidity
keccak256(abi.encode(
    bytes32("TAIKO_ETNA_LAND_V10"),
    block.chainid, l2ChainId, address(this), address(stakingRegistry),
    recoveryGeneration, parentHeight, parentHash, committeeConfigHash,
    lastHeight, lastBlockHash, lastStateRoot,
    l1ReferenceBlockNumber, l1ReferenceBlockHash,
    keccak256(abi.encodePacked(blobHashes)),
    forcedInclusionHeadBefore, forcedInclusionHeadAfter, feeRecipient,
    l2RewardRecipient, baseFeeAmount, activeCommitteeSnapshot
))
```

Identities, generation, config, stored parent and queue head before come from the Inbox;
reference hash and ordered blobs come from L1 execution. `hashLandStatement` is an encoder,
so call through the proxy to bind that proxy's address; it does not authenticate arbitrary inputs.
After verification the Inbox atomically records the checkpoint, active committee cutoff, receipt and queue progress,
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
recipient. Changed reward recipient or amount changes the V10 statement and commitment while
retaining the same batch ID. Existing V9 and older landing formats are incompatible. The ten-word receipt and batch ID are unchanged.

### Permissionless L2 claims

Anyone may pay gas for `claim(receipt, anchorTimestamp, accountProof, storageProof)` on the
immutable L2 vault. The receipt fixes the L2 recipient and actual EL base-fee credit for the
landed batch. This equals `sum(baseFeePerGas * gasUsed)` only with `extraData[0] == 0` on every
execution block and the pinned EL rules, excluding claims, ordinary/forced Ether and other balance
effects from fee accounting. `anchorTimestamp` is the timestamp of an executed L2 block carrying the
finalized L1 state root in EIP-4788, not the L1 block timestamp. The account proof authenticates
the fixed Inbox and the storage proof authenticates its slot-283 receipt commitment. A global
batch-id claimed bit permanently prevents a second payout of that same ID through later anchors,
including after recovery. A new generation creates a different batch ID and does not prevent
re-awarding the same logical fees; recovery procedures must avoid recreating already-paid fees.
A zero amount receipt is valid and is still consumed once.

The lander's `feeRecipient` receives only consumed forced-inclusion queue fees on L1;
`l2RewardRecipient` receives base fees on L2. They may be different addresses. Validator priority
fees go to the immutable address registered with its stake, independently of the batch recipient.
Neither the Inbox nor the vault needs reward pre-funding. Landers must fund their own L1 gas/blob
working capital; collected base fees need not cover proving or landing costs. No proving-performance
reduction has been measured, and a real guest remains unimplemented.

The companion client exposes explicit `taiko-client lander-claim` with independent L1/L2 RPCs,
landing transaction, batch id, payer key file and claim directory. It retains signed bytes across
restart. A canonical successful claim is final, since Etna L2 blocks are BFT-final; after a
recovery that rewinds L2, rerunning the command reconciles the same signed bytes. No automatic
bridge withdrawal is performed.

### Guest and consensus obligations

Consensus already pins zero sharing; the future guest must also check `extraData[0] == 0` for
every execution block and reexecute fee charges/destinations. The committed amount is actual EL
base-fee credit to the immutable treasury, equal to the header sum only under this invariant and
the pinned EL rules; other balance effects are excluded. Neither Inbox nor vault can inspect all
L2 headers onchain, so economic correctness depends on the selected verifier and its guest.

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

Planned recovery has an explicit schedule exception; it is not implemented by this genesis-only
change. If the recovery checkpoint is `c = S(t)`, bootstrap the outgoing committee `t-1` and the
authenticated, already-derived pending committee `t` from the original `D(t)`. Re-emit that pending
validator update in FinalizeBlock at `S(t)+1 = H(t)-1`. With CometBFT H+2 timing the outgoing set
signs `H(t)` and the incoming set starts at `H(t)+1`. Proofs must accept independent batch cuts
ending at either `H(t)` or `H(t)+1`, authenticating the actual signer and corresponding cutoff in
each case. Recovery must not derive a replacement pending set from a newer anchor.

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
from the stored parent to terminal hash/state root and exact blob data. The bound blobs carry
payload V6, `0x06 || zlib(rlp([[comet_header_proto_bytes, execution_block_rlp_bytes], ...]))`, in
the existing blob coding. Both items in each pair are byte strings: the full canonical CometBFT
header protobuf, followed by the canonical RLP encoding of `[full EL header, ordered EIP-2718
transactions]`. The execution block has no envelope version or consensus witnesses. Batches decode
independently, with the following fixed acceptance rules:

- Decode 1..6 blobs in transaction order using Kona encoding version 0. Each decoded chunk is at
  most 130044 bytes; every nonfinal chunk is full and the final chunk is nonempty. Every 32-byte
  field element starts with two zero high bits; require zero unused/reserved bits and padding.
  Concatenate the chunks before parsing.
- Require exactly `0x06` followed by one complete RFC1950 zlib stream, with no preset dictionary,
  truncation, trailing bytes or concatenated streams. The entire inflated RLP list is at most
  `64 * 1024 * 1024` bytes. Each published header-protobuf or ExecutionBlock-RLP byte string is
  at most `22020096` bytes. These protocol ceilings are independent of CLI settings.
- Require canonical RLP: one outer list, each pair a list of exactly two byte strings, and no
  extra fields or trailing bytes. Decode execution bytes completely and require identical canonical
  re-encoding. Header bytes use `tendermint_proto::v0_38::types::Header` and must equal both their
  protobuf re-encoding and their CometBFT domain-normalize/re-encoding. At height 1, omit
  `last_block_id`; Go's explicit empty BlockID field `0x2a021200` is accepted in private raw blocks
  but forbidden in published headers.
- Require exactly `N = lastHeight - parentHeight > 0` pairs, with `N` at most the authenticated
  deployed `maxBatchBlocks`. Both CometBFT and EL heights must equal `parentHeight+1..lastHeight`.
  Require internal CometBFT `last_block_id` and EL `parentHash` links; the first EL `parentHash`
  must equal the checkpoint `parentHash`, and the terminal EL hash/state root must equal
  `lastBlockHash`/`lastStateRoot`.

Lower operator `max-blocks` and byte budgets constrain operational capacity; they are not
alternative guest validity rules. Public decoding checks framing and links, not certificates or
original envelope `data_hash` authentication.

The full original envelope v6, anchor/committee/forced witnesses, evidence, commits and signatures
remain private consensus/proving inputs. Authenticate original envelopes against each certified
header's `data_hash`, verify their witness rules and execution, and prove their execution blocks
match the published projection exactly. Public DA decoding alone cannot recompute the original
`data_hash` or verify certificates. The lander checks this binding before publication and after
restoring persisted jobs. Envelope v6 still carries forced witness `[index, entryProof, tx]` when
the anchor proves a pending entry; ordinary/included blocks omit the separate preimage and skips
carry it. Forced transaction admission still uses calldata bytes, and landing still publishes blobs.

Under a sound real ZK landing proof and a finalized canonical L1 checkpoint binding the ordered
blob hashes, archived blob bytes plus the required genesis/execution context suffice to reconstruct
the landed EL chain and check its terminal hash/state root without original consensus witnesses or
signatures. Commitments alone cannot recover unavailable blob bytes. Exact historical envelopes
and stock CometBFT validator bootstrap are separate capabilities; L1-only CometBFT state bootstrap
is not implemented. Unlanded blocks retain their consensus/proving inputs. The development dummy
proof does not establish this soundness assumption.

Capacity checks measure the execution DA actually published, with conservative framing allowance
and existing compression-work limits. Independently bound retained private inputs and journal size;
smaller DA must not admit a job that cannot be durably recorded. Keep six blobs and `maxBatchBlocks`,
back-pressure and generation unchanged. Every anchor and actual proving L1 root belongs to the
header chain ending at the reference hash. Reference headers may be recent even for old batches.
Arbitrary batch cuts never depend on an earlier batch's committee output.

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
At or after due, a block that neither includes nor legally skips the current queue-head entry is
invalid; it cannot retain the cursor. This implication applies only to entry `c`, not every due
entry behind it. Log acquisition failure or an unavailable singleton verdict does not relax this
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
committee rules. The age check uses the candidate's fixed timestamp and authenticated anchor;
a proposal does not expire merely because a node's local finalized L1 head later advances. There
is no moving `K_FRESH` acceptance limit. A proposer with no finalized anchor fresh enough for `M`
proposes nothing, so a longer L1 finality stall pauses L2. Timing arguments assume less than
one-third Byzantine voting power, reasonable clocks and continued L1/L2/landing progress. Block
time and the due rule do not promise a wall-clock inclusion deadline for an arbitrary queue entry.
ProcessProposal, hot/cold FinalizeBlock, proposer final-block checking and lander validation must
agree on the classification and completed singleton verdict.
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

Receipt membership authenticates what the Inbox recorded, not the economic correctness of that
record. The verifier/guest must enforce per-block `extraData[0] == 0` and actual EL base-fee credit,
excluding claims, ordinary/forced Ether and other balance effects; only then do the pinned EL
rules imply the header fee sum. The Inbox's UUPS owner can change receipt authorization by
upgrading it. An unsound selected verifier, including an accept-all devnet verifier, can authorize
arbitrary recipients/amounts under the Inbox's structural checks. Anyone able to obtain the
resulting anchored proof can claim those receipts and exhaust funds, despite the vault having no
owner or upgrade function.

After authentication the vault consumes `claimed[batchId]` and pays exactly the committed amount
to the committed recipient. A transfer failure reverts consumption so a later attempt can retry.
The reentrancy lock protects all claim paths, including callbacks, and repeated claims fail. A
zero amount consumes the receipt and emits `RewardClaimed` without calling the recipient. Extra
or forced Ether gives no new entitlement. Insufficient balance reverts and leaves the claim
retryable; funds are never shared by vote, swept wholesale or paid to the proof submitter.

The EIP-4788 roots ring has 8191 timestamp-indexed modulo slots. An entry at timestamp `t` is
overwritten when a later system write uses a timestamp congruent to `t` modulo 8191. It is neither
a last-8191-block queue nor a fixed 8191-second expiry; without a colliding write an older entry
can remain readable. Claims may use any retained later authenticated state root that still proves
the immutable Inbox receipt; the receipt does not expire on L1.
L1 proofs and sufficient treasury funding are operational dependencies; no subsidy or bridge
keeper is introduced. Recovery must avoid recreating already-paid logical execution fees under
a new generation. New generation IDs prevent receipt collisions but do not alone prevent
cross-generation economic double payment; recovery coordination remains outside this change.

## Shared vectors and verification

`testdata/etna_vectors/generate.py` uses independent `cast` ABI/hash/slot commands. Its schema-3
JSON pins the V4 eleven-word config, recipient-bound registry leaves/four-word storage, V2 set
leaves and committee records, complete twenty-one-word V10 preimages, batch identity, commitment,
slot-283 location, slot-284 cutoff, exact land/claim selectors, and a zero-fee batch. Integers are decimal strings.
Set cases cover empty rejection input, singleton, odd-width and five-member trees.

Regenerate twice and compare SHA-256. Export runtime and build genesis twice with identical
explicit inputs and compare bytes; changing either L1 immutable must change runtime, and changing
L2 chain ID must change the treasury allocation. `EtnaGenesis.t.sol` installs the exported runtime
and canonical system bytecode in Foundry, uses the exact privileged system caller for writes,
reads roots/history and claims a real trie-proved receipt. It validates genuine exporter runtimes
for two distinct L1 identities through the Python builder. The Python tests verify preservation
of non-alloc fields except discarded `stateRoot`, normalization, rejected ambiguity, full runtime
binding, malformed compiler metadata and deterministic JSON. These are EVM/unit checks; they do not replace real EL custom-genesis activation/block execution acceptance.

Run from `packages/protocol`:

```bash
FOUNDRY_PROFILE=layer2 forge build
python3 test/layer2/core/test_etna_genesis.py
pnpm test:l1
pnpm test:l2
pnpm test:shared
```
