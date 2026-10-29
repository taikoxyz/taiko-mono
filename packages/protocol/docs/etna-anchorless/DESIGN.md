# Etna anchorless design

From the Etna fork on, L2 blocks carry no anchor transaction. Each block header commits to its L1 anchor block instead: the anchor block's execution state root in `parentBeaconBlockRoot` and its number in `extraData`. The standard EIP-4788 pre-execution call records the root on L2, and L2 contracts verify L1 storage proofs against it. No Taiko-specific system call or execution hook is added and every header field stays within Ethereum's limits, so the only Taiko-specific execution rule left is header validation.

This document gives the design, the contract changes and the activation order. The derivation rules are in [Derivation.md](../Derivation.md#etna-blocks-without-an-anchor-transaction).

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
| `extraData`             | 7 bytes `[basefeeSharingPctg(1) \| proposalId(6)]` | 13 bytes `[basefeeSharingPctg(1) \| proposalId(6) \| anchorBlockNumber(6)]`, both numbers big-endian `uint48`    |

Every other header field is unchanged.

- **Execution engine rule**: from the fork on, a non-genesis block must have a non-zero `parentBeaconBlockRoot` and exactly 13 bytes of `extraData`.
- **Derivation and prover rule**: the root must be the state root of the L1 block at the derived `anchorBlockNumber`, and bytes 7..12 of `extraData` must encode that number. Provers authenticate the anchor block's header through the parent-hash chain of the L1 headers they are given; before Etna they apply the same check to the anchor calldata.
- **Self-contained blocks**: a block received over P2P executes without L1 access.

Blocks that inherit their anchor (forced inclusions and default manifests) keep the parent's number and root. For an Etna parent, both come from its header. For a pre-Etna parent, they come from its L2 state: its anchor number and saved checkpoint, or the L1 header when no checkpoint exists. Genesis inheritance uses number 0 and the state root of L1 block 0; the L2 genesis header keeps a zero root and performs no EIP-4788 call.

Other derivation changes at the fork:

- Nothing is prepended to a block's transactions, so the first transaction is treated like any other, and the zk gas limit can abort it.
- A default source manifest yields an empty block.
- Transactions from the golden touch address are ordinary transactions.
- The 1,000,000 gas reserve applies only before the fork.

The proposal format and metadata validation are unchanged.

## 3. Recording through EIP-4788

Because the root is in `parentBeaconBlockRoot`, the EIP-4788 pre-execution call that every post-Cancun execution client already makes stores it in the beacon roots contract at `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`, keyed by the L2 block timestamp. The contract is a ring buffer indexed by `timestamp % 8191`, so an entry stays readable until a later block's timestamp has the same remainder: at least 8,191 seconds, about 2.3 hours. Derived L2 timestamps strictly increase, so every block has its own entry.

There is no new system call into the `SignalService`, no synthetic receipt and nothing for the provers to implement beyond upstream EIP-4788 behaviour. The contract also serves any L2 contract as a short-term oracle of recent L1 state roots.

## 4. Bridge verification

The `Anchor`, already the L2 `SignalService`'s authorized syncer, resolves the root for a proof, and `SignalServiceL2` overrides one hook of the shared `SignalService`:

```solidity
// Anchor
function getL1StateRoot(uint64 blockId) external view returns (bytes32 stateRoot) {
    if (block.timestamp < etnaTimestamp) {
        // Before the fork: blockId is an L1 block number; read the saved checkpoint.
        require(blockId <= type(uint48).max);
        stateRoot = checkpointStore.getCheckpoint(uint48(blockId)).stateRoot;
    } else {
        // From the fork on: blockId is an L2 timestamp; read EIP-4788, which reverts
        // for a missing or overwritten entry and returns nothing without code.
        require(blockId >= etnaTimestamp);
        stateRoot = BEACON_ROOTS.get(blockId);
    }
    require(stateRoot != 0);
}

// SignalServiceL2
function _getStateRoot(uint64 blockId) internal view override returns (bytes32) {
    return IL1StateRootProvider(_authorizedSyncer).getL1StateRoot(blockId);
}
```

- **Proof format**: the existing single-hop `HopProof`. Its `blockId` is an L1 block number before the fork and an L2 timestamp from the fork on; the timestamp of the L2 block that verifies the proof decides which. `rootHash` must equal the resolved root, and the account and storage proofs are checked against the L1 `SignalService` as before. No caller-supplied L1 number, hash or root is trusted.
- **No checkpoints after the fork**: from the fork on, proofs never read checkpoints. A signal proven once stays cached, and an empty proof for a cached signal keeps working after its EIP-4788 entry expires.
- **L1 unchanged**: `SignalService` stays shared L1 and L2 code. Its base keeps the checkpoint path with the `uint48` bound.
- **Storage**: `SignalServiceL2` keeps checkpoints and cached signals in the `VERSION` storage namespace of the current `SignalService`; section 8 covers the migration.
- **Fork time**: `etnaTimestamp` is an immutable of the `Anchor`. It must equal the clients' fork time, and it also gates `anchorV4` (section 8).

To build a proof off chain:

1. Pick a recent L2 block and read the anchor number from bytes 7..12 of its `extraData`. It must be at or after the L1 block that sent the message.
2. Fetch `eth_getProof` for the L1 `SignalService` at that L1 block. Many L1 nodes serve it only for recent blocks, another reason to use a recent L2 block.
3. Set `blockId` to the L2 block's timestamp and `rootHash` to its `parentBeaconBlockRoot`.

A proof must be rebuilt once its timestamp leaves the EIP-4788 window. From the fork on there are no new `CheckpointSaved` events and `Anchor.getBlockState().anchorBlockNumber` stops moving, so processability checks read the anchor number from L2 headers.

## 5. Liveness

While L2 produces blocks, a recent root is always inside the EIP-4788 window. A newer L1 state root proves everything an older one did, because L1 signal slots are never cleared, so old roots are never needed. If L2 stops producing blocks, nothing is bridged anyway. Forced-inclusion and default-manifest blocks inherit the parent's number and root, so there is no anchor transaction to construct for them. If the EIP-4788 contract has no code at the fork, uncached L1 → L2 proofs fail closed until it is deployed (section 7).

## 6. Why the state root rather than the block hash

The header could instead carry the L1 block hash in `parentBeaconBlockRoot`, keep `extraData` at 7 bytes, and rely on a permissionless call that proves a header preimage against the recorded hash and stores a checkpoint for the bridge. The state root is used because:

- There is no reveal transaction (about 100,000 gas per checkpoint), no new checkpoint storage and no re-emitted `CheckpointSaved`: the bridge reads the root by L2 timestamp.
- The anchor number in `extraData` lets drivers, provers, relayers and the bridge UI read it from the header, without decoding header RLP or scanning L1.
- L2 contracts do not get L1 block hashes directly, but they remain provable from an L1 state root through L1's own EIP-2935 (block n − 1 and older) and EIP-4788 storage, at the cost of one more Merkle-proof hop.

## 7. Prerequisite: EIP-4788 and EIP-2935 on L2

The EIP-4788 contract (`0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`) and the EIP-2935 contract (`0x0000F90827F1C53a10cb7A02335B175320002935`) must have code on L2 before the fork. Unzen already enables the Prague pre-execution calls, but EIP-4788 requires the call to fail silently when the address has no code, so on a network whose genesis lacks the contracts both calls do nothing.

Ethereum deployed both as ordinary contracts through Nick's method ahead of the respective forks (EIP-4788 before Cancun, EIP-2935 before Prague); clients never insert the code. Taiko does the same, but the order matters: every builder, importer and prover must already execute a state-writing pre-execution call identically before its contract exists, or deploying the contract splits the chain.

- **Build and import must agree.** Each execution engine makes both calls on the block-building path exactly as on the import path, with a zero `parentBeaconBlockRoot` before Etna. An engine that skips the EIP-4788 call while building and stamps the zero root afterwards produces blocks without the call's two storage writes once the contract has code. Every node, not only sequencers, builds through the Engine API during L1 derivation (`forkchoiceUpdated`, `getPayload`, `newPayload`), so such a node would reject its own derived blocks.
- **Provers follow the import path**, so they agree with importers.

Order of operations:

1. Every execution engine makes both calls identically when building and importing. With no code at the addresses this changes nothing, so it ships as a normal release without a fork.
2. Deploy EIP-2935 (test network first, then mainnet). It starts recording L2 block hashes at once, because the Prague call has run since Unzen, and lets witness generation be validated against the history contract before the fork.
3. Deploy EIP-4788 once step 1 runs on every node (test network first, then mainnet). The contract then records zero roots, harmlessly, until the fork switches `parentBeaconBlockRoot` to the L1 anchor state root.
4. The fork comes last, with both contracts deployed and the contract and prover upgrades of section 8 executed. New networks put both contracts in the genesis alloc instead of steps 2 and 3.

To deploy each contract, fund its canonical deployer and broadcast the presigned pre-EIP-155 transaction through a node that accepts unprotected transactions. The deployers are `0x0B799C86a49DEeb90402691F1041aa3AF2d3C875` for EIP-4788 and `0x3462413Af4609098e1E27A490f554f260213D685` for EIP-2935. Each transaction uses nonce 0, a gas limit of 250,000 and a gas price of 1,000 gwei, so each deployer needs a 0.25 ETH prefund; the remainder is refunded. Alternatively, a fork block can insert the canonical deployment transactions, as OP Stack did in Ecotone, so both contracts land at the L1 addresses on every network deterministically.

With EIP-2935 in place, the L2 matches Ethereum's post-Prague state: `BLOCKHASH` semantics are unchanged, and the last 8,191 L2 block hashes are readable on chain, which replaces the binding the ancestors hash provided.

## 8. Fork and migration

- **Activation**: Etna activates by L2 timestamp at `ETNA_FORK_TIME`. Each L2 block follows the fork active at its own timestamp, so one proposal can contain blocks of both forks. Pre-fork blocks keep the anchor transaction and a zero `parentBeaconBlockRoot`; post-fork blocks have no anchor transaction, a non-zero `parentBeaconBlockRoot` and 13 bytes of `extraData`.
- **`anchorV4` gate**: `Anchor.anchorV4` reverts from `etnaTimestamp` on. The gate is required. The ancestors-hash check excludes the parent, so in the first block without an anchor transaction an `anchorV4` sent as an ordinary transaction would still pass. The golden touch key is public, and also usable through an EIP-7702 delegation, so anyone could then save a forged checkpoint. A later clean-up upgrade can delete `anchorV4`, `blockHashes`, the block state and the ancestors hash, but must keep `withdraw` and `getL1StateRoot`.
- **Checkpoints**: pre-fork checkpoints stay in storage, but proofs stop reading them at the fork. `SignalService.saveCheckpoint` and its authorized syncer stay for L1, where the Inbox keeps saving L2 → L1 checkpoints.
- **Storage namespace**: `SignalServiceL2` uses the `VERSION` storage namespace, while the L2 `SignalService` deployed before Etna uses flat mappings. The upgrade therefore leaves the old checkpoints and cached signals unreadable; legitimate signals are proven again against a newer root. Provers that read the parent checkpoint read both layouts: the versioned mapping at base `keccak256(abi.encode(VERSION, 254))` first, then the flat slot `keccak256(abi.encode(blockNumber, 254))` when the versioned one is empty.

### Upgrade order

Each step depends on the previous one.

1. **Execution engines, then EIP-2935 and EIP-4788 on L2** (section 7). If EIP-4788 has no code when the fork activates, every uncached L1 → L2 proof reverts until it is deployed.
2. **Provers read both checkpoint layouts.** After the upgrade in step 3, new checkpoints land in the versioned mapping. Every guest in the proof combinations used must read both layouts. The new guests also prove the current layout, so they can ship early.
3. **One DAO proposal, executed well before `ETNA_FORK_TIME`:**

   - Its L1 actions trust the new guest images, and SGX enclaves if used. They take effect when the proposal executes, before its L2 part reaches L2.
   - One L2 message to the `DelegateController` upgrades both proxies: the `Anchor` (`anchorV4` gated by `etnaTimestamp`, plus `getL1StateRoot`) and the `SignalService` to `SignalServiceL2`. Its last action calls `Anchor.etnaTimestamp()`, so if the `Anchor` upgrade is missing, the whole batch reverts and the message stays retriable.

   Both proxies go in one batch because `SignalServiceL2` asks the `Anchor` for every uncached root, and the `Anchor` deployed before Etna has no `getL1StateRoot`. Upgrading the `SignalService` alone would make every uncached L1 → L2 proof revert, including the message that would upgrade the `Anchor`; the namespace switch also empties the received-signal cache, so nothing could reach L2 again. The guest images go first because a proposal with a forced inclusion or a stalled anchor reads its parent checkpoint from the versioned mapping, which old guests cannot prove, so finalization would stop until new ones are trusted.

4. **Relayers and the bridge UI.** Checkpoints saved before the `SignalService` upgrade are no longer readable, so L1 → L2 processing waits until a post-upgrade `CheckpointSaved` is indexed, or treats `SS_CHECKPOINT_NOT_FOUND` as transient. Proof builders that set `blockId` to an L2 timestamp and `rootHash` to that block's `parentBeaconBlockRoot` must ship before the fork. A proof built before the fork must be rebuilt after it, and a timestamp that has left the EIP-4788 window needs a fresh proof.
5. **The fork.** Clients activate Etna at `ETNA_FORK_TIME`. Once step 3 has executed, the fork time is fixed on chain. Moving it needs another L2 upgrade that executes before the old time, because from then on uncached L1 → L2 proofs fail until the clients actually fork.
6. **Afterwards.** Never roll the L2 `SignalService` back to the flat implementation, which would revive the pre-upgrade checkpoints and cached signals. A later `Anchor` clean-up must keep `getL1StateRoot`.

## 9. Changes by component

| Component                                    | Change                                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Protocol contracts                           | `Anchor`: the `etnaTimestamp` gate on `anchorV4` and `getL1StateRoot(blockId)` (checkpoint before the fork, EIP-4788 from the fork on). `SignalServiceL2`: roots from the `Anchor`, `VERSION` storage. Shared `SignalService`: a `_getStateRoot` hook; L1 behaviour unchanged. Deployment and genesis take the Etna timestamp. |
| Execution engines (taiko-geth, alethia-reth) | From the fork on: require a non-zero `parentBeaconBlockRoot` and 13 bytes of `extraData`; stop treating transaction 0 as the anchor (anchor validation, anchor fee and balance exceptions, anchor gas-limit pins); accept empty blocks. Make the EIP-4788 and EIP-2935 calls identically when building and importing.          |
| Clients (Go and Rust)                        | Set `parentBeaconBlockRoot` and the 13-byte `extraData`, and stop constructing the anchor transaction from the fork on; apply the 1,000,000 gas reserve only before it; read an Etna parent's anchor number from its `extraData`; keep the fixed-k signer only to re-derive pre-fork blocks.                                   |
| Provers (raiko2, gaiko2)                     | Verify `parentBeaconBlockRoot` and `extraData` against the derived L1 anchor; drop the anchor-transaction checks for Etna blocks; read the parent checkpoint from both `SignalService` layouts.                                                                                                                                |
| Relayer                                      | Build the `HopProof` with `blockId` set to an L2 timestamp and `rootHash` to that block's root; take the anchor number from the L2 header; stop waiting for `CheckpointSaved` after the fork; rebuild expired proofs.                                                                                                          |
| Bridge UI                                    | Read processability from the L2 header's anchor number instead of `Anchor.getBlockState()`; build the same proofs for manual claims.                                                                                                                                                                                           |
| Ejector                                      | Stop relying on `Anchor.getBlockState()` after the fork.                                                                                                                                                                                                                                                                       |
| Catalyst                                     | Stop treating transaction 0 as the anchor from the fork on.                                                                                                                                                                                                                                                                    |

## 10. Security considerations

- **Root authentication**: the root comes from L1, not from proposer input. Execution engines check that it is non-zero and that `extraData` has 13 bytes; derivation and the guests check that it is the state root of the L1 block at the encoded number. A preconfirmed block with a wrong root cannot be derived from L1 and is reorged out, the same trust as an anchor checkpoint before Etna.
- **Proof checks**: `rootHash` must equal the resolved root, the account proof must be non-empty, and an exclusion proof reverts. The signal slot hashes the source chain ID, app and signal, so a proof cannot be reused for another chain. No caller-supplied L1 number, hash or root is trusted.
- **Fork boundary**: `anchorV4` is gated by `etnaTimestamp` (section 8), which must equal the clients' fork time. If the gate came later, the first anchorless blocks could save forged checkpoints. If it came earlier, anchor transactions would revert silently and uncached L1 → L2 proofs would fail until the clients fork. A proof built before the fork must be rebuilt after it.
- **EIP-4788 entries**: there is one entry per L2 timestamp, readable for at least 8,191 seconds. A missing or overwritten entry reverts, and a missing EIP-4788 contract fails closed.
- **Storage reset**: switching the L2 `SignalService` to the `VERSION` namespace also drops any stale cached signals. Never roll it back to the flat implementation.
- **No key for new blocks**: there is nothing to leak and nothing to sign deterministically; the fixed-k signer remains only to re-derive pre-fork blocks. Clients must stop applying the anchor fee exceptions from the fork on, because golden touch transactions are ordinary there.
- **Ancestors hash**: the ring buffer re-binds L2 ancestor hashes that the stateless executor already verifies by chaining the parent hashes of the ancestor headers it is given, and the once-per-block property it enforced disappears with the transaction. EIP-2935 provides the on-chain binding of L2 block hashes instead, with no custom code.
- **Fee model**: unchanged. Nothing is executed on anyone's behalf, so base-fee sharing is not affected.

## 11. Open questions

1. **Fork scheduling**: `ETNA_FORK_TIME` is not set. The `Anchor`'s `etnaTimestamp` must equal it and is fixed once the upgrade executes, so it has to be chosen before the DAO proposal (section 8).
2. **Consumers of the anchor transaction**: whether anything else relies on the `Anchored` event or on transaction 0 being the anchor, such as explorers, indexers and tests. The known consumers of `CheckpointSaved` and `Anchor.getBlockState()` are in section 9.
