# 00 — Baseline and lessons

> **Status:** Phase 0 deliverable, consolidating the two pinned research documents. **Baseline pin:** `7718753c1cece7d7705afaf33e6f9680115086dd` (branch `etna-pos-zk`, 2026-10-05). **Prior Etna pin:** `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`, 2026-10-05).
>
> **Consolidates:** [`research/taiko-baseline-contracts.md`](research/taiko-baseline-contracts.md) (Half A) and [`research/prior-etna-digest.md`](research/prior-etna-digest.md) (Half B). **Read alongside:** [`01-requirements-and-threat-model.md`](01-requirements-and-threat-model.md) for vocabulary and status labels, and [`04-architecture-decision.md`](04-architecture-decision.md) for the selected architecture.
>
> **No number here is a measurement.** Every value is tagged **sourced** (read from the cited pinned artifact), **derived** (arithmetic over sourced values, inputs shown), or **unmeasured** (proposed or placeholder; no procedure has run). A repo constant is *sourced*, not measured. Prior-Etna values that its own documents label unmeasured are marked where quoted.

## 1. What a reader should take from this

- **Today's Inbox is a two-transaction accept path, and that is the hardest constraint on the redesign.** `propose()` carries data only (`Inbox.sol:270`) and `prove()` carries the proof (`Inbox.sol:321`); no code path accepts both, so D5 cannot be satisfied by configuration.
- **The proof public input is `Commitment`, hashed with no domain separator.** `hashCommitment` reproduces `keccak256(abi.encode(commitment))` word for word (`LibHashOptimized.sol:32-84`); domain separation begins only at the verifier layer (`LibPublicInput.sol:18-36`).
- **The economics are off and there is no contest.** Mainnet ships `minBond: 0` and `livenessBond: 0` (`MainnetInbox.sol:37-38`); bond settlement is skipped whenever the prover whitelist is on (`Inbox.sol:356-359`); and `challenge/contest/dispute` has zero matches under `layer1/core`.
- **Both proposing and proving are permissioned.** An epoch-rotating `PreconfWhitelist` operator gates `propose`; `ProverWhitelist` gates `prove`; the in-repo comment reads `// Permissionless proposing is temporarily disabled.` (`Inbox.sol:601-603`).
- **Forced inclusion exists, and the owner can void it unilaterally.** `init3()` moves the queue head to the tail, discarding every queued entry with fees unrefunded (`Inbox.sol:246-258`); its NatSpec names the June 2026 incident and expired blob references. The incident record itself was **not** read: **UNVERIFIED**.
- **Storage layout, not code, decides what an upgrade may do.** Slots 0–250 are reserved; Inbox's first free slot is 258 and only 43 gap slots remain (`MainnetInbox_Layout.sol:21-26`). Every new variable consumes gap, and deprecated slots are frozen rather than free.
- **L2 state has exactly one checkpoint writer per chain, and it is immutable.** `SignalService._authorizedSyncer` has no setter (`SignalService.sol:37,86-90,174-177`); the Anchor's only checkpoint path is hard-gated to `GOLDEN_TOUCH_ADDRESS` (`Anchor.sol:36-37,86-89,124-127`). Anchor-less L2 execution is a new code path, not a toggle.
- **The privileged levers R1/R2 must remove are enumerable.** Owner `activate/init2/init3`, `IProposerChecker`, `ProverWhitelist`, the single writer and golden touch, verifier allowlists, pause, and the resolver — [§3.9](#39-every-privileged-lever) lists each with its exercising function.
- **There are no proof "tiers" at this commit.** Across `packages/protocol/contracts` the string `tier` has zero matches; the role is filled by `ComposeVerifier.VerifierType`, and the active mainnet policy is `ZkRequiredVerifier`'s exact-two rule with at least one ZK leaf (`ZkRequiredVerifier.sol:31-51`).
- **The prior Etna programme delivered a document-only design whose own readiness bar was never met.** Its D44 item 5 stood at 0 of 2 at the accepted head (D97, D100); no machine-checked model exists (L34), and no measurement procedure ever ran (D69).
- **Its most valuable output is its failure traces, not its mechanisms.** A height-only lock rule produced a High and required the W22 repair; recovery prototypes stayed unclosed; an L1-reference field carrying two meanings produced a High; an L1-read age clock produced a High (C5C7-FT-01) and the D99 fix.
- **The new design answers those lessons with published rules where they exist and OPEN where they do not.** CometBFT lock/PoLC [CONS-04], epoch-scoped certificates [CONS-08], the unique-finalized-prefix invariant [INV-01], one atomic accept path [L1-01], and a safe halt [HALT-01] are linked per trace in [§5](#5-known-failure-traces-and-what-they-teach); every unclosed item is marked **OPEN**.

## 2. Pin record

### 2.1 Revisions and dates

| Artifact | Revision / value | Date | How read |
|---|---|---|---|
| Taiko monorepo baseline | `7718753c1cece7d7705afaf33e6f9680115086dd`, branch `etna-pos-zk` | commit 2026-10-05 01:41:56 +0000; read 2026-10-05 (Asia/Singapore) | primary research doc, plus spot checks against this working tree |
| Prior Etna design | `a829f79723de9a09205660d9895418577cfe9aa9`, branch `etna/converged-spec` | authored 2026-10-05 05:51:27 +0000; read 2026-10-05 | **only through the digest**; the revision itself was not checked out |
| HEAD re-check | `git rev-parse HEAD` returned `7718753c1cece7d7705afaf33e6f9680115086dd` | 2026-10-05 | verified in-session |

### 2.2 Files read in full for this consolidation

| File | Lines |
|---|---|
| [`research/taiko-baseline-contracts.md`](research/taiko-baseline-contracts.md) | 800 |
| [`research/prior-etna-digest.md`](research/prior-etna-digest.md) | 242 |
| [`README.md`](README.md) | 80 |
| [`01-requirements-and-threat-model.md`](01-requirements-and-threat-model.md) | 302 |
| [`04-architecture-decision.md`](04-architecture-decision.md) | 236 |
| [`spec/index.html`](spec/index.html) — rule index and the GEN/STATUS rule blocks | 431 total; index consulted |

### 2.3 Contracts spot-verified in-session against the working tree at `7718753c1`

`Inbox.sol:145` (`__gap`), `:246-258` (`init3`), `:270` (`propose`), `:321` (`prove`), `:337` / `:356-359` / `:771-779` (whitelist gate and bond switch), `:601-603` (disabled permissionless proposing); `MainnetInbox.sol:17-18,37-38,40`; `MainnetInbox_Layout.sol:10-26`; `SignalService.sol:37,86-90,174-177`; `Anchor.sol:36-37,86-89,124-127`; `PreconfWhitelist.sol:127-141`; `ProverWhitelist.sol:28,74-104`; `ZkRequiredVerifier.sol:31-51`; `ComposeVerifier.sol:13-21,107`; `MainnetVerifier.sol:8-14`; `LibL1Addrs.sol:37-48,56-62`; `LibHashOptimized.sol:24-84`; `IInbox.sol:60-138`; `BondManager_Layout.sol:21-23`.

Also verified in-session: `tier` has 0 matches across `packages/protocol/contracts`; `challenge|contest|dispute` has 0 matches under `contracts/layer1/core`; `**/BondManager*.sol` matches only the generated layout file.

Where a verified range differs from the baseline's recorded range (for example the baseline cites `ZkRequiredVerifier.sol:37-51`; the function opens at `:31`), both are preserved here and the difference is noted rather than silently renumbered.

### 2.4 What was NOT read or verified

| # | Not verified | Consequence |
|---|---|---|
| 1 | The prior-Etna primary artifacts (`P/spec/*.html`, `P/DECISIONS.md`, `P/WORK.md`, `P/iterations/*`, its research notes) | §4 and §5 restate the digest; any claim used normatively must be re-checked at `a829f797…` first. |
| 2 | The prior Etna revision was not checked out | No line-level citation to it appears here; citations point to the digest and to the primary docs it quotes. |
| 3 | The June 2026 incident | Cause, scope and governance record are **UNVERIFIED**; only the in-repo `init3` NatSpec (`Inbox.sol:246-252`) and a deployment-log bundle note were read. |
| 4 | Live mainnet wiring | Whether `Inbox._proofVerifier` currently points at `ZkRequiredVerifier` needs `getConfig().proofVerifier` on-chain or the upgrade bundle; `LibL1Addrs` and the log agree only on the constant. **UNVERIFIED.** |
| 5 | Addresses | As recorded in repo constants and hand-maintained `deployments/*.md`; no `eth_call` or explorer verification was performed. |
| 6 | Off-chain stack | All of `packages/taiko-client*`, the relayer and the indexer are out of scope and were not read. |
| 7 | Spec pages referenced by the rule index but absent from `spec/` when this was written | `04-l1-integration.html`, `07-economics.html`, `08-migration-upgrades.html` are referenced by the index; rule links here resolve to `spec/index.html#ruleindex`, which exists. |
| 8 | Baseline's own gap list | `MainnetDAOController.sol`, `LibTrieProof.sol`, `BaseNFTVault.sol` (full), `TaikoTokenBase.sol`, the `SharedResolver` implementation, most deploy/bundle scripts and `LibPackUnpack` internals are carried forward as unread. |

`UNVERIFIED` markers from the sources are preserved wherever they appear; a claim is never upgraded by copying.

### 2.5 Number tags used here

**sourced** — read from the cited pinned artifact (commit and date given). **derived** — arithmetic over sourced values, with its inputs shown. **unmeasured** — proposed or placeholder; no procedure has run. A repo constant is *sourced*, not a measurement. D1's 2 s cadence is a fixed design decision and is not a measurement (30 min = 900 L2 blocks, **derived**: 30 × 60 / 2).

## 3. Taiko as it exists today at `7718753c1`

First mentions link to source: `Inbox.sol` = [`contracts/layer1/core/impl/Inbox.sol`](../../../contracts/layer1/core/impl/Inbox.sol); `IInbox.sol` = [`contracts/layer1/core/iface/IInbox.sol`](../../../contracts/layer1/core/iface/IInbox.sol); `MainnetInbox.sol` = [`contracts/layer1/mainnet/MainnetInbox.sol`](../../../contracts/layer1/mainnet/MainnetInbox.sol); `SignalService.sol` = [`contracts/shared/signal/SignalService.sol`](../../../contracts/shared/signal/SignalService.sol); `Anchor.sol` = [`contracts/layer2/core/Anchor.sol`](../../../contracts/layer2/core/Anchor.sol). Citations are repo-root-relative; ranges are as recorded in the pinned baseline unless marked "verified in-session".

### 3.1 The accept path: one transaction proposes, another proves

`propose(bytes _lookahead, bytes _data)` is external `nonReentrant` (`Inbox.sol:270`). Its decoded `ProposeInput` has exactly three fields — `deadline`, a `BlobReference`, and `numForcedInclusions` (`IInbox.sol:100-109`): **no proof, no state root, no block hash, no transition array**. `prove(bytes _data, bytes _proof)` is a separate external `nonReentrant` function carrying the proof (`Inbox.sol:321`). There is no code path that accepts both in one call, and the baseline's verdict for D5 is explicit: **yes, data and proof are split today, and that is the only supported flow**.

What `propose` actually commits to is a blob slice frozen into the proposal hash: `LibBlobs.validateBlobReference` binds this transaction's `blobhash` values (`LibBlobs.sol:44-48`, called at `Inbox.sol:598-599`). There is no `lastProposalHash` storage variable; the parent link lives inside the hashed `Proposal` struct (`IInbox.sol:70`, set at `Inbox.sol:616`) and the proof-side link is `commitment.lastProposalHash` checked against `getProposalHash(lastProposalId)` (`Inbox.sol:348-351`).

`prove()` validates the commitment range (`Inbox.sol:333-334`, body `:788-812`), computes `proposalAge` (`:336`), checks parent-block continuity (`:342-346`) and last-proposal-hash continuity (`:348-351`), settles the liveness bond only when the whitelist is off (`:356-359`), **writes the L2 checkpoint** (`:364-370`), finalizes core state and emits `Proved` **before** proof verification (`:376-387`), and calls the verifier last (`:389-398`). One transaction means a reverting verifier unwinds the checkpoint and the core state; the ordering is still structurally "optimistic write, then verify", a property a same-transaction redesign must preserve.

### 3.2 The `Commitment` public input and its hashing

`Transition` is `{address proposer; uint48 timestamp; bytes32 blockHash;}` (`IInbox.sol:112-119`). `Commitment` is, in order: `firstProposalId` (uint48), `firstProposalParentBlockHash` (bytes32), `lastProposalHash` (bytes32), `actualProver` (address), `endBlockNumber` (uint48), `endStateRoot` (bytes32), `transitions` (`Transition[]`) — `IInbox.sol:122-138`.

- `hashProposal` is `keccak256(abi.encode(_proposal))` with no domain separator (`LibHashOptimized.sol:24-27`).
- `hashCommitment` is a hand-built, `abi.encode`-equivalent word layout documented at `LibHashOptimized.sol:37-51` and implemented with `EfficientHashLib.malloc(9 + len*3)` (`:52-54`) and `EfficientHashLib.hash(buffer)` (`:80`). The bytes are **byte-identical to** `keccak256(abi.encode(commitment))`; there is no domain separator.
- Wire encoding: `ProposeInput` is a fixed 15 bytes (`LibCodec.sol:17-29`); `ProveInput` is a fixed 130 bytes plus 58 per transition (`LibCodec.sol:50-73,105-121`; `LibTransitionCodec.TRANSITION_SIZE = 58`, `LibTransitionCodec.sol:11`).
- Domain separation exists only at the verifier public input: `EfficientHashLib.hash(bytes32("VERIFY_PROOF"), chainId, verifierContract, aggregatedProvingHash, proofSigner)` (`LibPublicInput.sol:18-36`), with ZK aggregation layered at `:43-52` and a Risc0 `sha256` wrapper at `Risc0Verifier.sol:74`.

### 3.3 Bonds switched off, and no challenge mechanism

Mainnet's live configuration is `minBond: 0` with the comment `// During prover whitelist, bonds are not necessary`, and `livenessBond: 0` (`MainnetInbox.sol:37-38`). The bond machinery still exists but is inert: balances are gwei-denominated `uint64` converted at the ERC20 boundary (`LibBonds.sol:18,202-205`); `Bond` is `{uint64 balance; uint48 withdrawalRequestedAt;}` (`IBondManager.sol:13-19`); the liveness settlement debits best-effort and credits **half** to the actual prover, the other half leaving the ledger with no burn call (`LibBonds.sol:143-170`, `payeeAmount = debited / 2` at `:161-162`); and the whole path is skipped when the whitelist is enabled (`Inbox.sol:356-359`).

**There is no challenge, contestation or dispute game.** A grep for `challenge|contest|dispute` across `contracts/layer1/core` returns zero matches (verified in-session). `IProofVerifier.sol:15` mentions "prover-killer proposals" only as a comment about what `_proposalAge` *could* do; both SP1 and Risc0 implementations discard it (`SP1Verifier.sol:51`, `Risc0Verifier.sol:50`). The only sanction is the liveness bond, and it is switched off.

### 3.4 Who may propose and who may prove

- **Proposing** goes through the non-view `IProposerChecker.checkProposer` (`IProposerChecker.sol:16-21`). Mainnet's checker is `PreconfWhitelist`, which selects exactly one operator per epoch from the EIP-4788 beacon block root and rejects everyone else (`PreconfWhitelist.sol:136-140`; beacon root constant `LibPreconfConstants.sol:11-12`). Slashing is not enabled for whitelisted preconfers, so it returns `endOfSubmissionWindowTimestamp_ = 0`.
- **Proving** is gated by `ProverWhitelist` through `_checkProver` (`Inbox.sol:771-779`), called once per `prove()` (`:337`); its boolean return doubles as the switch that disables bond settlement. The whitelist is a `mapping(address => bool)` plus `proverCount` and a `uint256[48]` gap (`ProverWhitelist.sol:24-30`); mainnet's instance is `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` (`LibL1Addrs.sol:39`).
- The call site carries the baseline's key textual evidence: `// Permissionless proposing is temporarily disabled.` immediately above `_proposerChecker.checkProposer` (`Inbox.sol:601-603`, verified in-session).
- The Inbox itself is **not pause-gated**: no function in `Inbox.sol` carries `whenNotPaused` and there is no `_authorizePause` override, while Bridge, vaults and SignalService are pausable. That asymmetry matters to any redesign that keeps the retained surfaces.

### 3.5 Forced inclusion, the June 2026 incident, and `init3()`

Enqueue: `saveForcedInclusion` is payable and accepts exactly one blob (`Inbox.sol:431-443`; `LibForcedInclusion.sol:52`), prices the fee as `baseFee * (threshold + numPending) / threshold` (`:89-93`) and appends FIFO at `$.queue[$.tail++]` (`:64`). Dequeue: an entry is due when `block.timestamp >= inclusion.blobSlice.timestamp + _forcedInclusionDelay` (`Inbox.sol:656`), the proposer must request at least `dueToProcess` (`:662-664`), capped at `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` (`:667`); accumulated fees are forwarded to the proposer (`:710`).

The recovery hatch is owner-only and destructive:

```solidity
// Inbox.sol:246-253 — verbatim
/// @notice One-time owner function that voids all queued forced inclusions by moving the
///         queue head to the tail.
/// @dev Invoke via `upgradeToAndCall` on the proxy. The skipped entries were queued while
///      forced inclusions were disabled after the June 2026 incident; their blobs have
///      expired from the blob retention window and can no longer be derived, so they must
///      be evicted before forced inclusion processing is re-enabled. Their fees remain in
///      the contract.
function init3() external onlyOwner reinitializer(3) {
```

The body sets `$.head = tail` and emits `ForcedInclusionsVoided(head, tail)` (`Inbox.sol:254-257`). **The incident's cause is UNVERIFIED here**; what the repo records is that entries queued while forced inclusions were disabled outlived their blob retention window, and that fees are not refunded. The deployment log records that the Inbox was upgraded to the Unzen implementation by Proposal0019 and `init3()` was called in the same bundle (`mainnet-contract-logs-L1.md:222-223`).

### 3.6 Storage-layout constraints

Every retained contract is a UUPS proxy: the implementation's slot assignment **is** the proxy's storage. The generated layout files record it; the operational rule is `pnpm layout` before and after every change.

| Contract | Own storage starts | Last used slot | Gap after (slots) | Layout file |
|---|---|---|---|---|
| Inbox / MainnetInbox | 251 | 257 (`_bondStorage`) | 43 (258–300) | `MainnetInbox_Layout.sol:21-26` |
| SignalService | 251 | 254 (`_checkpoints`) | 46 (255–300) | `SignalService_Layout.sol:21-24` |
| Bridge | 251 | 256 (`__reserved3`) | 44 (257–300) | `Bridge_Layout.sol:21-27` |
| ERC20Vault | 301 | 304 (`lastMigrationStart`) | 46 (305–350) | `ERC20Vault_Layout.sol:21-26` |
| ERC721Vault | 301 | 302 | 48 + 50 | `ERC721Vault_Layout.sol:21-25` |
| ERC1155Vault | 301 | 302 | 48 + three 50s | `ERC1155Vault_Layout.sol:21-27` |
| Anchor | 251 | 256 (`_blockState`) | 43 (258–300) | `Anchor_Layout.sol:21-25` |
| ProverWhitelist | 251 | 252 (`proverCount`) | 48 (253–300) | `ProverWhitelist_Layout.sol:21-23` |
| PreconfWhitelist | 251 | 254 (`ejecters`) | 45 (255–299) | `PreconfWhitelist_Layout.sol:21-29` |
| BondManager (layout doc only) | 251 | 252 (`processedSignals`) | 44 (253–296) | `BondManager_Layout.sol:21-23` |

The rules an upgrade must respect:

1. **Never reorder, retype, resize or delete an existing slot.** New state may only be appended after the concrete contract's last used slot, consuming the trailing gap. The first new Inbox variable lands at **slot 258**; the first new SignalService variable at **slot 255**.
2. **Deprecated slots are frozen, not free** — `Anchor._pacayaSlots`, `Anchor._lastProposalId`, `SignalService._slotsUsedByPacaya`, `Bridge.__reserved1/__ctx/__reserved2/__reserved3`, `PreconfWhitelist._deprecated*`, `EssentialContract.__reentry`.
3. **The 151-slot prefix (0–150) is the ForkRouter's footprint** and must stay identical for anything routed through one (`ForkRouter.sol:18-20`). Slots 0–250 are reserved in total.
4. **Gap arithmetic is exact**: taking *n* slots from a `uint256[43]` gap leaves `uint256[43-n]`.

### 3.7 Addresses preserved by D3

D3 preserves the existing L1+L2 **SignalService, Bridge and the three Vaults** by in-place upgrade. Recorded addresses (repo constants and hand-maintained logs; **not chain-verified**):

| Contract | L1 mainnet proxy | L2 Taiko mainnet proxy | Source |
|---|---|---|---|
| SignalService | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0x1670000000000000000000000000000000000005` | `LibL1Addrs.sol:45`; `LibL2Addrs.sol:14` |
| Bridge | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | `0x1670000000000000000000000000000000000001` | `LibL1Addrs.sol:43`; `LibL2Addrs.sol:11` |
| ERC20Vault | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | `0x1670000000000000000000000000000000000002` | `LibL1Addrs.sol:46`; `LibL2Addrs.sol:15` |
| ERC721Vault | `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa` | `0x1670000000000000000000000000000000000003` | `LibL1Addrs.sol:47`; `LibL2Addrs.sol:16` |
| ERC1155Vault | `0xaf145913EA4a56BE22E120ED9C24589659881702` | `0x1670000000000000000000000000000000000004` | `LibL1Addrs.sol:48`; `LibL2Addrs.sol:17` |

The recorded owners are `controller.taiko.eth` for TaikoToken/SignalService/Bridge/Inbox/PreconfWhitelist (`mainnet-contract-logs-L1.md:15,31,50,336`) and `admin.taiko.eth` = `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` for QuotaManager (`LibL1Addrs.sol:67`). The Inbox, Anchor, TaikoToken, whitelists and resolver are also UUPS proxies, but they are **not** in D3's preserved list.

### 3.8 One checkpoint writer, one golden touch

`SignalService` sets a single immutable writer at construction with no setter and no rotation path — "the inbox on L1 and the anchor on L2" (`SignalService.sol:35-37,86-90`); `saveCheckpoint` reverts unless `msg.sender == _authorizedSyncer` and both checkpoint fields are non-zero (`:174-177`). On L1 that writer is the Shasta Inbox (deploy scripts); on L2 it is the Anchor proxy (deploy script `DeployShastaL2Contracts.s.sol:46-53`).

The Anchor's only state-changing path to the checkpoint store is `anchorV4`, under `onlyValidSender`: `require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender())` with the hardcoded constant `0x0000777735367b36bC9B61C50022d9D0700dB4Ec` (`Anchor.sol:36-37,86-89,124-127`, verified in-session); the only other external function, `withdraw`, is owner-only and never touches the store (`:145-156`). Every L2 cross-chain read resolves through `SignalService._getCheckpoint`, which only such a write can satisfy (`SignalService.sol:284-296`; `Bridge.sol:637-645`). **Anchor-less L2 execution is therefore a new code path, not a configuration toggle.**

### 3.9 Every privileged lever

| Lever | Holder | Exercising function |
|---|---|---|
| Void the forced-inclusion queue | Inbox owner | `init3()` — `Inbox.sol:253-258` |
| Incident state recovery / activation | Inbox owner | `init2` (`:217`), `activate` (`:188`) |
| Gate proposing | `IProposerChecker` (mainnet `PreconfWhitelist`) | `checkProposer` — `PreconfWhitelist.sol:127-141`, called at `Inbox.sol:603` |
| Gate proving | `ProverWhitelist` owner or immutable `_proverManager` | `whitelistProver` — `ProverWhitelist.sol:74-80`; gate `Inbox.sol:337,771-779` |
| Write L2 checkpoints on L1 | Inbox (immutable syncer) | `SignalService.saveCheckpoint` — `SignalService.sol:174-177` |
| Write L2 checkpoints on L2 | `GOLDEN_TOUCH_ADDRESS` (hardcoded) | `Anchor.anchorV4` — `Anchor.sol:124-127` |
| Verifier allowlists | Verifier owners | `setProgramTrusted`, `setImageIdTrusted`, `setMrEnclave`, `setMrSigner`, `setEnclaveAttributePolicy`, `addInstances`, `deleteInstances`, `toggleLocalReportCheck`, `registerInstance` |
| Pause | Bridge / vault / SignalService owners and pausers | `pause/unpause`; Bridge `pauser` monopoly on `receive()` (`Bridge.sol:186-188`) |
| Resolve peer addresses | SharedResolver owner | `resolve()` consumed by `Bridge.isDestChainEnabled` (`Bridge.sol:517-524`) and `BaseVault` (`BaseVault.sol:60,69`) |
| Upgrade | every `EssentialContract` owner | `upgradeTo/upgradeToAndCall` (`EssentialContract.sol:207`) |

The baseline's seven-item list of levers "an R1/R2 design would have to remove or neutralize" is exactly rows 1–7 above. Note that `Inbox.propose` and `Inbox.prove` are not pause-gated today.

### 3.10 Verifier policy: `ZkRequiredVerifier`, no tiers

`IProofVerifier.verifyProof(uint256 _proposalAge, bytes32 _commitmentHash, bytes calldata _proof)` is `external view` and must **revert** on an invalid proof (`IProofVerifier.sol:9,18-24`); every implementation in the tree is `external view`. There is **no proof-tier system**: `tier` has zero matches across `packages/protocol/contracts` (verified in-session). The role "tier" played is filled by `ComposeVerifier.VerifierType` (`ComposeVerifier.sol:13-21`: `NONE, SGX_GETH, TDX_GETH, OP, SGX_RETH, RISC0_RETH, SP1_RETH`), and the only numeric threshold is the required **count** of sub-proofs inside each composition. `ZkRequiredVerifier` (the active mainnet policy per `LibL1Addrs.ZK_REQUIRED_VERIFIER = 0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec`, `LibL1Addrs.sol:56`) requires exactly two: (SGX_GETH or SGX_RETH) plus (RISC0_RETH or SP1_RETH), **or** RISC0_RETH + SP1_RETH; SGX_GETH + SGX_RETH does not satisfy (`ZkRequiredVerifier.sol:31-51`).

`MainnetVerifier` is explicitly deprecated after the Unzen upgrade (Proposal0019) because it "still accepts the SGX-GETH + SGX-RETH (zero ZK) combination that finalized the June 2026 forged proofs. Do not wire into new deployments." (`MainnetVerifier.sol:8-14`). Whether the live Inbox's immutable `_proofVerifier` currently points at `ZkRequiredVerifier` is **UNVERIFIED** from the repo.

### 3.11 The orphan `BondManager` layout document

`layer2/core/BondManager_Layout.sol` exists — auto-generated, showing `processedSignals` at slot 252 and a `uint256[44]` gap at slot 253 (`:21-23`) — but there is **no `BondManager.sol` anywhere in the tree** (verified in-session: the `**/BondManager*.sol` glob matches only the layout file) and no deployment entry on any chain. `IBondManager` is implemented on L1 **by the Inbox itself** (`Inbox.sol:36`, functions `:403-425`). The baseline's gap 2 records that `git log --all` would be needed to learn whether the L2 contract ever existed. The layout file must not be read as evidence that the contract exists today.

### 3.12 The complete accepted state

After a successful `prove()` the accepted state is only: (1) `_proposalHashes[proposalId % _ringBufferSize] = keccak256(abi.encode(Proposal))`, written at `propose` time and **overwritten on wrap-around** (`Inbox.sol:136,286,559-561,626`); (2) `CoreState`, whose five `uint48` fields pack one slot alongside `lastFinalizedBlockHash` (`IInbox.sol:82-97`; `Inbox.sol:131`); (3) the `SignalService` checkpoint `{blockHash, stateRoot}` keyed by `blockNumber = commitment.endBlockNumber` (`SignalService.sol:70-73,179-181`; written from `Inbox.sol:364-370`). **There is no per-transition persistence** — the only proof-side records are `CoreState.lastFinalizedBlockHash` and the checkpoint.

### 3.13 Baseline extraction gaps carried forward

The pinned baseline lists ten gaps. They are reproduced here because a redesign that quietly assumes one of them away would be building on sand.

| # | Gap | Status |
|---|---|---|
| 1 | Prover "tiers" | Do not exist at this commit: `tier` has zero matches across `packages/protocol/contracts`; the nearest object is `ComposeVerifier.VerifierType`. |
| 2 | `BondManager` implementation | Absent; only the generated L2 layout document survives. `IBondManager` is the Inbox on L1. |
| 3 | Fork-router deployments | No concrete `ForkRouter` subclass or `shouldRouteToOldFork` override exists in `contracts/`, `script/` or `test/`, yet fork-router layouts exist. **UNRESOLVED.** |
| 4 | URC wiring | `eth-fabric/urc` is pinned as a dependency but imported by no Solidity file. |
| 5 | Hoodi L1 address library | No `LibL1HoodiAddrs`; Hoodi L1 addresses exist only in the deployment log. |
| 6 | Unread set | `MainnetDAOController.sol`, `LibTrieProof.sol`, `BaseNFTVault.sol` (full), `TaikoTokenBase.sol`, the `SharedResolver` implementation, most deploy/bundle scripts, all of `packages/taiko-client*`. |
| 7 | `LibPackUnpack` | Read only through call sites; exact little-endian packing not inspected. |
| 8 | Addresses | As-recorded, not chain-verified. |
| 9 | Live verifier wiring | Which verifier the Inbox immutable actually points at is not repo-determinable. **UNVERIFIED.** |
| 10 | Per-transition persistence | Confirmed absent; any such record is new state that must be carved out of the gaps in [§3.6](#36-storage-layout-constraints). |

## 4. Prior Etna research at `a829f79723de9a09205660d9895418577cfe9aa9`

**Nature of the artifact:** accepted-but-unimplemented, document-only design on branch `etna/converged-spec`, dated 2026-10-05. Its own README labels it "research in progress… Not an implementation, not a description of any deployed system, and not ready." Everything below is sourced from [`research/prior-etna-digest.md`](research/prior-etna-digest.md), which read the primary pages at that revision; this document did not. Treat these as **sourced (via digest)**.

### 4.1 The seat/sortition committee

Sequencing was a **bonded 32-seat committee, not L1 sequencing and not stake-weighted PoS**. A term is 60 s; a term has up to `V_MAX + 1` views; the leader ("holder") is drawn by sortition, `idx(t,k) = keccak(seed(c) || 0x01 || t || k) mod E_t`, with a walk that skips visited or excluded seats and stops at `K` selections or `WALK_MAX = 8K` draws. Attestation is a committee of up to `K = 32` seats with quorum `Q(m) = floor(2m/3) + 1` (`Q(32) = 22`). The safety premise is explicit: "fewer than one third of the **domain seats** are malicious" (T11) — a different security model from stake-weighted PoS.

### 4.2 The one-action landing rule

`land(LandInput)` "carries a range of certified blocks as blobs attached in range order plus one proof, and is the only L1 action that advances `lastLanded`. There is no propose step and no sequencer seal" (C2-R01). `C2-R05` defines eleven ordered checks (L1–L11): sequence, deadline, parent link, segment/VC chain, end certificate, `blobhash(i)` binding, anchor-tip freshness, forced inclusion, replacement, effects, and proof verification. `C2-R04` is the key statement: "nothing on L1 references unproven data"; candidate B's data-first staging gate was explicitly dropped. **This is the strongest alignment with the new project's D5.**

### 4.3 The finality ladder

Labels: sequenced (0.3 s, revertible without slashing) → attested `C(n)` (0.7–1.0 s) → locked (1.7–2.0 s) → fully backed (minimum over the closing chain) → landed (checkpoint written) → landed (provisional) (one-leaf/degraded) → L1-final (provisional) (D98) → final (covering checkpoint plus an authenticated canonical L1 transaction in a beacon-finalized block; no universal wall-clock bound). The 0.3/0.7–1.0/1.7–2.0 s figures are **unmeasured** A-T9 projections (S4-R15 E1 says the 450 ms attestation figure does not follow from the stated 300 + 200 ms), and D78/V38 falsified the published 2 s "locked" backing — the publication is "the publication being repaired, not a sound current guarantee".

### 4.4 The TAIKO bond ledger

"The existing TAIKO gwei bond ledger in the Inbox proxy: per address a balance, two sub-balances, `reserveGwei` and the sentinel pocket `sentinelGwei`, the announcement pocket `announceLockedGwei` … no L2 ledger, no ETH bonds" (S3 section 1). Amounts: `B_SEAT = 20,000 TAIKO` (`2e13 gwei`), explicitly "**derived from assumed inputs**"; `CHALLENGER_BPS/CAP = 1,000 / 2,000 TAIKO`, likewise derived from assumed inputs; `V_term ≈ 0.01 ETH` and `P ≈ 1.5e-4 ETH per TAIKO` are **unmeasured**. L15: "Every TAIKO amount is a formula on assumed inputs (term revenue, exchange rate)." The ledger concept is reusable; the numbers are not.

### 4.5 Readiness was never met

D44 set a seven-item "done" bar; item 5 required two clean full-tree rounds. At the accepted head it stood at **0 of 2**: the full-tree round at `062fda1` found 1 High (C5C7-FT-01, the V5 anchor-age clock), 12 Mediums and 21 Lows (D97), and D100 records that item 5 stays at 0 of 2 and D44 is not complete. No machine-checked model of the view-change and landing state machines exists and no implementation exists (L34: "every 'proven' is argued on a page"); no measurement procedure in the plan ever ran (D69). Two independent designs had been converged, with a third agent as judge.

### 4.6 The one paragraph that matters

The prior programme's rules are hypotheses with review history, not validated mechanisms: its own artifacts record a High in the lock rule, a High in an L1-reference field, a High in an L1-read clock, unclosed recovery-liveness prototypes, and a falsified published guarantee. The new design should import its **rule-id discipline, evidence tags, traceability apparatus and one-action landing rule**, and should treat its mechanisms as prior art to argue against — never as proof.

### 4.7 Structural pins that must be re-derived, never copied

At D1's 2 s cadence the prior grid changes shape. These are the quantities whose old values are tied to the 1 s term (all old values sourced via digest; the new column is **derived** arithmetic where shown, otherwise **unmeasured**):

| Prior quantity | Prior value | At 2 s |
|---|---|---|
| Term length | 60 s = 60 blocks of 1 s | 60 s = 30 blocks (**derived**) |
| Single-proof landing cap | ≤ 240 blocks per `DEGRADE_AFTER` (7,200 s) | 240 blocks = 480 s (**derived**); the 7,200 s window and the cap need a new decision |
| Landing window | `LAND_WINDOW = 1,800 s`, max 3,600 s | **unmeasured**; must cover a 30-min proving latency under D6, unlike the prior happy-path assumption |
| Replacement grace / window | `REPLACE_GRACE = 300 s`; 35–65 min, up to 75 min | tied to the sortition term grid; not reusable |
| Per-term byte caps | `TERM_BYTES_MAX = 1,270,000`; `LANDING_UNIT = 254,000` bytes | assume a 60-block term; re-derive |
| Committee geometry | `K = 32`, `Q(m) = floor(2m/3)+1`, `V_MAX = 4`, redraw 17 | no committee in the new design; set geometry comes from stake and [MEM-08](spec/index.html#ruleindex) |
| Revenue / price inputs | `V_term ≈ 0.01 ETH`, `P ≈ 1.5e-4 ETH/TAIKO` | **unmeasured** even in the prior design; every TAIKO amount is a formula on them |

Nothing in this table may be carried into the new parameter tables as if it were measured; each row must be re-derived and tagged under [PARAM-02](spec/index.html#ruleindex) / [PARAM-03](spec/index.html#ruleindex).

## 5. Known failure traces and what they teach

All rows are from [`research/prior-etna-digest.md`](research/prior-etna-digest.md) §4 (sourced via digest at `a829f797…`). "New design" links a rule id from [`spec/index.html`](spec/index.html) (rule index; anchors resolve at `#ruleindex`) where a rule exists, otherwise **OPEN**.

| Trace | What it attacked | Prior resolution / acceptance | What the NEW design does |
|---|---|---|---|
| **safety-locked-interleaved-branch-closing** (D78 cycle-2 round-1 **High**, S2) | A leader plus one committee position interleave certified heights across two branches, so a **height-only lock rule** moves honest keys to a conflicting block inside the same opening and displaces a locked block with nothing slashable. | W22 repair (D83): signed `parentPhHash`, persistent attested tip, pair lock, set-bit S3b aggregate (S2-R21), redraw backfill, V38/V39 schedules; ancestry checked by equal-height `phHash` identity, not height. | **Rule retained unmodified**: CometBFT lock and proof-of-lock-change [CONS-04](spec/index.html#ruleindex), vote uniqueness per (height, round) [CONS-02](spec/index.html#ruleindex), commit rule [CONS-05](spec/index.html#ruleindex), epoch-scoped forever-valid certificates [CONS-08](spec/index.html#ruleindex), uniqueness invariant [CONS-12](spec/index.html#ruleindex) / [INV-01](spec/index.html#ruleindex). A standing obligation remains: **any** modification of the lock rule re-opens the W22 proof burden. |
| **W22 recovery prototypes** (long empty prefix; repeated recovery reference; first RESUME over a surviving replacement generation; proof-free priority over REPLACE) | Recovery liveness/safety: with ~100 empty closings the chain cannot split across landings; a consumed RESUME scope can be reused; a recorded H can displace an eligible REPLACE fork. | **Not closed.** Recorded as S2-V43 open; the recovery-prefix tree (RPT) was published as a **research note only** (D87); Rule G unadopted. | The new design's honest answer is not to repair recovery but to avoid needing it: **Mode A selected**, no path may invalidate PoS-finalized history [REC-01](spec/index.html#ruleindex); Mode B is specified but not selected, with its D2-step-5 blocker recorded [REC-02](spec/index.html#ruleindex) / [REC-03](spec/index.html#ruleindex); safe halt [HALT-01](spec/index.html#ruleindex), restart [HALT-02](spec/index.html#ruleindex); withholding catalogue [WH-01](spec/index.html#ruleindex)–[WH-04](spec/index.html#ruleindex). **OPEN**: any future Mode B selection must close the analogous recovery-liveness proofs from scratch. |
| **CS-R3-01** (round 3) | "Do not retire signing history on a young L1 recovery": a shallow reorg orphans a young recovery while the key has already permanently retired its old generation. | D92 mature reset: wait for an authenticated canonical landing at least `ANCHOR_MIN_AGE` old; reversible scan cursor plus durable applied-recovery journal. | Only Ethereum-final L1 facts enter L2 consensused state [SYS-02](spec/index.html#ruleindex); L1 reorganisation handling [L1-12](spec/index.html#ruleindex); halt/restart [HALT-01](spec/index.html#ruleindex) / [HALT-02](spec/index.html#ruleindex); key binding, rotation and stale keys [MEM-07](spec/index.html#ruleindex). The maturity window is **OPEN**: its value must be re-derived (the prior default `ANCHOR_MIN_AGE = 48 s` is unmeasured) and recorded under [PARAM-03](spec/index.html#ruleindex). |
| **Anchor-field conflict** (D80, J's **High**) | The merged spec said `parentBeaconBlockRoot` = L1 execution block hash; the implementation stack used the state root, and as merged the state root "leaves C1 section 8's censorship recovery broken: proofs expire with the 8,191-slot ring and nothing pins them." | User chose Option 3: the hash stays normative; the L1 header travels inside the signal proof (C1-R11, D80). | No golden-touch anchor exists in the selected architecture, but the lesson binds every L1→L2 observation field: one field, one meaning, stated once [SYS-01](spec/index.html#ruleindex); only Ethereum-final L1 facts [SYS-02](spec/index.html#ruleindex); Bridge/SignalService authentication anchored at L1 checkpoints [MSG-01](spec/index.html#ruleindex); migration must preserve retained-surface semantics [MIG-02](spec/index.html#ruleindex). **OPEN**: the exact L1→L2 observation encoding is not fixed in the documents read; "a field with two meanings must be impossible by construction" is a named review question. |
| **Full-tree High C5C7-FT-01** (D97) — the V5 anchor-age clock | A fixed-reference L1 read could yield a verdict before its L1 number was mature, so a short fork was reported as divergence. | D99: every fixed-reference L1 read in validity yields a verdict only once mature in the node's own view (`timestamp(H) >= timestamp(X_N) + ANCHOR_MIN_AGE`), else the block is **held**; J attacked the fix with no Critical/High and noted "a client must not treat a hold as INVALID". | Maturity discipline maps to [SYS-02](spec/index.html#ruleindex) plus L1 reorg handling [L1-12](spec/index.html#ruleindex) and safe halt [HALT-01](spec/index.html#ruleindex); the two forbidden inferences are already rules — [STATUS-09](spec/index.html#ruleindex) ("local receipt is not availability") and [STATUS-10](spec/index.html#ruleindex) ("an elapsed timeout is never evidence of absence"). **OPEN**: the maturity window value is unmeasured and must be derived, not copied. |
| **XS-FIN-01** (full-tree Medium) | S2-R18's "final" row said "landing L1-finalized" / "irrevocable", so a one-leaf landing became L1-final while its record stayed PROVISIONAL. | D98: "final" needs an authenticated covering checkpoint written by a successful canonical L1 transaction in a beacon-finalized block; a new "L1-final (provisional)" level was added. | The fixed label ladder is normative: [STATUS-01](spec/index.html#ruleindex)–[STATUS-08](spec/index.html#ruleindex), with [STATUS-04](spec/index.html#ruleindex) separating PoS-finalized from provisional, [STATUS-06](spec/index.html#ruleindex) accepted on L1, [STATUS-07](spec/index.html#ruleindex) Ethereum-finalized, and [STATUS-11](spec/index.html#ruleindex) the label-disclosure obligation; [REC-01](spec/index.html#ruleindex) makes finalized history irrevocable. Rule of thumb: **never publish a label whose evidence is not the evidence listed for that label**. |

### 5.7 Other traces carried forward

| Trace | Lesson for the new design |
|---|---|
| **V38 / D78** — the published 2 s "locked" guarantee was falsified by the design's own review. | A published confirmation label is a security artifact: [STATUS-11](spec/index.html#ruleindex) disclosure, and D1's 2 s is cadence, never finality ([SYS-03](spec/index.html#ruleindex)). |
| **B-D21-01** (conditional High) — a colluding quorum displaces a LOCKED successor through a second closing recorded first, with no listed evidence. | Vote uniqueness [CONS-02](spec/index.html#ruleindex) and equivocation evidence [CONS-11](spec/index.html#ruleindex); objective evidence only ([ECON-04](spec/index.html#ruleindex)). |
| **G5 / G5-F** — a private quorum certificate stalls landing with nothing slashable until the hatch or dead mode. | Accepted-and-disclosed is a legitimate precedent but not a repair: withholding catalogue [WH-01](spec/index.html#ruleindex)–[WH-04](spec/index.html#ruleindex), safe halt [HALT-01](spec/index.html#ruleindex). |
| **Sortition defects** (B's W8/D19) — a walk without an attempt counter over a live committee size is not a walk. | The seat/sortition mechanism is not reusable as PoS; the new design authenticates a stake-weighted set instead ([MEM-02](spec/index.html#ruleindex), [MEM-08](spec/index.html#ruleindex)). |
| **D33 forced-inclusion machinery** (renewable waivers, stall clock, run caps) — withdrawn by D39 as attackable. | Reuse the *hatch concept* (a request path that cannot be ignored), not the withdrawn machinery: [FI-01](spec/index.html#ruleindex)–[FI-05](spec/index.html#ruleindex). |
| **Withholding W1–W7** — every message class can be withheld; "non-receipt is not provable on L1". | [WH-01](spec/index.html#ruleindex)–[WH-04](spec/index.html#ruleindex); never infer misconduct from silence ([STATUS-10](spec/index.html#ruleindex)). |
| **Readiness process** — only full-tree rounds under the two-refuter protocol counted; delta rounds did not reset the bar. | The new project's convergence bar (two consecutive clean full rounds, ≥3 independent reviewers) should be read the same way: a clean delta round is not a clean full round. |

## 6. Reuse / do not reuse from prior Etna

### 6.1 Reuse (with reasons)

| Asset | Why it transfers |
|---|---|
| Rule-id discipline and evidence tags (C1-R01…S4-R15, vector ids, invariants I1–I5, register rows L1–L51) | [GEN-03](spec/index.html#ruleindex) / [GEN-04](spec/index.html#ruleindex) adopt the same "one rule, one place, stable identifiers" and Proven/Assumed/Open tagging. |
| Traceability apparatus (rule → owner/inputs/failure/vector; 143/143 rules complete; 81 error names) | A ready template for the new specification's rule-to-vector traceability and error families. |
| The one-action landing rule (C2-R01/R04/R05) | Directly implements D5: one transaction, data bound by `blobhash`/calldata, proof verified in the same call. New rules: [L1-01](spec/index.html#ruleindex), [L1-02](spec/index.html#ruleindex), [DA-01](spec/index.html#ruleindex)–[DA-03](spec/index.html#ruleindex). |
| The TAIKO gwei bond-ledger **concept** (per-address balance, sub-balances, pockets; no ETH bonds, no L2 ledger) | Matches D7 and the existing Inbox ledger; new rules [ECON-01](spec/index.html#ruleindex), [MEM-01](spec/index.html#ruleindex). |
| The finality-ladder **label concept** (evidence set, guarantee, revocation per label) | Adopted as the fixed label ladder [STATUS-01](spec/index.html#ruleindex)–[STATUS-11](spec/index.html#ruleindex), with D98's lesson built in. |
| Hashing and domain-tag conventions (canonical `abi.encode` of typed fields; versioned `bytes32` domain tags) | New rule [GEN-05](spec/index.html#ruleindex); the current Inbox's undomained `Commitment` hash is exactly what this prevents. |
| Parameter-table discipline and the measurement-plan template (C6 MP-01…MP-35: default, procedure, out-of-range action, owner) | Adopted as [PARAM-01](spec/index.html#ruleindex)–[PARAM-03](spec/index.html#ruleindex); keeps proposed values from masquerading as measurements. |
| Safety-first building blocks: certificates + locks, the L1-checkpoint finality predicate, objective evidence with no accusation object (I5), permissionless landing/replacement, a forced-inclusion hatch | These map onto [CONS-04](spec/index.html#ruleindex), [CONS-05](spec/index.html#ruleindex), [ECON-04](spec/index.html#ruleindex), [FI-03](spec/index.html#ruleindex) and [REC-01](spec/index.html#ruleindex) without importing the sortition model. |
| Storage-compatibility discipline for retained surfaces (C4-R10/R11, C1-R10: keep proxy addresses, inherited fields, signal slots, checkpoint map root and value ordering) | Required by D3; new rules [MIG-02](spec/index.html#ruleindex), [MIG-06](spec/index.html#ruleindex). |

### 6.2 Do not reuse (with reasons)

| Asset | Why not |
|---|---|
| 1 s cadence constants and level timings (TERM 60 blocks of 1 s, handoff on a 1 s grid, 0.3/0.7–1.0/1.7–2.0 s, 240-block single-proof arithmetic, per-term byte caps) | Conflicts with D1's 2 s cadence and every figure is an **unmeasured** A-T9 projection; re-derive under [PARAM-02](spec/index.html#ruleindex). |
| Sortition/seat economics as "PoS" (S1-R11…R19 walk, domain tree, CAP, T11's "one third of domain seats") | A different security model (bonded seats, not stake weight); reusing it would misrepresent seat share as stake, against [GEN-09](spec/index.html#ruleindex). |
| The published 2 s "locked" guarantee (S2-R18/D1) | Falsified by the prior programme's own review at D78/V38: "the publication being repaired, not a sound current guarantee"; a label without its evidence is exactly what [STATUS-11](spec/index.html#ruleindex) forbids. |
| Shasta migration machinery as a whole (freeze/drain/abandon, `DRAIN_DEADLINE = 86,400 s`, legacy SGX admission, LEGACY_BLOB terms, L47) | Only relevant if the new project migrates that chain; the retained-surface storage discipline is reusable, the lifecycle is not. |
| D26's power removals as a package (Anchor.withdraw, DefaultResolver.registerAddress, owner mint/burn) | These are behaviour changes, not preservation; decide each lever explicitly under R1/R2 and [MIG-04](spec/index.html#ruleindex). |
| Degraded/single-proof throughput rules (L-SPT, LS1-2, sentinel chains, DEGRADE_AFTER-only mode, ≤240 blocks per 7,200 s) | Built around a two-leaf outage with a steep cap; under D6 a 30-min proof is normal, so thresholds must be redesigned rather than copied. |
| Failed/unadopted designs: single-proof split timer, sentinel continuation, RPT long-prefix admission, Rule G, G5's stateful fix | Explicitly recorded as failed attack or unadopted ("inert until then"); importing them imports the unclosed proofs. |
| The old per-block forced-inclusion machinery (stall clock, waivers, run caps) | Withdrawn by D39; the hatch replaces it, and the hatch's own residuals were signed, not proven. |
| C6 measurement values as facts | "No procedure has run" (D69); every MP default is a conservative placeholder and MP-05's worst-case landing gas fit is open. |
| Old committee handoff/redraw timing bounds (V_MAX = 4, redraw 17, 35–65/75-minute replacement windows, 96–108 s full-backing delay) | Tied to the sortition committee and the 1 s term grid; meaningless once the consensus mechanism is replaced. |

## 7. Consequences for the new design

### 7.1 Remove the data-first path (D5)

The current split — `propose()` (`Inbox.sol:270`) then `prove()` (`Inbox.sol:321`) — is the data-first design D5 forbids, and the baseline's D5 verdict is explicit: separate transactions are "the only supported flow" today. The new design therefore needs:

- **one atomic accept entry point**: no selector accepts data without verifying a proof over that data in the same call ([L1-01](spec/index.html#ruleindex));
- **no pending or incomplete batch record**: no entry point may persist a batch before its proof verifies ([L1-02](spec/index.html#ruleindex)), and a failed verification must leave no partial effect ([L1-03](spec/index.html#ruleindex));
- **no admission gate and no expiring range** ([L1-04](spec/index.html#ruleindex)) — the current `NotEnoughCapacity` ring (`Inbox.sol:591-593`) and the `init3` void are both symptoms of holding references to unproven data;
- **forced inclusion expressed as a validity rule** on the atomic path, not as a queue the proposer must service ([FI-02](spec/index.html#ruleindex)).

**Storage consequence:** do not plan a staging queue in the Inbox's gap. The only room is 43 slots at 258–300, and D5 removes the reason to spend one on unproven data.

### 7.2 Design out the blob-expiry class

The June 2026 failure is the class to design out: a pending reference outlives its blob retention window, and the recovery is an owner void (`init3()`, `Inbox.sol:246-258`) with fees unrefunded. D5 changes the invariant: **no protocol state may reference blob data that has not been accepted in the same transaction**. Consequences:

- data is published *with* the proof, so a pending batch cannot outlive its own blob pointer ([L1-01](spec/index.html#ruleindex), [DA-01](spec/index.html#ruleindex));
- a calldata path removes expiry entirely for the batches that use it ([DA-02](spec/index.html#ruleindex)); the blob path needs the on-chain KZG opening plus in-guest evaluation ([DA-03](spec/index.html#ruleindex), [PRF-07](spec/index.html#ruleindex));
- a consensus-enforced unsettled-depth cap keeps the outstanding backlog inside the retrievability window ([HALT-03](spec/index.html#ruleindex), [DA-05](spec/index.html#ruleindex), [DA-06](spec/index.html#ruleindex)). The prior design quoted a blob retention window "about 18 days" (**sourced via digest, unmeasured here**), and EIP-2935 gives a past-block-hash window of 8,191 L2 blocks (about 2.3 h at 1 s; ~4.6 h at 2 s — **derived**), which the prior design flagged as an open dependency.

### 7.3 Remove the privileged levers (R1/R2)

Every lever in [§3.9](#39-every-privileged-lever) is live today. R1/R2 require that operational authority disappear; the new rules that must carry that are [SYS-04](spec/index.html#ruleindex) (no DAO or emergency operator in ordinary operation), [ROLE-05](spec/index.html#ruleindex) (DAO = upgrades only), [GOV-01](spec/index.html#ruleindex), [L1-04](spec/index.html#ruleindex) (any prover), [ROLE-01](spec/index.html#ruleindex) / [ROLE-02](spec/index.html#ruleindex) (permissionless roles), [HALT-04](spec/index.html#ruleindex) (no emergency rescue), and [MIG-04](spec/index.html#ruleindex) (removal of operational privileges during migration). Two levers are **immutables, not settings**, so they cannot be "turned off" — the implementation must be replaced:

1. `SignalService._authorizedSyncer` is fixed at construction (`SignalService.sol:37,86-90`) with no setter; re-pointing it means an implementation upgrade ([MIG-02](spec/index.html#ruleindex)).
2. `GOLDEN_TOUCH_ADDRESS` is a hardcoded constant in the Anchor (`Anchor.sol:37`) and `anchorV4` is its only checkpoint path; removing the golden touch is a code change, not a role revocation.

The preconf and prover whitelists are simpler: the new Inbox must not wire an `IProposerChecker` or `IProverWhitelist` at all, and the inherited pause on the retained surfaces must not gate the accept path ([SYS-04](spec/index.html#ruleindex)).

### 7.4 Storage-layout rules constrain every upgrade

The rules in [§3.6](#36-storage-layout-constraints) are not advice; they are the boundary of what D3 permits. Concretely:

1. New state goes **only** in the trailing gap of the contract that holds it: Inbox first free slot 258 (43 slots), SignalService 255 (46), Bridge 257 (44), Anchor 258 (43). A design that needs a per-transition record, a validator-set registry or a pending-proof record must budget those slots explicitly.
2. **Nothing may be reordered, retyped or deleted**, and deprecated slots stay frozen — the new design cannot repurpose `_bondStorage`, `_proposalHashes` or the Pacaya residual slots.
3. The 151-slot prefix must remain identical for anything that continues to sit behind a fork router, and the retained signal slots and checkpoint map root must keep their derivation ([MIG-02](spec/index.html#ruleindex)).
4. `pnpm layout` before and after every change is the operational check; every upgrade entry point must accept previously finalized history ([GOV-03](spec/index.html#ruleindex), [MIG-06](spec/index.html#ruleindex)).

### 7.5 What this document does not decide

This is a baseline and lessons consolidation, not an architecture document. It does not choose the consensus mechanism, the staking parameters, the recovery trigger set, the proof-system versions or the migration sequence; those are decided in [04-architecture-decision.md](04-architecture-decision.md) and stated normatively in `spec/`. Where the two halves of this document conflict with a later decision, the later decision wins and this document must be corrected — the same rule the requirements document applies to itself.

## 8. Open questions (ordered by importance)

1. **Is the Mode A availability counterexample reachable *inside* the stated liveness assumptions?** If certified-but-unavailable data can occur while every assumption holds, Mode A's selection must be revisited (04 §5.2's stated falsifier; review question Q-A1). Rules: [REC-01](spec/index.html#ruleindex), [REC-03](spec/index.html#ruleindex), [HALT-01](spec/index.html#ruleindex).
2. **What bounds the unsettled backlog at a 30-minute proving latency, and who bears the halt when the cap binds?** D6 makes 30 min normal, but the backlog interacts with the retrievability window and with any recovery story ([HALT-03](spec/index.html#ruleindex), [DA-06](spec/index.html#ruleindex)); the numbers are unmeasured.
3. **What is the exact L1→L2 observation encoding, and which rule prevents a field from carrying two meanings?** This is the anchor-field-conflict lesson applied to the new architecture; the pages read do not fix it ([SYS-01](spec/index.html#ruleindex), [SYS-02](spec/index.html#ruleindex), [MSG-01](spec/index.html#ruleindex)). **OPEN**.
4. **Does the epoch handoff preserve locks across validator-set versions?** Modification M2 in 04 §2.1 is explicitly assumed-with-argument, not proven; it is the named review target F1 ([CONS-09](spec/index.html#ruleindex), [CONS-08](spec/index.html#ruleindex)).
5. **Does the blob-path binding hold against a grinding prover, and what does the in-guest evaluation cost?** Q-A3 and F2; the cost is **unmeasured** ([DA-03](spec/index.html#ruleindex), [PRF-07](spec/index.html#ruleindex)).
6. **Can the live Inbox be upgraded in place, and what happens to its pending state?** Bonds, forced inclusions, the post-`init3` queue state and the current `_proofVerifier` wiring must be enumerated before any migration plan is credible ([MIG-02](spec/index.html#ruleindex), [MIG-03](spec/index.html#ruleindex)). Live wiring is **UNVERIFIED**.
7. **How are the immutable single-writer checkpoints replaced without changing retained addresses?** The L1 SignalService's syncer and the L2 golden touch are constructor constants ([SignalService.sol:37](spec/index.html#ruleindex), `Anchor.sol:37`); the migration must replace implementations and re-point writers without breaking historical proofs ([MIG-02](spec/index.html#ruleindex), [MIG-03](spec/index.html#ruleindex)).
8. **Is the 2 s cadence achievable under a permissionless global validator set?** Measurement gate F3; currently an assumption, not a measurement ([PARAM-02](spec/index.html#ruleindex)).
9. **What are the TAIKO amounts?** Every prior amount (B_SEAT, CHALLENGER_CAP, rewards) is derived from unmeasured revenue and price inputs; they must be re-derived and tagged unmeasured until measured ([ECON-09](spec/index.html#ruleindex), [ECON-12](spec/index.html#ruleindex), [PARAM-03](spec/index.html#ruleindex)).
10. **What is the weak-subjectivity freshness window, and is any trusted checkpoint provider introduced?** The prior design's answer does not transfer; the new rule must state source and freshness explicitly ([MEM-11](spec/index.html#ruleindex), [MEM-12](spec/index.html#ruleindex)).
11. **What is the exact maturity window for fixed-reference L1 reads?** The D99 lesson demands one, but its value is a new derivation, not a copy of `ANCHOR_MIN_AGE` ([SYS-02](spec/index.html#ruleindex), [L1-12](spec/index.html#ruleindex), [PARAM-03](spec/index.html#ruleindex)).
12. **When do the missing specification pages land?** The rule index references `04-l1-integration.html`, `07-economics.html` and `08-migration-upgrades.html`, which were not present in `spec/` when this document was written; until they exist, every rule link here resolves only to the index. This is a process dependency, not a security question.
