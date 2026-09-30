# Current Taiko protocol: an engineer's guide

Initial source baseline: `961bbd8ff55a0f66f44ad04160eb51638d655b66`, inspected 2026-09-30. Remote freshness could not be authenticated during the initial Phase 1 read because GitHub access failed; the later successful refresh is recorded immediately below. This is a source-level account, not a deployed-state audit. Original body citations remain pinned to the initial baseline; source defaults are not asserted to be live chain values.

## 2026-09-30 addendum: refreshed main

**Proven source update:** the subsequent public fetch supplied main `31df8fe8ef7c027840abf122ec36f87c41c3ce94`, two commits beyond the initial baseline. The relevant commit is [6d1d62741464efe736179e3b35f133d5844469ca](https://github.com/taikoxyz/taiko-mono/commit/6d1d62741464efe736179e3b35f133d5844469ca) (Proposal0026). Current [MainnetInbox.sol:45–46](https://github.com/taikoxyz/taiko-mono/blob/31df8fe8ef7c027840abf122ec36f87c41c3ce94/packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol#L45) and [DevnetInbox.sol:43](https://github.com/taikoxyz/taiko-mono/blob/31df8fe8ef7c027840abf122ec36f87c41c3ce94/packages/protocol/contracts/layer1/devnet/DevnetInbox.sol#L43) configure **100% of the L2 basefee to the block coinbase**, replacing 75%. The 75% entry in Section 4 is retained as an explicitly historical initial-snapshot observation, not the refreshed default. Already proposed legacy inputs retain their committed percentage; native fees remain ETH and bond denomination is unchanged.

**Proven scope:** this interval changes no core Inbox, shared SignalService/Bridge/Vault/fork-router, L2 Anchor/layout or Go/Rust client runtime source. Its only Go delta updates treasury-income test expectations. It adds v0.9.0 RISC0/SP1/SGX constants, a recorded ZK-required verifier address, and Proposal0026 deployment/proposal/test artifacts. **Open:** these source constants and repository deployment statements do not authenticate live implementations, enabled keys, SGX registrations or execution of the proposal. They are not preapproved Etna verifier keys.

The [main-refresh evidence note](notes/main-refresh.md) lists exact commits, paths and line citations, the 21-action verifier rotation, checks performed and consequences for fee rules and historical migration. All sections below preserve the initial snapshot unless this addendum explicitly updates them.


**Classification:** factual descriptions below are **proven by the cited source**; cryptography, Ethereum consensus and honest operation are **assumptions**; unavailable deployment/circuit facts are **open**. Full subsystem evidence is in [L1](notes/l1.md), [L2/shared](notes/l2-shared.md), [Go](notes/go-client.md), [Rust](notes/rust-client.md) and [docs](notes/docs.md). Read this summary first and those notes when modifying a subsystem.

## 1. The system in one pass

Taiko's L2 execution is Ethereum-like, but canonical input order comes from L1 proposal transactions. A preconfer first builds and distributes **unsafe** blocks off-chain. Later the L1 Inbox records blob-backed proposal metadata. Nodes derive L2 blocks deterministically from that metadata and the blob bytes, replacing an incompatible unsafe tail. A later proof transaction validates a contiguous range of proposals and publishes the final block's state root to the existing SignalService. Bridge message verification consumes that root.

There are three different units: an **L2 block**, a **proposal** containing one or more derivation sources and potentially many blocks, and a **proof commitment** covering one or more contiguous proposals. They are not interchangeable. Current structs: `packages/protocol/contracts/layer1/core/iface/IInbox.sol:51–79,111–144`; proposal/proof entry points: `packages/protocol/contracts/layer1/core/impl/Inbox.sol:270–289,321–399`.

```text
user transactions → preconfer → P2P execution payloads → unsafe L2 head
                               ↓ later
                     L1 propose(data blobs + metadata)
                               ↓
                      deterministic derivation → L1-confirmed L2 input
                               ↓ later
                      L1 prove(commitment, proof)
                               ↓
                      SignalService checkpoint → Bridge → Vault/recipient
```

The current core does not implement the old contestable-proof tier escalation described in historic docs. A successful proof call updates the contract's finalized head atomically; there is no additional contest window in this path. Ethereum consensus finality remains a separate condition on the L1 block containing that call. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:364–399`; `packages/protocol/contracts/layer1/verifiers/IProofVerifier.sol:7–24`.

## 2. L1 Inbox and derivation

### Proposal admission

`propose(bytes _lookahead, bytes _data)` decodes a deadline, a current-transaction blob reference and requested forced-inclusion count. It permits at most one proposal per L1 block and reserves ring-buffer capacity so unfinalized metadata cannot be overwritten. Forced sources come first; the proposer's ordinary source comes last. It unconditionally invokes the proposer checker, then checks a configured minimum bond if nonzero. The proposal commits the previous L1 block hash as origin, a parent proposal hash and fee-sharing policy. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:270–289,577–628,637–673,764–765`.

Admission certifies neither execution nor timely P2P broadcast. The L1 contract sees blob commitments and proposer authorization, not gossip receipts. Blob references require nonzero hashes from `blobhash` in the current transaction. There is no calldata DA mode in this current interface. `packages/protocol/contracts/layer1/core/libs/LibBlobs.sol:34–54`; `packages/protocol/contracts/layer1/core/iface/IInbox.sol:99–109`.

### Derive exactly the same blocks

The Shasta derivation document specifies proposal-level, source-level and block-level metadata. Nodes reconstruct versioned blob slices, decompress and decode source manifests, then validate each source independently. Invalid source formatting yields a default anchor-only source rather than poisoning other forced sources. Source limits change at Unzen from 192 to 768 blocks; forced sources must describe one block. `packages/protocol/docs/Derivation.md:12–55,146–196`.

Block metadata includes timestamp, coinbase, gas limit, transactions and L1 anchor checkpoint. The L1 proposal origin bounds which L1 facts may be imported. Any field that depends on a future landing event is an obstacle to precomputing an immutable propose-with-proof statement; Etna must explicitly replace such dependencies rather than assume that today's preconf payload can be proved before all its derivation inputs exist. This is a deduction from proposal timestamps/origin at `packages/protocol/contracts/layer1/core/impl/Inbox.sol:609–620` and the metadata rules in `packages/protocol/docs/Derivation.md:22–55,62–76`.

### Prove and publish a checkpoint

`prove(bytes _data, bytes _proof)` may overlap already finalized proposals but must advance the finalized head, leave no gap, and never prove an unproposed ID. Solidity checks continuity from the stored finalized block hash and checks the terminal proposal hash against the ring buffer. The proof program must bind the intermediate hash-linked proposals and execution. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:332–351,788–811`; `packages/protocol/contracts/layer1/core/libs/LibHashOptimized.sol:32–82`.

It then processes any applicable liveness penalty, saves the end checkpoint, updates the head, emits `Proved`, and invokes the configured verifier. Verifier failure reverts all preceding writes in that transaction. This ordering does not expose a persistent unverified checkpoint under Ethereum atomic execution. A fully stale competing proof still reverts. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:353–399`.

The proof commitment includes `actualProver`, so the payout identity is proof-bound; it need not equal the transaction sender. A design must not conflate proof author, relayer and fee payer. `packages/protocol/contracts/layer1/core/iface/IInbox.sol:121–144`; `packages/protocol/contracts/layer1/core/impl/Inbox.sol:729–742`.

## 3. Whitelists: what they actually guarantee

| Mechanism | Proven code guarantee | Assumption or missing guarantee |
|---|---|---|
| PreconfWhitelist | A curated proposer/sequencer mapping and deterministic selection of one active proposer at a given consistent state/time; delayed additions, immediate authorized ejection | Reliability and independence come from curation; no permissionless qualification, gossip availability guarantee or withholding slash |
| ProverWhitelist | With a nonempty configured list, only listed transaction senders can finalize proofs | No implemented age-based escape; membership does not establish proof soundness or reliable availability |
| Verifier policy | Proof wrappers check configured programs/verification keys and composition | Owner-chosen program policies and SGX trust remain separate administrative/security assumptions |

Preconfer additions/removals are privileged; selection uses a delayed beacon root with 12-second/32-slot arithmetic. `checkProposer` ignores its lookahead argument in the whitelist path and returns zero for the submission-window end because whitelist slashing is disabled. This is not CL validator-schedule lookahead, but it still violates Etna's slot independence. `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:94–140,203–265,275–313`; `packages/protocol/contracts/layer1/preconf/libs/LibPreconfConstants.sol:19–23`.

The current Inbox comment explicitly says permissionless proposing is temporarily disabled. A nonempty prover whitelist is enforced with no proposal-age argument. `permissionlessProvingDelay` and `permissionlessInclusionMultiplier` remain in configuration but do not implement their advertised escape paths. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:601–603,771–778`; `packages/protocol/contracts/layer1/core/iface/IInbox.sol:28–48`.

Etna must replace the useful coordination, Sybil cost, key registration, recovery and proof-admission functions of these controls. Merely deleting membership checks does not supply those properties. URC and its associated lookahead paths are **removed in Etna**; they are not candidate foundations.

## 4. Bonds, rewards, gas and forced inclusion

| Source parameter | Value / behavior | Meaning |
|---|---|---|
| Bond token | TAIKO in Unzen deployment script | ERC20 collateral, recorded in units of 10^9 token base units |
| Minimum / liveness bond | 0 / 0 in MainnetInbox source | Current source does not charge a positive liveness slash |
| Withdrawal delay | 604,800 seconds | Excess over minimum can leave earlier; requesting withdrawal disables proposal bond eligibility |
| Proving window / sequential grace | 14,400 / 180 seconds | Generic late-proof threshold uses the later applicable deadline |
| L2 basefee share | 75% to coinbase in metadata | Remaining share reaches Anchor; native execution gas remains ETH-denominated |
| Forced queue delay / base fee | 576 seconds / 10^15 wei ETH | Queue fee increases linearly with pending count; paid to consumer |
| Forced entries per proposal | At most 10 | FIFO due-prefix enforcement, subject to successful authorized proposal |
| Proposal ring | 21,600 entries | Source sizes this using 12-second L1 blocks; wall-clock coverage shrinks with faster L1 blocks |

Sources: `packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol:15–52`; `packages/protocol/script/layer1/mainnet/DeployUnzenContracts.s.sol:61–68`; `packages/protocol/contracts/layer1/core/libs/LibBonds.sol:33–105,126–140,143–204`; `packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol:42–94`; Anchor fee comment/withdrawal at `packages/protocol/contracts/layer2/core/Anchor.sol:140–155`. The source table does not authenticate live settings.

When the prover whitelist is effective, `prove` skips the generic bond settlement entirely. Otherwise late settlement best-effort debits the first newly finalized proposal's proposer, credits half to `actualProver`, and removes the remainder from the ledger. “Burn” here is not a token-contract burn operation. There is no escrow of a distinct full liability for every outstanding proposal. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:356–359,729–742`; `packages/protocol/contracts/layer1/core/libs/LibBonds.sol:143–204`.

Any user can enqueue one forced-inclusion blob with ETH payment once the protocol has its first ordinary proposal. The queue protects against an authorized proposer ignoring due entries **while proposing**; it does not bypass the proposer whitelist if all operators stop. Its data can outlive blob retention. The source includes an owner recovery hook that voids old queued entries after a repository-described incident; that is evidence of an administrative recovery path, not a permissionless solution. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:246–257,427–443,650–673`; `packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol:42–71`.

## 5. Proof composition

`ComposeVerifier` checks an ordered, nonduplicated list of verifier IDs, runs each sub-verifier on the same commitment, then enforces a policy. `ZkRequiredVerifier` requires exactly two proofs with at least one ZK leg: SGX+ZK or RISC0+SP1. `SgxAndZkVerifier` and `AnyVerifier` express other policies, so the presence of a contract in the tree does not prove it is active. `packages/protocol/contracts/layer1/verifiers/compose/ComposeVerifier.sol:13–25,59–101`; `packages/protocol/contracts/layer1/verifiers/compose/ZkRequiredVerifier.sol:31–50`; `packages/protocol/contracts/layer1/verifiers/compose/SgxAndZkVerifier.sol:25–35`; `packages/protocol/contracts/layer1/verifiers/compose/AnyVerifier.sol:25–35`.

Public-input domains bind chain/verifier/commitment and the relevant program identifiers. SP1/RISC0 wrappers maintain owner-controlled trusted keys/images; SGX additionally has attestation, trusted measurements and instance expiry/registration policy. **Assumed:** selected remote verifiers and programs are sound. **Open:** full proving-program audit and deployed verifier wiring. `packages/protocol/contracts/layer1/verifiers/LibPublicInput.sol:18–51`; `packages/protocol/contracts/layer1/verifiers/SP1Verifier.sol:32–83`; `packages/protocol/contracts/layer1/verifiers/Risc0Verifier.sol:31–80`; `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:221–319,459–479,591–603`.

Historical contestation and tiers remain useful design background, but are not today's Inbox state machine. The documentation note records the historical/current differences explicitly.

## 6. Anchor and the frozen shared contracts

The current first-transaction anchor method is `anchorV4(ICheckpointStore.Checkpoint)`, called by the protocol's golden-touch sender. It updates the parent-block history accumulator and publishes a fresher L1 checkpoint. Its Solidity body does not independently establish that the supplied root is an authentic L1 state root; derivation and proving must bind that fact. `packages/protocol/contracts/layer2/core/Anchor.sol:86–88,124–138,173–185,194–228`.

The exact shared checkpoint interface on **both** layers is:

```solidity
struct Checkpoint { uint48 blockNumber; bytes32 blockHash; bytes32 stateRoot; }
function saveCheckpoint(Checkpoint calldata _checkpoint) external;
function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory);
event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
```

`packages/protocol/contracts/shared/signal/ICheckpointStore.sol:12–43`. L1 Inbox publishes proven L2 end roots; L2 Anchor publishes authenticated L1 roots. SignalService has immutable authorized-syncer and remote-SignalService addresses. A new Inbox address requires corresponding implementation wiring at the **existing** L1 SignalService proxy; retaining an Anchor address can retain that layer's syncer identity. `packages/protocol/contracts/shared/signal/SignalService.sol:35–43,81–93,174–183`.

The current SignalService stores received-signal cache at slot 253 and checkpoints at 254, both version-namespaced. Historical reserved slots and inherited owner/router alignment are intentional. It accepts exactly one hop with account and storage proofs against a saved state root; the storage value is the signal itself, not the older documentation's `1`. `packages/protocol/contracts/shared/signal/SignalService_Layout.sol:10–24`; `packages/protocol/contracts/shared/signal/SignalService.sol:263–295`. Checkpoints are overwriteable by the authorized syncer; monotonic, unique root publication is thus an Inbox/Anchor security obligation, not enforced here.

Bridge authenticates a remote message through SignalService and maintains statuses to prevent repeat processing. Vaults preserve canonical-token mappings, lock canonical assets and release/mint representations according to authenticated bridge context. Exact storage and dispatch inventories are in [L2/shared notes](notes/l2-shared.md). Preserving proxy addresses alone is insufficient: message statuses, signal slots, mappings, immutable targets and old fork dispatch must remain correct.

Operational privileges extend beyond Inbox: owner/pauser controls exist in Bridge and SignalService, ERC20Vault has owner token remapping, resolver updates are owner-controlled, Anchor has owner fee withdrawal, and BridgedERC20 permits owner-or-Vault mint authorization. These must be considered under R1 while retaining R2 addresses. `packages/protocol/contracts/shared/signal/SignalService.sol:200–201`; `packages/protocol/contracts/shared/common/EssentialContract.sol:149–165,207–209`; `packages/protocol/contracts/shared/vault/ERC20Vault.sol:200–205`; `packages/protocol/contracts/shared/common/DefaultResolver.sol:37–49`; `packages/protocol/contracts/layer2/core/Anchor.sol:140–155`; `packages/protocol/contracts/shared/vault/BridgedERC20.sol:112–125,181`.

ForkRouter delegates into old/new implementations using shared proxy storage and reserves slots 0–150. It does not create isolated storage per fork. A migration must inspect selectors reachable through the old route, especially administrative and proof-processing selectors. `packages/protocol/contracts/shared/fork-router/ForkRouter.sol:11–20,40–66`.

## 7. What a preconfirmation means today

A preconfirmation is a signed off-chain execution-payload claim preceding L1 data publication. “Valid” has several predicates:

1. **Wire/authentication:** decode a bounded payload and verify its signature/domain.
2. **Authority:** the signing key belongs to an eligible sequencer under the node's L1 registry view; membership and unique current sequencing right are distinct checks.
3. **Continuity:** the parent exists, its state is known, and height/timestamp rules fit it.
4. **Execution:** reexecute transactions and compare every claimed execution result, including the block hash and state root.
5. **Anchor/derivation:** check the first anchor, authenticated L1 checkpoint, metadata bounds and fork rules.
6. **Canonicality:** determine whether L1 later admits the same data and the ZK proof confirms it. This cannot be known from a signature alone.

**Proven limitation:** a synced node with complete block/parent data can evaluate deterministic validity without waiting for batch landing; a node missing the parent cannot. Local execution also takes nonzero time. The truthful API therefore distinguishes invalid, valid-relative-to-view and not-yet-checkable. A transport ACK or whitelist signature must not be shown as irrevocable confirmation.

The Go server performs structural/anchor admission and delegates execution to the engine. It can cache/request missing-parent blocks and reorg its unsafe tail; P2P signature validation crosses into a pinned external Optimism dependency, so the repository-only review does not claim a full audit of that dependency. The Rust whitelist driver recovers signatures and checks the periodically polled operator set, then applies structural checks and execution. Whole-set membership is not the same as unique sequencing authorization. The detailed evidence tables in [Go notes](notes/go-client.md) and [Rust notes](notes/rust-client.md) identify checks at each boundary.

A specific Rust caution is visible in source: when the signed hash differs from the block the supplied payload produces, the importer drops the envelope after the produced block has advanced the unsafe head. That is a code observation, not a completed exploit claim. `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/importer/cache_import.rs:172–208`. Missing parents are deferred at `:154–169`; signature recovery is at `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/network/handler.rs:224–236`.

Current whitelist selection/handover still consumes slot/period conventions in both client families. Go proposer/prover paths separately submit L1 data and proofs; Rust proposer/driver implement proposal construction and derivation, with proving components outside the requested crate subset. Neither path turns a private preconf into an L1 proof by signature alone. URC-related lookahead code is **removed in Etna**.

| User-visible stage | What is established | What can still change |
|---|---|---|
| Payload received / admitted | Some structural and authentication checks | Missing execution, stale authority view, invalid anchor, private competing branch |
| Locally executed unsafe block | Valid execution relative to known parent and L1 view | L1 proposal order/data can replace unsafe tail |
| L1 data proposal | Ethereum ordered the proposal and its DA commitments | L1 reorg; execution proof not yet finalized |
| Successful L1 proof | Contract accepted execution commitment and published checkpoint | L1 reorg until Ethereum finality; proof-system/program assumptions |
| Ethereum-final proof block | Settlement relative to Ethereum finality | Catastrophic consensus failure or malicious future upgrade, outside ordinary operation |

## 8. Withholding and the design obligations it creates

An authorized operator can build privately and reveal its branch only in an L1 blob transaction. Current L1 admission does not require prior gossip evidence; no current whitelist withholding slash exists. A valid execution proof establishes execution, not dissemination time. A competing prover may waste work, and users may transact on stale public state. `packages/protocol/contracts/layer1/core/impl/Inbox.sol:577–623`; `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol:139–140`.

No contract can directly prove that bytes were not sent to a global P2P network. A permissionless successor must make **specific signed publication/response obligations** enforceable and state the synchrony/inclusion assumptions under which an honest party avoids timeout punishment. A withholding defense must also specify how late private branches interact with successor blocks and proof races. See [threat model](01-threat-model.md) for traces and falsification tests.

## 9. Boundaries and unresolved facts

- **Proven:** current source separates proposals from proofs, enforces operational whitelists, relies on slot-derived whitelist timing, and trusts proof-bound checkpoint publication.
- **Assumed:** Ethereum consensus/DA, verifier soundness, correct circuits and honest initial configuration. None is established merely by reading Solidity.
- **Open:** live addresses/implementations/configuration, external engine/P2P implementation audit, current main freshness, end-to-end proof performance and circuit-level equivalence. Phase 2 separately verifies L1 roadmap claims from public sources.

The required historic docs were read as background, not treated as current executable specification. `how_taiko_proves_blocks.md` describes an older anchor and data model, `contestable_validity_rollup.md` describes historical tier/contest behavior, `actors_privileges_deployments.md` describes older proxy/governance arrangements, and `multihop_bridging_deployment.md` describes an older multi-hop proof format. The code-path differences and exact document citations are preserved in [docs notes](notes/docs.md).
