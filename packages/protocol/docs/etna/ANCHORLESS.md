# Etna anchorless design

From the Etna fork on, L2 blocks carry no anchor transaction. Each block header commits to its L1 anchor block instead: the anchor block's execution state root in `parentBeaconBlockRoot` and its number in `extraData`. The standard EIP-4788 pre-execution call records the root on L2, and L2 contracts verify L1 storage proofs against it. This design adds no Taiko-specific system call or execution hook and every header field stays within Ethereum's limits, so the only Taiko-specific execution rule it leaves is header validation. The block-start staking call is part of the PoS + ZK specification, not of this design ([SPEC.md 3.2](SPEC.md#32-block-header)).

This document gives the design, the contract changes and the activation order. Etna block production and validation follow [SPEC.md section 3](SPEC.md#3-consensus-and-blocks); the header encoding is also recorded in [Derivation.md](../Derivation.md#pre-execution-block-header).

## 1. The anchor transaction before Etna

Before Etna, `Anchor.anchorV4(checkpoint)` runs as transaction 0 of every L2 block. The golden touch address sends it; that address's private key is public, and the transaction is signed with a fixed-k ECDSA signature so that every node reproduces the same bytes. It:

1. re-binds the last 255 L2 block hashes through a ring-buffer hash, the ancestors hash;
2. stores the parent block hash in `blockHashes`;
3. saves the L1 checkpoint through `SignalService.saveCheckpoint` when the anchor block advances.

Several parts of the stack exist only to support it:

- **Key and signing**: the published golden touch key, the fixed-k signers in both clients with their retry on a second k value, and the matching test signer.
- **Execution engine exceptions**: for the anchor transaction, the execution engines skip the balance check, the fee-cap check, the base-fee split and the gas refund, and they pin its type, selector, gas limit (1,000,000), fee cap and sender. Block import treats transaction 0 as the anchor.
- **Block-shape rules**: the zk gas limit never aborts the anchor transaction, and the block gas limit carries a 1,000,000 gas reserve for it.
- **Provers**: the guests re-derive the fixed-k signature and compare bytes.

Security does not come from the key, which is public. It comes from three rules: the anchor must be transaction 0, a second `anchorV4` in the same block reverts on the ancestors-hash check, and the guests check the anchor calldata against values derived from L1. This design keeps those guarantees with fewer parts. Nothing is executed on anyone's behalf, so there is no payer, fee exemption or gas accounting to special-case.

## 2. Header

| Field                   | Before Etna                                        | From Etna on                                                                                                     |
| ----------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `parentBeaconBlockRoot` | `0x0` (from Unzen on)                              | execution state root of the L1 block at the final derived `anchorBlockNumber`; never zero for non-genesis blocks |
| `extraData`             | 7 bytes `[basefeeSharingPctg(1) \| proposalId(6)]` | 13 bytes `[basefeeSharingPctg(1) \| generation(6) \| anchorBlockNumber(6)]`, both numbers big-endian `uint48`    |

This design changes no other header field; [SPEC.md 3.2](SPEC.md#32-block-header) defines the full Etna header.

Etna block production follows the PoS + ZK specification, so bytes 0..6 of `extraData` follow [SPEC.md 3.2](SPEC.md#32-block-header): byte 0 is always 100 and bytes 1..6 hold the recovery generation. This design adds the anchor commitment: `parentBeaconBlockRoot` and bytes 7..12.

- **Execution engine rule**: from the fork on, a non-genesis block must have a non-zero `parentBeaconBlockRoot` and exactly 13 bytes of `extraData`.
- **Derivation and prover rule**: the root must be the state root of the L1 block at the derived `anchorBlockNumber`, and bytes 7..12 of `extraData` must encode that number. Provers authenticate the anchor block's header through the parent-hash chain of the L1 headers they are given; before Etna they apply the same check to the anchor calldata.
- **Self-contained blocks**: a block received over P2P executes without L1 access.

A block that keeps its parent's anchor carries the parent's number and root. The first Etna block always carries an anchor witness ([SPEC.md 3.3](SPEC.md#33-anchor)), so no Etna block inherits an anchor from an Unzen parent; on a new network the L2 genesis header keeps a zero root and performs no EIP-4788 call.

Other derivation changes at the fork:

- Nothing is prepended to a block's transactions, so the first transaction is treated like any other, and the zk gas limit can abort it.
- In Unzen’s based derivation a default source manifest yields one block containing only the `anchorV4` transaction and no user transactions. Etna’s ABCI application validates the CometBFT proposal under SPEC §3.
- Transactions from the golden touch address are ordinary transactions.
- The 1,000,000 gas reserve applies only before the fork.

The proposal and manifest descriptions in this document and `Derivation.md` describe the earlier proposal-based flow and await a separate rewrite. Etna block production and metadata validation follow [SPEC.md section 3](SPEC.md#3-consensus-and-blocks).

## 3. Recording through EIP-4788

Because the root is in `parentBeaconBlockRoot`, the EIP-4788 pre-execution call that every post-Cancun execution client already makes stores it in the beacon roots contract at `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`, keyed by the L2 block timestamp. The contract is a ring buffer indexed by `timestamp % 8191`, so an entry stays readable until a later block's timestamp has the same remainder: at least 8,191 seconds, about 2.3 hours. Derived L2 timestamps strictly increase, so every block has its own entry.

There is no new system call into the `SignalService`, no synthetic receipt and nothing for the provers to implement beyond upstream EIP-4788 behaviour. The contract also serves any L2 contract as a short-term oracle of recent L1 state roots.

## 4. Bridge verification

L1 and L2 use the same [EtnaSignalService implementation](../../contracts/shared/signal/EtnaSignalService.sol) and storage layout. Each stores only the counterpart chain’s state root under the checkpoint height. Both expose `getStateRoot(uint64)` with the same lookup and missing-root behavior as signal verification. The `SignalService` resolves every root itself: from its own checkpoint store, and on L2 also from EIP-4788. One immutable flag, `usesBeaconRoots`, turns on the L2 behavior: the contract then accepts a checkpoint only in a block whose own EIP-4788 root is zero, which is every block before Etna and no block from Etna on. It reads the boundary from the block, so no contract holds the fork time and the contract cannot disagree with the execution engines about where Etna begins.

| Immutable configuration | L1                       | L2                       |
| ----------------------- | ------------------------ | ------------------------ |
| `_authorizedSyncer`     | EtnaInbox                | `Anchor` proxy           |
| `usesBeaconRoots`       | `false`                  | `true`                   |
| `_remoteSignalService`  | L2 `SignalService` proxy | L1 `SignalService` proxy |
| `pauser`                | L1 pauser, may be zero   | L2 pauser, may be zero   |

These are all of the immutables the `SignalService` declares itself; the ones it inherits, `UUPSUpgradeable`'s `__self` and `EssentialContract`'s `__resolver`, are set as for any other implementation. They are fixed at implementation deployment, with no setter. With `usesBeaconRoots` false, as on L1, the checkpoint store is the only root source and never closes. With it true, as on L2, the store closes by itself at the first Etna block: a block before Etna has a zero `parentBeaconBlockRoot`, so the EIP-4788 contract holds a zero root for its timestamp, and an Etna block has a nonzero one (section 2). On a new network the genesis block makes no EIP-4788 call and executes no transaction, and every later block is an Etna block. Every `SignalService` has one syncer and reads no Inbox state; on a switching L1 the Unzen Inbox's final checkpoints reach it through the EtnaInbox ([SWITCH.md](SWITCH.md#3-the-dao-proposals)).

```solidity
// Shared SignalService; assigned by the constructor.
/// @notice False on L1. True on L2, where EIP-4788 holds L1 state roots from Etna on.
bool public immutable usesBeaconRoots;

/// @inheritdoc ICheckpointStore
function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
    if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();
    // An Etna block has a nonzero EIP-4788 root for its own timestamp, so no checkpoint can be saved
    // from Etna on and the public golden touch key cannot forge one.
    // A failed read rejects as well, so a missing EIP-4788 contract fails closed.
    if (usesBeaconRoots) {
        (bool ok, bytes32 root) = _beaconRoot(block.timestamp);
        if (!ok || root != 0) revert SS_CHECKPOINTS_CLOSED();
    }
    if (_checkpoint.stateRoot == 0) revert SS_INVALID_CHECKPOINT();
    _checkpoints[VERSION][_checkpoint.blockNumber].stateRoot = _checkpoint.stateRoot;
    emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
}

/// @dev Resolves the state root against which a signal proof is checked.
/// @param _blockId The remote height of a checkpoint, or on L2 the local timestamp of an Etna block.
/// @return stateRoot_ The authenticated state root.
function _getStateRoot(uint64 _blockId) private view returns (bytes32 stateRoot_) {
    // A checkpoint answers first. On L2 either source authenticates an L1 state root.
    if (_blockId <= type(uint48).max) stateRoot_ = _checkpoints[VERSION][uint48(_blockId)].stateRoot;
    if (stateRoot_ == 0 && usesBeaconRoots) (, stateRoot_) = _beaconRoot(_blockId);
    if (stateRoot_ == 0) revert SS_CHECKPOINT_NOT_FOUND();
}

/// @dev Reads EIP-4788. Its whole calldata is the 32-byte timestamp, with no selector. It reverts for
///      a timestamp it does not hold, and a call to an address without code succeeds with no return
///      data; both give ok_ false. A block before Etna reads as a zero root.
function _beaconRoot(uint256 _timestamp) private view returns (bool ok_, bytes32 root_) {
    (bool success, bytes memory ret) = BEACON_ROOTS.staticcall(abi.encode(_timestamp));
    ok_ = success && ret.length == 32;
    if (ok_) root_ = abi.decode(ret, (bytes32));
}
```

- **Proof format**: the existing single-hop `HopProof`. Its `blockId` is the remote block number of a saved checkpoint, or on L2 the timestamp of an Etna block. The `SignalService` uses a checkpoint when it holds one for that id and reads EIP-4788 otherwise; the choice does not depend on the block that verifies the proof. `rootHash` must equal the resolved root, and the account and storage proofs are checked against the counterpart `SignalService`. No caller-supplied L1 number, hash or root is trusted.
- **No new checkpoints from the fork on**: the L2 `SignalService` saves none in an Etna block. The checkpoints it saved before the fork stay usable in proofs: each is an L1 state root that a real anchor transaction recorded, and a signal proven under an older root was sent (section 5). A signal proven once stays cached, and an empty proof for a cached signal keeps working after its EIP-4788 entry expires.
- **Root resolution**: `_verifySignalReceived` uses `_getStateRoot` for both the `rootHash` comparison and Merkle-proof verification. The `uint48` bound belongs only to the checkpoint lookup; the EIP-4788 path takes the full `uint64` timestamp. On L2 both sources authenticate L1 state roots. An id with no checkpoint and no live EIP-4788 entry, a missing return value or a zero root rejects the proof with `SS_CHECKPOINT_NOT_FOUND`, the error relayers already treat as transient (section 8).
- **Checkpoint authorization**: the shared implementation accepts checkpoints only from `_authorizedSyncer`, while its checkpoint store is open. On L2 the `Anchor` keeps saving checkpoints until the fork; the `Anchor` itself needs no change for Etna (section 8).
- **Storage**: the shared `SignalService` keeps checkpoints and cached signals in its current `VERSION` storage namespace; immutables add no proxy storage slots. L1 keeps `VERSION = 1` so Unzen roots stay readable. The record retains its old block-hash word and writes only the following stateRoot word. A nonzero stateRoot marks an existing record. The three-field checkpoint ABI is preserved: `getCheckpoint` returns zero in its hash field, including for legacy records, so reusing a height never exposes a stale hash. `CheckpointSaved` still emits the caller-supplied hash for indexers. Section 8 covers the L2 migration.
- **Fork time**: no L2 contract holds it. The `SignalService` only needs to know whether the current block is an Etna block, and the block's own EIP-4788 root tells it.

To build a proof off chain:

1. Pick a recent L2 block and read the anchor number from bytes 7..12 of its `extraData`. It must be at or after the L1 block that sent the message.
2. Fetch `eth_getProof` for the L1 `SignalService` at that L1 block. Many L1 nodes serve it only for recent blocks, another reason to use a recent L2 block.
3. Set `blockId` to the L2 block's timestamp and `rootHash` to its `parentBeaconBlockRoot`.

A proof must be rebuilt once its timestamp leaves the EIP-4788 window. The checkpoint cutoff prevents new L2 `CheckpointSaved` events. An ordinary `anchorV4` that does not advance the checkpoint can still succeed and emit `Anchored` while calls maintain its ancestor history. Indexers and bridge processability checks take the anchor number and root from the validated Etna header. Neither this event nor the legacy Anchor’s block state authenticates the current anchor.

## 5. Liveness

While L2 produces blocks, a recent root is always inside the EIP-4788 window. A newer L1 state root proves everything an older one did, because L1 signal slots are never cleared, so old roots are never needed. If L2 stops producing blocks, nothing is bridged anyway. Etna's application and guests validate its blocks, including FI blocks, under SPEC §§3 and 7. Default manifests belong to the earlier based derivation. The EIP-4788 contract is in place before the fork, because the L2 `SignalService` upgrade cannot execute without it (section 8).

## 6. Why the state root rather than the block hash

Each SignalService authenticates the counterpart chain’s state roots. L1 looks up L2 roots by landing height. L2 looks up L1 roots by anchor height for saved checkpoints and by L2 timestamp for Etna headers. The bridge can verify a storage proof directly against the resolved root.

For a remote execution block hash, prove the corresponding history-contract storage word under a later authenticated state root of that same chain: L1 uses L2’s EIP-2935, and L2 uses L1’s EIP-2935. At height n the history covers up to 8,191 preceding blocks, ending at n − 1. The landing block’s own hash therefore needs a later root too. At the 20-minute landing target and four-second L2 block time, roughly 300 blocks separate landings, within the history window. A longer gap requires checking the actual distance.

## 7. Prerequisite: EIP-4788 and EIP-2935 on L2

The EIP-4788 contract (`0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`) and the EIP-2935 contract (`0x0000F90827F1C53a10cb7A02335B175320002935`) must have code on L2 before the fork. Unzen already enables the Prague pre-execution calls, but EIP-4788 requires the call to fail silently when the address has no code, so on a network whose genesis lacks the contracts both calls do nothing.

Ethereum deployed both as ordinary contracts through Nick's method ahead of the respective forks (EIP-4788 before Cancun, EIP-2935 before Prague); clients never insert the code. Taiko does the same, but the order matters: every builder, importer and prover must already execute a state-writing pre-execution call identically before its contract exists, or deploying the contract splits the chain.

- **Build and import must agree.** Each execution engine makes both calls on the block-building path exactly as on the import path, with a zero `parentBeaconBlockRoot` before Etna. An engine that skips the EIP-4788 call while building and stamps the zero root afterwards produces blocks without the call's two storage writes once the contract has code. Every node, not only sequencers, builds through the Engine API during L1 derivation (`forkchoiceUpdated`, `getPayload`, `newPayload`), so such a node would reject its own derived blocks.
- **Provers follow the import path**, so they agree with importers.

Order of operations:

1. Every execution engine makes both calls identically when building and importing. With no code at the addresses this changes nothing, so it ships as a normal release without a fork.
2. Deploy EIP-2935 (test network first, then mainnet). It starts recording L2 block hashes at once, because the Prague call has run since Unzen, and lets witness generation be validated against the history contract before the fork.
3. Deploy EIP-4788 once step 1 runs on every node (test network first, then mainnet). The contract then records zero roots, harmlessly, until the fork switches `parentBeaconBlockRoot` to the L1 anchor state root.
4. Verify the runtime code hash at each canonical address against the published EIP bytecode. Observe actual pre-execution writes in equivalent built and imported blocks and in both proof paths: EIP-2935 stores the parent hash, and EIP-4788 writes the block timestamp and supplied root in its paired ring slots (including a pre-fork zero root). Verify a nonzero root is readable by timestamp in the Etna rehearsal. A nonempty code response alone cannot establish this. The L2 `SignalService` upgrade of section 8 comes after this step, because the upgraded contract reads EIP-4788 whenever it saves a checkpoint; its batch checks the code and the read on chain. The fork comes last, with both contracts deployed and the contract and prover upgrades of section 8 executed. New networks put both contracts in the genesis alloc instead of steps 2 and 3.

To deploy each contract, fund its canonical deployer and broadcast the presigned pre-EIP-155 transaction through a node that accepts unprotected transactions. The deployers are `0x0B799C86a49DEeb90402691F1041aa3AF2d3C875` for EIP-4788 and `0x3462413Af4609098e1E27A490f554f260213D685` for EIP-2935. Each transaction uses nonce 0, a gas limit of 250,000 and a gas price of 1,000 gwei, so each deployer needs a 0.25 ETH prefund; the remainder is refunded. Before funding, rehearse those exact signed legacy transactions with the target network’s transaction pool, replay-protection and block-validation settings. Record sender, nonce, inclusion, deployed runtime hash and system writes. If these transactions cannot be included, specify and rehearse an explicit deterministic fork allocation or deployment with matching builder, importer and guest behavior before scheduling Etna.

With EIP-2935 in place, the L2 matches Ethereum's post-Prague state: `BLOCKHASH` semantics are unchanged, and the last 8,191 L2 block hashes are readable on chain, which replaces the binding the ancestors hash provided.

## 8. Fork and migration

- **Activation**: Etna activates by L2 timestamp at `ETNA_FORK_TIME`. The Unzen Inbox accepts no proposal from shortly before that time, so every Unzen block is earlier and every Etna block is at or after it ([SWITCH.md](SWITCH.md)). Pre-fork blocks keep the anchor transaction and a zero `parentBeaconBlockRoot`; post-fork blocks have no anchor transaction, a non-zero `parentBeaconBlockRoot` and 13 bytes of `extraData`.
- **Checkpoint cutoff**: the L2 `SignalService` rejects every `saveCheckpoint` in an Etna block, which it recognizes by the block's own nonzero EIP-4788 root (section 4). The cutoff is required. The ancestors-hash check excludes the parent, so in the first block without an anchor transaction an `anchorV4` sent as an ordinary transaction would still pass. The golden touch key is public, and also usable through an EIP-7702 delegation, so without the cutoff anyone could then save a forged checkpoint. With it, such an `anchorV4` reverts whenever it advances the anchor; otherwise it only rewrites the `Anchor`'s own block state from real block hashes, so it forges nothing. The cutoff protects the checkpoints where they are stored, so the `Anchor` needs no upgrade for Etna. A later clean-up upgrade can delete `anchorV4`, `blockHashes`, the block state and the ancestors hash, but must keep `withdraw`.
- **Checkpoints**: the checkpoints the upgraded L2 `SignalService` saved before the fork stay in storage and usable in proofs; from the fork on it saves none. `SignalService.saveCheckpoint` and its authorized syncer stay for L1, where the EtnaInbox saves L2 → L1 checkpoints above the Etna start and forwards the Unzen Inbox's checkpoints only before the Etna start is written ([SWITCH.md](SWITCH.md#6-bridge-during-and-after-the-switch)).
- **Storage namespace**: The shared `SignalService` uses the `VERSION` storage namespace, while the L2 `SignalService` deployed before Etna uses flat mappings. The upgrade therefore leaves the old checkpoints and cached signals unreadable; legitimate signals are proven again against a newer root.

### Upgrade order

Both steps 1 and 2 precede the readiness upgrade in step 3.

1. **Execution engines, then EIP-2935 and EIP-4788 on L2** (section 7). Step 3 cannot execute before them: its batch requires the EIP-4788 code and a successful read.
2. **Update Unzen guests.** Take the inherited checkpoint from the parent block’s anchor transaction. These guests can ship any time before the L2 upgrade. Register the replacement images on L1 before either chain writes root-only checkpoints. See [raiko2#306](https://github.com/taikoxyz/raiko2/pull/306) and [gaiko2#64](https://github.com/taikoxyz/gaiko2/pull/64).
3. **L2 readiness proposal, before scheduling the fork:**

   - Its L1 actions trust the new guest images, and SGX enclaves if used. They take effect when the proposal executes, before its L2 part reaches L2.
   - One L2 message to the `DelegateController` upgrades the `SignalService` proxy to the shared implementation configured with `_authorizedSyncer = address(Anchor)` and `usesBeaconRoots = true`. Its first check requires the canonical EIP-4788 code and a zero root for the current block's timestamp, and its final check requires the proxy to hold the expected implementation, so a wrong order or a wrong implementation reverts the batch and leaves the message retriable. The `Anchor` is not upgraded.

   The upgrade touches one proxy and depends on one other L2 contract, the EIP-4788 contract. In every block before Etna the new implementation accepts the `Anchor`'s checkpoints and resolves roots from them as before, so the upgrade is safe whenever it executes before the propose cutoff, and it carries no date. The namespace switch empties the checkpoint store and the received-signal cache, so uncached L1 → L2 proofs wait for the next anchor transaction that advances the anchor. The guest images go first because old guests reject the zero checkpoint hash when a proposal inherits its parent’s anchor. Such proposals would stall until the new images are trusted.

   Verify the installed implementation against a proven Unzen checkpoint on finalized L1 before authorizing the separate scheduling proposal. Until then Unzen stays open.

4. **Relayers and the bridge UI.** Checkpoints saved before the `SignalService` upgrade are no longer readable, so L1 → L2 processing waits until a post-upgrade `CheckpointSaved` is indexed, or treats `SS_CHECKPOINT_NOT_FOUND` as transient. Proof builders that set `blockId` to an L2 timestamp and `rootHash` to that block's `parentBeaconBlockRoot` must ship before the fork. A proof built against a checkpoint that the upgraded `SignalService` holds stays valid across the fork, and a timestamp that has left the EIP-4788 window needs a fresh proof.
5. **The switch.** Etna starts as described in [SWITCH.md](SWITCH.md#4-switch-day): the Unzen Inbox stops accepting proposals shortly before `ETNA_FORK_TIME`, and the first Etna block has a timestamp at or after it. The second DAO proposal installs the cutoffs, fork time and schedule-specific guest trust on L1. Once it executes, the fork time is fixed on chain in the Unzen Inbox and the EtnaInbox only. Moving it takes one L1 batch and a client release, and no L2 action ([SWITCH.md](SWITCH.md#moving-the-fork-time)). Unzen must prove its closed tip and L1 must finalize the start write before Etna produces.
6. **Afterwards.** Never roll the L2 `SignalService` back to the flat implementation, which would revive the pre-upgrade checkpoints and cached signals. Every later L2 `SignalService` implementation keeps the checkpoint cutoff and the EIP-4788 root path. The cutoff rests on every Etna block having a nonzero `parentBeaconBlockRoot` (section 2): a later change to what that field carries must first close `saveCheckpoint` unconditionally, as the clean-up that deletes `anchorV4` also does.

## 9. Changes by component

The Go/Rust drivers, preconfirmers and proposal-manifest derivation refer to the based Unzen system up to S. From S + 1 the production stack is the Etna ABCI application, CometBFT, guarded signer, Etna execution engine, landers and Etna proof guests under SPEC §§2–6. The application and both guests validate each Etna block’s anchor, header and payload. A based preconfirmation or driver decision cannot authenticate an Etna header.

| Component                                    | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Protocol contracts                           | Shared `SignalService`: immutable `usesBeaconRoots`, false on L1 and true on L2, where it closes checkpoint writes in every Etna block and adds EIP-4788 to root resolution, with `VERSION` storage and one authorized syncer on both chains. `Anchor`: no change for Etna. EtnaInbox: on a switching L1, forwards the Unzen Inbox's checkpoints to the `SignalService` until the start write, which closes forwarding at every height ([SWITCH.md](SWITCH.md#3-the-dao-proposals)). Deployment and genesis take the Etna timestamp. |
| Execution engines (taiko-geth, alethia-reth) | From the fork on: require a non-zero `parentBeaconBlockRoot` and 13 bytes of `extraData`; make the block-start staking call that SPEC.md 3.2 adds; stop treating transaction 0 as the anchor (anchor validation, anchor fee and balance exceptions, anchor gas-limit pins); accept empty blocks. Make the EIP-4788 and EIP-2935 calls identically when building and importing.                                                                                                                                                       |
| Unzen drivers and Etna ABCI application      | Retain Unzen derivation through S. From S + 1 the ABCI app validates the anchor witness, constructs the Etna payload and checks the header under SPEC §3. Nodes run the switching checks in SYNC-9-5a.                                                                                                                                                                                                                                                                                                                               |
| Unzen and Etna guests                        | Unzen guests take the inherited checkpoint from the parent block’s anchor transaction. Both Etna guests authenticate the header commitments and execution under SPEC §6.2, including S’s timestamp and the L2 SignalService and `EtnaStaking` implementations when proving from S.                                                                                                                                                                                                                                                   |
| Relayer                                      | Build the `HopProof` with `blockId` set to an L2 timestamp and `rootHash` to that block's root; take the anchor number from the L2 header; stop waiting for `CheckpointSaved` after the fork; rebuild expired proofs.                                                                                                                                                                                                                                                                                                                |
| Bridge UI                                    | Read processability from the L2 header's anchor number instead of `Anchor.getBlockState()`; build the same proofs for manual claims.                                                                                                                                                                                                                                                                                                                                                                                                 |
| Ejector                                      | Stop relying on `Anchor.getBlockState()` after the fork.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Catalyst                                     | Stop treating transaction 0 as the anchor from the fork on.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

## 10. Security considerations

- **Root authentication**: the root comes from L1, not from proposer input. Execution engines check that it is non-zero and that `extraData` has 13 bytes; derivation and the guests check that it is the state root of the L1 block at the encoded number. An Etna proposal with the wrong root fails application validation and cannot be proven by a conforming guest.
- **Proof checks**: `rootHash` must equal the resolved root, the account proof must be non-empty, and an exclusion proof reverts. The signal slot hashes the source chain ID, app and signal, so a proof cannot be reused for another chain. No caller-supplied L1 number, hash or root is trusted.
- **Fork boundary**: the L2 `SignalService` closes its checkpoint store in every block whose own EIP-4788 root is nonzero (section 4). It reads the boundary from the block, so the boundary is the one the execution engines and the guests apply and cannot come earlier or later than theirs. It rests on two facts that they enforce: a block before Etna has a zero `parentBeaconBlockRoot`, and an Etna block never has one. Each node still compares its own fork time with the EtnaInbox's before it becomes trusted, before and after the first landing ([SPEC.md SYNC-9-5a](SPEC.md#9-sync-and-weak-subjectivity)).
- **EIP-4788 entries**: there is one entry per L2 timestamp, readable for at least 8,191 seconds. A missing or overwritten entry reverts, and a missing EIP-4788 contract fails closed.
- **Storage reset**: switching the L2 `SignalService` to the `VERSION` namespace also drops any stale cached signals. Never roll it back to the flat implementation.
- **No key for new blocks**: there is nothing to leak and nothing to sign deterministically; the fixed-k signer remains only to re-derive pre-fork blocks. Clients must stop applying the anchor fee exceptions from the fork on, because golden touch transactions are ordinary there.
- **Ancestors hash**: the ring buffer re-binds L2 ancestor hashes that the stateless executor already verifies by chaining the parent hashes of the ancestor headers it is given, and the once-per-block property it enforced disappears with the transaction. EIP-2935 provides the on-chain binding of L2 block hashes instead, with no custom code.
- **Fee model**: unchanged. Nothing is executed on anyone's behalf, so base-fee sharing is not affected.

## 11. Open questions

1. **Fork scheduling**: `ETNA_FORK_TIME` is not set. The Unzen Inbox's propose cutoff and the EtnaInbox's `ETNA_FORK_TIME` derive from it ([SWITCH.md](SWITCH.md#3-the-dao-proposals)), so it has to be chosen before the scheduling proposal. No L2 contract holds it, so it can still be moved on L1 afterwards ([SWITCH.md](SWITCH.md#moving-the-fork-time)).
2. **Consumers of the anchor transaction**: whether anything else relies on the `Anchored` event or on transaction 0 being the anchor, such as explorers, indexers and tests. The known consumers of `CheckpointSaved` and `Anchor.getBlockState()` are in section 9.
