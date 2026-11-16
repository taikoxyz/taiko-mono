# Etna anchorless design

From the Etna fork on, L2 blocks carry no anchor transaction. Each block header commits to its L1 anchor block instead: the anchor block's execution state root in `parentBeaconBlockRoot` and its number in `extraData`. An extended EIP-4788 contract writes a bridge checkpoint, consisting of the L2 block timestamp and that L1 state root, into the L2 `SignalService`. The existing EIP-4788 system call keeps its address, caller and 32-byte root input; the timestamp comes from `block.timestamp`. The contract bytecode and its installation at the fork are Taiko-specific, but no additional system call or calldata field is needed, and every header field stays within Ethereum's limits.

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
- A default source manifest yields an empty block.
- Transactions from the golden touch address are ordinary transactions.
- The 1,000,000 gas reserve applies only before the fork.

The proposal and manifest descriptions in this document and `Derivation.md` describe the earlier proposal-based flow and await a separate rewrite. Etna block production and metadata validation follow [SPEC.md section 3](SPEC.md#3-consensus-and-blocks).

## 3. Recording through EIP-4788

The pre-execution call remains the [EIP-4788 call](https://eips.ethereum.org/EIPS/eip-4788#block-processing): caller `SYSTEM_ADDRESS` (`0xfffffffffffffffffffffffffffffffffffffffe`), destination `BEACON_ROOTS` (`0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`), calldata exactly the 32 bytes of `header.parentBeaconBlockRoot`, the existing system-call gas allowance, and zero value. No timestamp, L1 number, block hash or header is added to the calldata.

At the fork, the bytecode at `BEACON_ROOTS` is replaced with an extended implementation (section 7). It retains the standard ring-buffer writes and timestamp-based read interface. Its system-caller branch additionally calls the L2 `SignalService` to save `(block.timestamp, root)`. Ordinary callers can only read the ring buffer; they cannot trigger a checkpoint write. The extension's `SignalService` proxy address and fork time are fixed by the deployment configuration.

The following is a call-flow sketch, not a replacement for the EIP-4788 runtime:

```text
execution engine -> BEACON_ROOTS, from SYSTEM_ADDRESS, calldata = root (32 bytes)
  write the standard EIP-4788 timestamp/root ring-buffer entries
  SignalService.saveBridgeCheckpoint(uint64(block.timestamp), root)
```

The `SignalService` accepts this new entry point only from `BEACON_ROOTS`, only at or after its configured Etna time, only for a timestamp equal to the current L2 `block.timestamp`, and only for a nonzero root. The timestamp must fit `uint64` before conversion. A repeated write of the same timestamp and root is harmless; a different root at an already written timestamp reverts. The extension propagates a failed nested write, so its ring-buffer update and the bridge checkpoint succeed or revert together. The engine keeps the existing EIP-4788 call-error handling; this does not add a rule making an EVM revert invalidate the block. A missing checkpoint makes uncached bridge proofs fail closed.

The bridge store is a persistent mapping from timestamp to root, separate from the EIP-4788 ring buffer. It uses the timestamp as its key, so no duplicate timestamp field or block hash is stored in each value. Zero means absent. These records do not expire when the ring buffer wraps, at the cost of one additional root slot per L2 block, including blocks that keep the same L1 anchor. Storage growth and execution/proving cost must be checked before launch; no measured cost is assumed here.

There is no anchor transaction or synthetic receipt. Logs emitted inside the system call are not ordinary transaction-receipt logs and are not the relayer's discovery mechanism. Every execution engine and guest must execute the extended bytecode, including the nested call and its state changes, on the build, import and proving paths. A shortcut that directly performs only the standard EIP-4788 storage writes is incompatible with this extension.

## 4. Bridge verification

The bridge's Merkle-proof verifier needs an authenticated state root, not a block hash. From the fork on, the L2 `SignalService` reads that root from its own bridge-checkpoint store. There is no read through `Anchor.getL1StateRoot`, no proof-time EIP-4788 call and no `SignalServiceL2` root-provider subclass.

The new L2 entry points are `saveBridgeCheckpoint(uint64 timestamp, bytes32 stateRoot)` and `getBridgeCheckpoint(uint64 timestamp) returns (bytes32 stateRoot)`. The getter reverts for a timestamp before the fork or an absent record. The existing single-hop `HopProof` and account/storage-proof checks remain: the verifier resolves a nonzero root, requires `proof.rootHash` to equal it, and verifies the signal under the remote `SignalService` account. Both chains can share this verification logic; their checkpoint identifiers still have different meanings.

- **L1 → L2 proof identifiers**: before the fork, `HopProof.blockId` is an L1 block number and the root comes from the full checkpoint. From the fork on, it is the timestamp of the L2 block that recorded the root, not the L1 anchor's timestamp; the root comes only from the new bridge store. The timestamp of the L2 block verifying the proof selects the path. Legacy block-number keys and new timestamp keys live in separate mappings, and a post-fork proof never falls back to a legacy checkpoint.
- **Caching**: a signal proven once stays cached. An empty proof for a cached signal keeps working across the fork, subject to the namespace migration in section 8. Uncached proofs against a retained bridge checkpoint remain usable after the EIP-4788 ring-buffer entry expires.
- **Full checkpoints remain separate**: the existing `(blockNumber, blockHash, stateRoot)` records and `saveCheckpoint`/`getCheckpoint` interfaces remain for non-bridge consumers that require them. In particular, L1 keeps every Unzen and Etna checkpoint, the first-landing check at S still compares its block hash and state root, and L2 → L1 bridge proofs continue to use the root of the checkpoint indexed by L2 block number. The L1 switch's two syncers and the Unzen height limit are unchanged ([SWITCH.md](SWITCH.md#3-the-dao-proposal)). No timestamp is substituted for those heights, and no block hash is discarded or fabricated.
- **Authorization**: the L2 `Anchor` stays the writer of full checkpoints before the fork; `BEACON_ROOTS` is authorized only for the new bridge-checkpoint entry point. Neither ordinary callers nor the public golden touch key can write a post-fork bridge checkpoint. The L1 implementation does not enable this L2 system-contract writer.
- **Storage**: the new bridge mapping has a dedicated storage namespace and is versioned by `VERSION`; it does not reuse or reinterpret the full-checkpoint slots. Full checkpoints and cached signals retain their existing versioned layouts, with the L2 upgrade migration described in section 8. Adding the bridge mapping does not bump `VERSION` on either chain.
- **Fork time**: the clients, extended EIP-4788 runtime and L2 `SignalService` use the same `etnaTimestamp` as the `Anchor`'s gate on `anchorV4`. The L2 upgrade batch checks the contract configurations agree before it succeeds.

To build a proof off chain:

1. Pick a recent L2 block and read the anchor number from bytes 7..12 of its `extraData`. It must be at or after the L1 block that sent the message.
2. Fetch `eth_getProof` for the L1 `SignalService` at that L1 block. Many L1 nodes serve it only for recent blocks, another reason to use a recent L2 block.
3. Check that `SignalService.getBridgeCheckpoint` at the L2 block's timestamp returns its `parentBeaconBlockRoot`. Set `blockId` to that timestamp and `rootHash` to that root.

The resulting proof does not expire with the EIP-4788 window. Relayers still prefer recent roots because L1 RPCs may not serve historical storage proofs. From the fork on there are no ordinary transaction-receipt `CheckpointSaved` events for these L2 writes, and `Anchor.getBlockState().anchorBlockNumber` stops moving. Relayers and processability checks discover roots and anchor numbers from L2 headers and confirm the corresponding `SignalService` record; they do not wait for a system-call log.

## 5. Liveness

Each Etna block records its anchor root in the persistent bridge store before user transactions run. A newer L1 state root proves every previously sent signal because L1 signal slots are never cleared; a relayer may choose a newer checkpoint if it cannot fetch an old L1 storage proof. Previously built proofs remain usable even after the standard EIP-4788 ring buffer wraps.

Forced-inclusion and default-manifest blocks keep the parent's anchor number and root but record it under their own strictly increasing L2 timestamp. There is no anchor transaction to construct. If L2 stops producing blocks, no claim transaction can execute. If a system write fails, uncached claims against that missing timestamp fail closed; retained checkpoints and cached signals remain usable, and a later successful write provides a new root. The deployment and fork checks must prevent a missing or misconfigured extension (section 7).

## 6. Why the state root rather than the block hash

The header could instead carry the L1 block hash in `parentBeaconBlockRoot`, keep `extraData` at 7 bytes, and rely on a permissionless call that proves a header preimage against the recorded hash and stores a checkpoint for the bridge. The state root is used because:

- The existing system-call input already supplies the state root, and `block.timestamp` supplies the bridge-checkpoint key. No reveal transaction or extra authenticated L1 header fields are needed. The extension adds persistent root storage, but no synthetic receipt or relayer dependency on a re-emitted `CheckpointSaved`.
- The anchor number in `extraData` lets drivers, provers, relayers and the bridge UI read it from the header, without decoding header RLP or scanning L1.
- L2 contracts do not get L1 block hashes directly, but they remain provable from an L1 state root through L1's own EIP-2935 (block n − 1 and older) and EIP-4788 storage, at the cost of one more Merkle-proof hop.

## 7. Prerequisite: EIP-4788 and EIP-2935 on L2

The EIP-4788 contract (`BEACON_ROOTS`) and the EIP-2935 contract (`0x0000F90827F1C53a10cb7A02335B175320002935`) must have code on L2 before the fork. Unzen already enables the Prague pre-execution calls, but EIP-4788 requires the call to fail silently when the address has no code, so on a network whose genesis lacks the contracts both calls do nothing. At Etna activation, `BEACON_ROOTS` must run the extended bytecode from section 3, with the correct `SignalService` proxy address and fork time.

The canonical Ethereum contracts can be deployed as ordinary contracts through Nick's method before Etna. That deploys only their canonical bytecode: the EIP-4788 presigned transaction cannot deploy the extension, and an existing canonical EIP-4788 contract is not an upgradeable proxy. This design therefore requires an explicit fork-state code installation at `BEACON_ROOTS`, before the first Etna pre-execution call. It replaces only that account's code, preserves existing storage and account metadata, and installs the same deployment-specific runtime on every builder, importer and prover. The system-call destination and input do not change. New networks put the extended runtime in the genesis allocation instead; it performs no bridge write before its configured fork time.

- **Build, import and proving must agree.** Every execution engine and guest installs the extended code at the same fork boundary and actually executes the contract, including its call into `SignalService`. Matching only the standard EIP-4788 ring-buffer writes is insufficient. Before Etna the ordinary calls still run with a zero `parentBeaconBlockRoot`; after Etna the nonzero root is recorded before user transactions. Every node that builds through the Engine API must produce the same state as an importer.
- **Configuration must agree.** Clients and guests pin the extended runtime and its `SignalService` address and fork time. The L2 upgrade batch checks the `SignalService`'s activation time and authorized system writer against that configuration. Moving the fork time requires rebuilding and updating the scheduled runtime as well as the contracts and clients.

Order of operations:

1. Every execution engine makes both calls identically when building and importing, and clients and guests support the scheduled extended-runtime installation and execution. With no code at the addresses the existing calls change nothing; the new code installation activates only at Etna.
2. Deploy EIP-2935 (test network first, then mainnet). It starts recording L2 block hashes at once, because the Prague call has run since Unzen, and lets witness generation be validated against the history contract before the fork.
3. Deploy canonical EIP-4788 once step 1 runs on every node (test network first, then mainnet), if it is absent. It records zero roots until Etna and lets the existing pre-execution paths be checked before activation.
4. Execute the contract and prover upgrades of section 8. Confirm the L2 `SignalService` accepts the extended contract's bridge writes from the configured fork time, while the pre-fork full-checkpoint bridge path still works.
5. At the fork, install the extended EIP-4788 runtime before processing the system call. The first Etna block supplies its nonzero anchor root and writes the first bridge checkpoint before its user transactions. Check its timestamp/root record in `SignalService`. New networks put both system contracts in genesis, using the extended EIP-4788 runtime instead of the canonical one.

For the canonical deployments in steps 2 and 3, fund the canonical deployer and broadcast the presigned pre-EIP-155 transaction through a node that accepts unprotected transactions. The deployers are `0x0B799C86a49DEeb90402691F1041aa3AF2d3C875` for EIP-4788 and `0x3462413Af4609098e1E27A490f554f260213D685` for EIP-2935. Each transaction uses nonce 0, a gas limit of 250,000 and a gas price of 1,000 gwei, so each deployer needs a 0.25 ETH prefund; the remainder is refunded. These transactions do not perform step 5's custom code installation.

With EIP-2935 in place, the L2 matches Ethereum's post-Prague state: `BLOCKHASH` semantics are unchanged, and the last 8,191 L2 block hashes are readable on chain, which replaces the binding the ancestors hash provided.

## 8. Fork and migration

- **Activation**: Etna activates by L2 timestamp at `ETNA_FORK_TIME`. The Unzen Inbox accepts no proposal from shortly before that time, so every Unzen block is earlier and every Etna block is at or after it ([SWITCH.md](SWITCH.md)). Pre-fork blocks keep the anchor transaction and a zero `parentBeaconBlockRoot`; post-fork blocks have no anchor transaction, a non-zero `parentBeaconBlockRoot` and 13 bytes of `extraData`.
- **`anchorV4` gate**: `Anchor.anchorV4` reverts from `etnaTimestamp` on. The ancestors-hash check excludes the parent, so the first ordinary transaction using the public golden touch key could otherwise still invoke this obsolete privileged path. The L2 `SignalService` also rejects the `Anchor`'s full-checkpoint writes from that time on. The post-fork bridge path reads only the new system-written records, so an old full checkpoint cannot become a bridge root. A later clean-up upgrade can delete `anchorV4`, `blockHashes`, the block state and the ancestors hash, but must keep `withdraw`; it does not need a `getL1StateRoot` adapter.
- **Checkpoints**: keep full checkpoints separate from the new timestamp/root bridge records. On L2, pre-fork proofs use full checkpoints until the fork and then switch to the bridge mapping without fallback. On L1, `saveCheckpoint`, the full records and their authorized syncers stay: the EtnaInbox saves checkpoints above the Etna start and the Unzen Inbox's final proofs save those at or below it ([SWITCH.md](SWITCH.md#6-bridge-during-and-after-the-switch)). The first-landing check and other full-checkpoint consumers are unchanged.
- **Storage namespace**: the upgraded L2 `SignalService` uses the existing `VERSION` namespace for full checkpoints and cached signals; its pre-upgrade implementation uses flat mappings. The upgrade leaves the flat records in place but unreadable through the upgraded contract; legitimate signals are proven again against a post-upgrade checkpoint. The new bridge mapping has its own namespace, starts empty and does not move or reinterpret either full-checkpoint layout. Provers that read a pre-Etna parent checkpoint read both full layouts: the versioned mapping at base `keccak256(abi.encode(VERSION, 254))` first, then the flat slot `keccak256(abi.encode(blockNumber, 254))` when the versioned one is empty. L1's `VERSION` and full checkpoints are preserved.

### Upgrade order

Each step depends on the previous one.

1. **Execution engines, then EIP-2935 and canonical EIP-4788 on L2** (section 7). Every engine and guest also supports the scheduled installation of the extended runtime at Etna. The canonical runtime alone cannot write post-fork bridge checkpoints.
2. **Provers read both checkpoint layouts.** After the upgrade in step 3, new checkpoints land in the versioned mapping. Every guest in the proof combinations used must read both layouts. The new guests also prove the current layout, so they can ship early.
3. **One DAO proposal, executed well before `ETNA_FORK_TIME`:**

   - Its L1 actions trust the new guest images, and SGX enclaves if used. They take effect when the proposal executes, before its L2 part reaches L2.
   - One L2 message to the `DelegateController` upgrades both proxies: the `Anchor` (`anchorV4` gated by `etnaTimestamp`) and the `SignalService` (the pre-fork full-checkpoint path, the new bridge mapping and its system-writer authorization). The batch checks that their fork times agree with the configured extended runtime and that the `SignalService` authorizes `BEACON_ROOTS` only for bridge writes. Its last action calls `Anchor.etnaTimestamp()`, so if the `Anchor` upgrade is missing, the whole batch reverts and the message stays retriable.

   Both proxies go in one batch to coordinate the anchor gate and bridge activation. The `SignalService` retains the pre-fork full-checkpoint path, so upgrading it does not require an `Anchor` root getter and does not enable timestamp/root writes early. The guest images go first because a proposal with a forced inclusion or a stalled anchor reads its parent checkpoint from the versioned mapping, which old guests cannot prove, so finalization would stop until new ones are trusted.

   This is the switch proposal in [SWITCH.md](SWITCH.md#3-the-dao-proposal), which also carries the switch's L1 actions.

4. **Relayers and the bridge UI.** Before the fork, full checkpoints saved before the `SignalService` upgrade are no longer readable, so processing waits for a post-upgrade `CheckpointSaved` or treats `SS_CHECKPOINT_NOT_FOUND` as transient. From the fork on, discover roots from L2 headers and query `SignalService.getBridgeCheckpoint`; stop waiting for `CheckpointSaved` receipt logs. Ship timestamp-based proof builders before the fork. Rebuild proofs made before the fork; post-fork proofs need no rebuild solely because the EIP-4788 ring buffer wraps.
5. **The switch.** Etna starts as described in [SWITCH.md](SWITCH.md#4-switch-day): the Unzen Inbox stops accepting proposals shortly before `ETNA_FORK_TIME`, and the first Etna block has a timestamp at or after it. Install the extended runtime before that block's system call and verify the first bridge checkpoint. Once step 3 has executed, the fork time is fixed on chain in the `Anchor`, L2 `SignalService`, Unzen Inbox and EtnaInbox, and pinned in the clients and extended runtime. Moving it needs coordinated updates of all of them before the old propose cutoff, including the scheduled runtime installation.
6. **Afterwards.** Never roll the L2 `SignalService` back to the flat implementation, which would revive the pre-upgrade checkpoints and cached signals, or restore the canonical EIP-4788 runtime, which would stop new bridge writes. Preserve the bridge mapping across upgrades. A later `Anchor` clean-up must keep `withdraw`.

## 9. Changes by component

| Component                                    | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Protocol contracts                           | `Anchor`: gate `anchorV4` by `etnaTimestamp`. Extended EIP-4788 runtime: keep the standard ring buffer and write timestamp/root bridge checkpoints into `SignalService`. L2 `SignalService`: authorize that writer, add separate persistent bridge storage and resolve post-fork proofs from it; preserve full checkpoints separately. L1 keeps the full-checkpoint path and adds the EtnaInbox as a syncer ([SWITCH.md](SWITCH.md#3-the-dao-proposal)). |
| Execution engines (taiko-geth, alethia-reth) | Install the extended runtime at Etna before the unchanged EIP-4788 call; execute its nested `SignalService` write identically when building and importing. Require a nonzero `parentBeaconBlockRoot` and 13 bytes of `extraData`; remove the anchor transaction's validation, fee/balance exceptions and gas-limit pins; accept empty blocks. Keep EIP-2935 processing unchanged.                                                                        |
| Clients (Go and Rust)                        | Set `parentBeaconBlockRoot` and the 13-byte `extraData`, and stop constructing the anchor transaction from the fork on; apply the 1,000,000 gas reserve only before it; read an Etna parent's anchor number from its `extraData`; keep the fixed-k signer only to re-derive pre-fork blocks; on a switching network, check the start under SPEC SYNC-9-5a, which needs the L2 state at S until the first landing.                                        |
| Provers (raiko2, gaiko2)                     | Verify the root and anchor number against L1; execute the extended-runtime installation and nested checkpoint write; drop Etna anchor-transaction checks; retain both full-checkpoint layouts for pre-Etna parents. In the first proof from the Etna start, check the `Anchor` implementation at S under SPEC PROOF-6.2-46a.                                                                                                                             |
| Relayer                                      | Discover timestamp/root records from L2 headers and confirm them through `SignalService.getBridgeCheckpoint`. Set `HopProof.blockId` to the L2 timestamp and `rootHash` to that block's root; take the anchor number from `extraData`. Stop waiting for post-fork `CheckpointSaved` receipt logs. Rebuild pre-fork proofs; retained post-fork checkpoints do not expire.                                                                                 |
| Bridge UI                                    | Read processability from the L2 header's anchor number instead of `Anchor.getBlockState()`; query the recorded root and build the same timestamp-based proofs for manual claims.                                                                                                                                                                                                                                                                         |
| Ejector                                      | Stop relying on `Anchor.getBlockState()` after the fork.                                                                                                                                                                                                                                                                                                                                                                                                 |
| Catalyst                                     | Stop treating transaction 0 as the anchor from the fork on.                                                                                                                                                                                                                                                                                                                                                                                              |

## 10. Security considerations

- **Root authentication**: the root comes from L1, not from proposer input. Execution engines check that it is non-zero and that `extraData` has 13 bytes; derivation and the guests check that it is the state root of the L1 block at the encoded number. A preconfirmed block with a wrong root cannot be derived from L1 and is reorged out, the same trust as an anchor checkpoint before Etna.
- **Proof checks**: `rootHash` must equal the resolved root, the account proof must be non-empty, and an exclusion proof reverts. The signal slot hashes the source chain ID, app and signal, so a proof cannot be reused for another chain. No caller-supplied L1 number, hash or root is trusted.
- **Fork boundary**: the anchor gate, L2 `SignalService` activation and extended-runtime installation share the clients' `etnaTimestamp` (sections 7 and 8). Before it, full checkpoints still serve the bridge; from it, only the new timestamp/root records do. A proof built before the fork must be rebuilt after it. Old full checkpoints cannot be used as a fallback or written through the new system entry point.
- **Writer authentication**: only the extended runtime's system-caller branch may forward a root to the new `SignalService` entry point. The latter checks the caller, fork time, timestamp and nonzero root. The runtime is fixed by fork configuration; a public setter or a caller-supplied forwarding target is not permitted.
- **Checkpoint retention**: the bridge mapping persists independently of the EIP-4788 ring buffer, whose ordinary reads still revert for missing or overwritten entries. Missing bridge records fail closed. The nested write is atomic with the ring-buffer update; execution clients do not fabricate successful checkpoints when the call reverts.
- **Execution consistency**: every builder, importer and guest must install and execute the same extended runtime, including its nested call. There is no additional Engine API field, external L1 lookup or synthetic receipt. State growth and system-call execution/proving costs need launch validation.
- **Storage reset**: switching the L2 `SignalService` to the `VERSION` namespace also drops any stale cached signals. Never roll it back to the flat implementation.
- **No key for new blocks**: there is nothing to leak and nothing to sign deterministically; the fixed-k signer remains only to re-derive pre-fork blocks. Clients must stop applying the anchor fee exceptions from the fork on, because golden touch transactions are ordinary there.
- **Ancestors hash**: the ring buffer re-binds L2 ancestor hashes that the stateless executor already verifies by chaining the parent hashes of the ancestor headers it is given, and the once-per-block property it enforced disappears with the transaction. EIP-2935 provides the on-chain binding of L2 block hashes instead, with no custom code.
- **Fee model**: unchanged. Nothing is executed on anyone's behalf, so base-fee sharing is not affected.

## 11. Open questions

1. **Fork scheduling**: `ETNA_FORK_TIME` is not set. The `Anchor`, L2 `SignalService`, scheduled extended runtime, clients and guests must agree on it before the DAO proposal (sections 7 and 8). The Unzen Inbox's propose cutoff and the EtnaInbox's `ETNA_FORK_TIME` derive from the same value ([SWITCH.md](SWITCH.md#3-the-dao-proposal)).
2. **Consumers of the anchor transaction**: whether anything else relies on the `Anchored` event or on transaction 0 being the anchor, such as explorers, indexers and tests. The known consumers of `CheckpointSaved` and `Anchor.getBlockState()` are in section 9.
