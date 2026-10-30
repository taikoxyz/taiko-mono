# Taiko Protocol — Implementation Baseline for the "PoS + ZK-in-one-tx" Redesign

Scope: factual, implementation-grade description of the CURRENT protocol surface at the pinned commit, limited to the files listed in the extraction brief. All citations are **repo-root-relative** `path:line` or `path:first-last`. Nothing here is inferred from documentation prose: every claim is anchored to Solidity source or to a deployment log in this repository.

---
## 1. Pin record

| Item | Value | Source |
| --- | --- | --- |
| Commit hash | `7718753c1cece7d7705afaf33e6f9680115086dd` | `git rev-parse HEAD` |
| Branch | `etna-pos-zk` | `git rev-parse --abbrev-ref HEAD` |
| Commit date | 2026-10-05 01:41:56 +0000 | `git log -1` |
| Retrieval date | 2026-10-05 | this session |
| Working tree | clean (`git status --porcelain` empty) | `git status` |
| solc | `0.8.30` | `packages/protocol/foundry.toml:9` |
| EVM version (default / layer2 / shared / genesis) | `osaka` | `foundry.toml:14`, `:140`, `:150`, `:159` |
| Optimizer | `true`, `optimizer_runs = 200` | `foundry.toml:6-7` |
| Foundry profiles | `default`, `layer1`, `layer1o` (via_ir), `layer2`, `shared`, `genesis` | `foundry.toml:1,108,120,132,142,152` |
| Forge version pin | **not found** in `foundry.toml` | — |

Files read for this baseline:

- `packages/protocol/contracts/layer1/core/impl/Inbox.sol`, `ProverWhitelist.sol`, `ProverWhitelist_Layout.sol`
- `packages/protocol/contracts/layer1/core/iface/{IInbox,IBondManager,ICodec,IForcedInclusionStore,IProposerChecker,IProverWhitelist}.sol`
- `packages/protocol/contracts/layer1/core/libs/{LibCodec,LibTransitionCodec,LibBlobs,LibBonds,LibForcedInclusion,LibHashOptimized,LibInboxSetup}.sol` (LibPackUnpack inspected only via its call sites)
- `packages/protocol/contracts/layer1/mainnet/{MainnetInbox,MainnetInbox_Layout,MainnetVerifier,LibL1Addrs,TaikoToken}.sol`
- `packages/protocol/contracts/layer1/verifiers/**` (all 16 `.sol` files; `SgxVerifier.sol` read in part) and `packages/protocol/contracts/layer1/preconf/**` (5 files)
- `packages/protocol/contracts/shared/signal/{SignalService,ISignalService,ICheckpointStore,SignalService_Layout,SignalServiceForkRouter_Layout}.sol`; `shared/bridge/{Bridge,IBridge,Bridge_Layout,QuotaManager}.sol`; `shared/vault/{BaseVault,ERC20Vault,ERC721Vault,ERC1155Vault,*_Layout}.sol`; `shared/fork-router/{ForkRouter,ForkRouter_Layout}.sol`; `shared/common/EssentialContract.sol`
- `packages/protocol/contracts/layer2/core/{Anchor,Anchor_Layout,AnchorForkRouter_Layout,BondManager_Layout}.sol`; `layer2/{mainnet/LibL2Addrs,hoodi/LibL2HoodiAddrs}.sol`
- `packages/protocol/deployments/*.md`, `packages/protocol/foundry.toml`, `script/layer1/core/DeployProtocolOnL1.s.sol`, `script/layer1/core/DeployShastaContracts.s.sol`, `script/layer2/DeployShastaL2Contracts.s.sol`

---
## 2. Inbox surface

`contract Inbox is IInbox, ICodec, IForcedInclusionStore, IBondManager, EssentialContract` — `packages/protocol/contracts/layer1/core/impl/Inbox.sol:36`

### 2.1 Immutables (set only in the constructor)

| Variable | Type | Line |
| --- | --- | --- |
| `_proofVerifier` | `IProofVerifier` | `Inbox.sol:72` |
| `_proposerChecker` | `IProposerChecker` | `Inbox.sol:75` |
| `_proverWhitelist` | `IProverWhitelist` (address(0) = disabled) | `Inbox.sol:78` |
| `_signalService` | `ISignalService` | `Inbox.sol:81` |
| `_bondToken` | `IERC20` | `Inbox.sol:84` |
| `_minBond` | `uint64` (gwei) | `Inbox.sol:87` |
| `_livenessBond` | `uint64` (gwei) | `Inbox.sol:90` |
| `_withdrawalDelay` | `uint48` | `Inbox.sol:93` |
| `_provingWindow` | `uint48` | `Inbox.sol:96` |
| `_permissionlessProvingDelay` | `uint48` | `Inbox.sol:99` |
| `_maxProofSubmissionDelay` | `uint48` | `Inbox.sol:102` |
| `_ringBufferSize` | `uint48` | `Inbox.sol:105` |
| `_basefeeSharingPctg` | `uint8` | `Inbox.sol:108` |
| `_forcedInclusionDelay` | `uint16` (seconds) | `Inbox.sol:111` |
| `_forcedInclusionFeeInGwei` | `uint64` | `Inbox.sol:114` |
| `_forcedInclusionFeeDoubleThreshold` | `uint64` | `Inbox.sol:117` |
| `_permissionlessInclusionMultiplier` | `uint8` | `Inbox.sol:121` |

Constructor: `Inbox.sol:153-173`; config validation `LibInboxSetup.validateConfig` — `layer1/core/libs/LibInboxSetup.sol:24-45`. Rejected: zero proofVerifier / proposerChecker / signalService / bondToken (`:26-29`), zero `provingWindow` (`:30`), `permissionlessProvingDelay <= provingWindow` (`:31-34`), `ringBufferSize < 2` (`:35`), `basefeeSharingPctg > 100` (`:36`), zero forced-inclusion fee / threshold (`:37-40`), `permissionlessInclusionMultiplier <= 1` (`:41-44`).

### 2.2 State variables and storage layout ordering

| Slot(s) | Variable | Type | Declared |
| --- | --- | --- | --- |
| 251 | `activationTimestamp` | `uint48` (public) | `Inbox.sol:128` |
| 252-253 | `_coreState` | `IInbox.CoreState` (2 slots, 64 bytes) | `Inbox.sol:131` |
| 254 | `_proposalHashes` | `mapping(uint256 bufferSlot => bytes32 proposalHash)` | `Inbox.sol:136` |
| 255-256 | `_forcedInclusionStorage` | `LibForcedInclusion.Storage` (2 slots) | `Inbox.sol:140` |
| 257 | `_bondStorage` | `LibBonds.Storage` (1 slot) | `Inbox.sol:143` |
| 258-300 | `__gap` | `uint256[43]` | `Inbox.sol:145` |

Slot numbers are the generated layout in `layer1/mainnet/MainnetInbox_Layout.sol:10-26`. Slots 0-250 are reserved by the inheritance chain (`MainnetInbox_Layout.sol:10-20`): 0 `_initialized/_initializing`, 1-50 `__gap`, 51 `_owner`, 52-100 `__gap`, 101 `_pendingOwner`, 102-150 `__gap`, 151-200 `__gapFromOldAddressResolver`, 201 `__reentry/__paused`, 202-250 `__gap`.

`CoreState` field order (`layer1/core/iface/IInbox.sol:83-97`): `uint48 nextProposalId`, `uint48 lastProposalBlockId`, `uint48 lastFinalizedProposalId`, `uint48 lastFinalizedTimestamp`, `uint48 lastCheckpointTimestamp` (all five pack into one slot, `IInbox.sol:82`), `bytes32 lastFinalizedBlockHash`.

### 2.3 Every external / public function

| Signature | Kind | What it does | Line |
| --- | --- | --- | --- |
| `constructor(Config)` | — | sets all immutables | `Inbox.sol:153-173` |
| `init(address _owner)` | initializer | `__Essential_init` | `Inbox.sol:181-183` |
| `activate(bytes32 _lastPacayaBlockHash)` | **onlyOwner** | bootstrap: sets `activationTimestamp` and `_coreState` (nextProposalId=1, lastProposalBlockId=1), stores the genesis proposal hash at buffer slot 0, emits `Proposed` + `InboxActivated` | `Inbox.sol:188-201` |
| `init2(uint48 _lastFinalizedProposalId, bytes32 _lastFinalizedBlockHash)` | **onlyOwner** + `reinitializer(2)` | incident recovery; preserves `nextProposalId`/`lastProposalBlockId`; emits `StateRecovered` | `Inbox.sol:217-244` |
| `init3()` | **onlyOwner** + `reinitializer(3)` | voids the forced-inclusion queue via `head = tail`; emits `ForcedInclusionsVoided` | `Inbox.sol:253-258` |
| `propose(bytes _lookahead, bytes _data)` | external `nonReentrant` | accepts a **data-only** proposal (§3); no proof argument | `Inbox.sol:270-290` |
| `prove(bytes _data, bytes _proof)` | external `nonReentrant` | accepts proof + commitment; finalizes a contiguous range (§3) | `Inbox.sol:321-400` |
| `deposit(uint64 _amount)` | external `nonReentrant` | bond credit; clears own pending withdrawal | `Inbox.sol:403-405` |
| `depositTo(address _recipient, uint64 _amount)` | external `nonReentrant` | bond credit to a recipient | `Inbox.sol:408-410` |
| `withdraw(address _to, uint64 _amount)` | external `nonReentrant` | bond debit + ERC20 transfer | `Inbox.sol:413-415` |
| `requestWithdrawal()` | external `nonReentrant` | starts the withdrawal delay | `Inbox.sol:418-420` |
| `cancelWithdrawal()` | external `nonReentrant` | cancels it | `Inbox.sol:423-425` |
| `saveForcedInclusion(LibBlobs.BlobReference)` | external **payable** | enqueues one blob as a forced inclusion | `Inbox.sol:431-443` |
| `encodeProposeInput / decodeProposeInput` | external pure | wire codec | `Inbox.sol:446-461` |
| `encodeProveInput / decodeProveInput` | external pure | wire codec | `Inbox.sol:464-479` |
| `hashProposal(IInbox.Proposal) → bytes32` | external pure | `keccak256(abi.encode(p))` | `Inbox.sol:482-484` |
| `hashCommitment(IInbox.Commitment) → bytes32` | external pure | see §4 | `Inbox.sol:487-493` |
| `getBond(address) → Bond` | view | bond ledger | `Inbox.sol:499-501` |
| `getCurrentForcedInclusionFee() → uint64` | view | current dynamic fee | `Inbox.sol:504-508` |
| `getForcedInclusions(uint48 _start, uint48 _maxCount)` | view | queue read | `Inbox.sol:511-520` |
| `getForcedInclusionState() → (uint48 head, uint48 tail)` | view | queue pointers | `Inbox.sol:523-525` |
| `getConfig() → Config` | view | echoes all immutables | `Inbox.sol:528-548` |
| `getCoreState() → CoreState` | view | `Inbox.sol:551-553` |
| `getProposalHash(uint256) → bytes32` | public view | `_proposalHashes[_proposalId % _ringBufferSize]` | `Inbox.sol:559-561` |
| inherited `pause/unpause/impl/paused/inNonReentrant/resolver/owner/pendingOwner` | public | `shared/common/EssentialContract.sol:150-185` |
| inherited `upgradeToAndCall/upgradeTo/proxiableUUID` | public **onlyOwner** | `EssentialContract.sol:207` |

**The Inbox is not pause-gated.** No function in `Inbox.sol` carries `whenNotPaused` and there is no `_authorizePause` override (grep for `whenNotPaused|_authorizePause` in `Inbox.sol` returns zero matches). `pause()` succeeds but gates nothing.

### 2.4 Events

| Event | Signature | Emitted at |
| --- | --- | --- |
| `Proposed` | `(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, DerivationSource[] sources)` | decl `IInbox.sol:169-176`; `Inbox.sol:748-755` |
| `Proved` | `(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver)` | decl `IInbox.sol:183-188`; `Inbox.sol:382-387` |
| `StateRecovered` | `(uint48 nextProposalId, uint48 lastFinalizedProposalId, bytes32 lastFinalizedBlockHash)` | `IInbox.sol:194-196`; `Inbox.sol:241-243` |
| `ForcedInclusionsVoided` | `(uint48 oldHead, uint48 newHead)` | `IInbox.sol:201`; `Inbox.sol:257` |
| `InboxActivated` | `(bytes32 lastPacayaBlockHash)` | `Inbox.sol:56`, `:200` |
| `ForcedInclusionSaved` | `(ForcedInclusion forcedInclusion)` | `IForcedInclusionStore.sol:18`; `LibForcedInclusion.sol:66` |
| `BondDeposited / BondWithdrawn / WithdrawalRequested / WithdrawalCancelled / LivenessBondSettled` | see `IBondManager.sol:29,34,39,43,51-57` | `LibBonds.sol:53,88,105,114,167` |
| `CheckpointSaved` | `(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot)` | `ICheckpointStore.sol:30`; emitted at `SignalService.sol:183` |
| `Paused / Unpaused` | `(address account)` | `EssentialContract.sol:44,48` |

### 2.5 Errors

`Inbox.sol:817-831`: `ActivationRequired, CannotProposeInCurrentBlock, DeadlineExceeded, EmptyBatch, FirstProposalIdTooLarge, IncorrectProposalCount, InsufficientBond, InvalidRecoveryState, LastProposalAlreadyFinalized, LastProposalHashMismatch, LastProposalIdTooLarge, NotEnoughCapacity, ParentBlockHashMismatch, ProverNotWhitelisted, UnprocessedForcedInclusionIsDue`.

Library errors: `LibBlobs.sol:61-62` (`BlobNotFound, NoBlobs`); `LibBonds.sol:211-215` (`InvalidAddress, MustMaintainMinBond, NoBondToWithdraw, NoWithdrawalRequested, WithdrawalAlreadyRequested`); `LibForcedInclusion.sol:176-178` (`InsufficientFee, InvalidFeeDoubleThreshold, OnlySingleBlobAllowed`); `LibInboxSetup.sol:95-107` (`ActivationPeriodExpired, BasefeeSharingPctgTooLarge, BondTokenZero, ForcedInclusionFeeDoubleThresholdZero, ForcedInclusionFeeInGweiZero, InvalidLastPacayaBlockHash, PermissionlessProvingDelayTooSmall, PermissionlessInclusionMultiplierTooSmall, ProofVerifierZero, ProposerCheckerZero, ProvingWindowZero, RingBufferSizeTooSmall, SignalServiceZero`); `EssentialContract.sol:50-55` (`INVALID_PAUSE_STATUS, FUNC_NOT_IMPLEMENTED, REENTRANT_CALL, ACCESS_DENIED, ZERO_ADDRESS, ZERO_VALUE`).

### 2.6 The exact accepted state

There is **no per-transition or per-proposal record other than a hash**. The complete accepted state after `prove()` is:

1. `_proposalHashes[proposalId % _ringBufferSize] = keccak256(abi.encode(Proposal))` — written in `propose()` (`Inbox.sol:286`, `_setProposalHash` `:627-629`), read by `getProposalHash` (`:559-561`). The slot is **overwritten** on wrap-around (`Inbox.sol:626`).
2. `CoreState`: `nextProposalId`/`lastProposalBlockId` advanced in `propose` (`:284-285`); `lastFinalizedProposalId`, `lastFinalizedTimestamp`, `lastCheckpointTimestamp`, `lastFinalizedBlockHash` advanced in `prove` (`:376-380`).
3. `SignalService` checkpoint: `_checkpoints[VERSION][blockNumber] = {blockHash, stateRoot}` (`SignalService.sol:72-73,179-181`), written from `prove()` with `blockNumber = commitment.endBlockNumber`, `stateRoot = commitment.endStateRoot`, `blockHash = commitment.transitions[numProposals-1].blockHash` (`Inbox.sol:364-370`).

There is no `lastProposalHash` storage variable: the parent link lives inside the hashed `Proposal` struct (`IInbox.sol:70`, set at `Inbox.sol:616` as `getProposalHash(_nextProposalId - 1)`), and the proof-side link is `commitment.lastProposalHash` checked against `getProposalHash(lastProposalId)` (`Inbox.sol:348-351`).

---
## 3. How a batch is currently accepted — and whether data and proof can be split (D5)

### 3.1 The two transactions

`propose()` (`Inbox.sol:270-290`) accepts **only** the lookahead payload and an encoded `ProposeInput`:

```solidity
// Inbox.sol:270-273
function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
    unchecked {
        ProposeInput memory input = LibCodec.decodeProposeInput(_data);
        _validateProposeInput(input);
```

`ProposeInput` has exactly three fields (`IInbox.sol:100-109`): `uint48 deadline`, `LibBlobs.BlobReference blobReference` (`uint16 blobStartIndex, uint16 numBlobs, uint24 offset`, `LibBlobs.sol:10-17`), `uint16 numForcedInclusions`. **No proof, no state root, no block hash, no transition array.**

`prove()` is a **separate external function** that carries the proof (`Inbox.sol:321`):

```solidity
// Inbox.sol:321-325
function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
    unchecked {
        CoreState memory state = _coreState;
        ProveInput memory input = LibCodec.decodeProveInput(_data);
```

> **Verdict for D5: yes — batch data and the validity proof are submitted in separate L1 transactions today, and that is the only supported flow.** `propose` never sees a proof; `prove` never sees blob data (it re-reads nothing from blobs — the blob slice was frozen into the `Proposal` hash at propose time via `LibBlobs.validateBlobReference` → `blobhash(...)`, `LibBlobs.sol:44-48`, called at `Inbox.sol:599`). There is no code path that accepts both in one call.

### 3.2 Exact code path, `propose()`

1. decode `ProposeInput` (`Inbox.sol:272`); `_validateProposeInput` only checks `deadline == 0 || block.timestamp <= deadline` (`:764-766`, error `DeadlineExceeded`).
2. `require(nextProposalId > 0, ActivationRequired())` (`:278`).
3. `_buildProposal` (`:577-623`):
   - `require(block.number > lastProposalBlockId, CannotProposeInCurrentBlock())` — at most one proposal per L1 block (`:590`);
   - `require(_ringBufferSize > nextProposalId - lastFinalizedProposalId, NotEnoughCapacity())` (`:591-593`);
   - consume forced inclusions (`:595-596`, §5);
   - `LibBlobs.validateBlobReference(_input.blobReference)` binds this tx's `blobhash` values (`:598-599`);
   - `_proposerChecker.checkProposer(msg.sender, _lookahead)` (`:602-603`) under the comment `// Permissionless proposing is temporarily disabled.` (`:601`);
   - `require(_bondStorage.hasSufficientBond(msg.sender, _minBond), InsufficientBond())` **only if** `_minBond > 0` (`:604-607`);
   - `originBlockNumber = block.number - 1`, `originBlockHash = blockhash(parentBlockNumber)` (`:610-618`).
4. persist: `_coreState.nextProposalId += 1`, `_coreState.lastProposalBlockId = block.number`, `_setProposalHash(proposal.id, LibHashOptimized.hashProposal(proposal))` (`:284-286`), then emit `Proposed` (`:288`).

### 3.3 Exact code path, `prove()` → proof verification

1. `_validateCommitment(state, commitment)` (`:333-334`, body `:788-812`):
   - `numProposals > 0` else `EmptyBatch` (`:800`);
   - `require(firstProposalId <= firstUnfinalizedId, FirstProposalIdTooLarge())` (`:801`) — the range may start at or before the last finalized proposal;
   - `require(lastProposalId < nextProposalId, LastProposalIdTooLarge())` (`:804`);
   - `require(lastProposalId >= firstUnfinalizedId, LastProposalAlreadyFinalized())` (`:805`);
   - `offset = firstUnfinalizedId - firstProposalId` (`:810`).
2. `proposalAge = block.timestamp - commitment.transitions[offset].timestamp` (`:336`); `_checkProver(msg.sender)` (`:337`).
3. parent-hash continuity: `require(state.lastFinalizedBlockHash == expectedParentHash, ParentBlockHashMismatch())` where `expectedParentHash = offset == 0 ? commitment.firstProposalParentBlockHash : commitment.transitions[offset-1].blockHash` (`:342-346`).
4. `require(commitment.lastProposalHash == getProposalHash(lastProposalId), LastProposalHashMismatch())` (`:348-351`).
5. liveness bond settlement **only if the prover whitelist is not enabled** (`:356-359`).
6. checkpoint sync — written **before** proof verification (`:361-371`):

```solidity
// Inbox.sol:364-370
_signalService.saveCheckpoint(
    ICheckpointStore.Checkpoint({
        blockNumber: commitment.endBlockNumber,
        stateRoot: commitment.endStateRoot,
        blockHash: commitment.transitions[numProposals - 1].blockHash
    })
);
```

7. core-state finalization and `Proved` emission **before** proof verification (`:376-387`).
8. proof verification, last (`:389-398`):

```solidity
// Inbox.sol:394-398
_proofVerifier.verifyProof(
    numProposals - offset == 1 ? proposalAge : 0,
    LibHashOptimized.hashCommitment(commitment),
    _proof
);
```

Because steps 6-8 share one transaction, a reverting verifier unwinds the checkpoint and the core state. The ordering is still structurally "optimistic write, then verify" — a property a same-tx redesign must preserve.

### 3.4 Absence of a challenge / contestation window

A grep for `challenge|contest|dispute|Challeng|Contest|Dispute` across `packages/protocol/contracts/layer1/core` returns **no matches**. There is no challenge period, no proof-contestation game and no re-org of finalized proposals. The only economic sanction is the liveness bond (§5). `IProofVerifier.sol:15` mentions "prover-killer proposals" only as a comment describing what `_proposalAge` *could* be used for; no implementation in this tree uses it (both `SP1Verifier.verifyProof` and `Risc0Verifier.verifyProof` discard it — `SP1Verifier.sol:51`, `Risc0Verifier.sol:50`).

---
## 4. Codec and encoding

### 4.1 `Proposal` struct — exact field order (`IInbox.sol:60-79`)

| # | Type | Name |
| --- | --- | --- |
| 1 | `uint48` | `id` |
| 2 | `uint48` | `timestamp` |
| 3 | `uint48` | `endOfSubmissionWindowTimestamp` |
| 4 | `address` | `proposer` |
| 5 | `bytes32` | `parentProposalHash` |
| 6 | `uint48` | `originBlockNumber` |
| 7 | `bytes32` | `originBlockHash` |
| 8 | `uint8` | `basefeeSharingPctg` |
| 9 | `DerivationSource[]` | `sources` |

`DerivationSource` (`IInbox.sol:52-57`): `bool isForcedInclusion`; `LibBlobs.BlobSlice blobSlice`. `BlobSlice` (`LibBlobs.sol:21-28`): `bytes32[] blobHashes`; `uint24 offset`; `uint48 timestamp`.

Proposal hash — **no domain separator** (`LibHashOptimized.sol:24-27`):

```solidity
function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
    return keccak256(abi.encode(_proposal));
}
```

### 4.2 `Transition` and `Commitment` (the proof public input)

`Transition` (`IInbox.sol:112-119`): `address proposer`; `uint48 timestamp`; `bytes32 blockHash`. `Commitment` (`IInbox.sol:122-138`), in order:

| # | Type | Name |
| --- | --- | --- |
| 1 | `uint48` | `firstProposalId` |
| 2 | `bytes32` | `firstProposalParentBlockHash` |
| 3 | `bytes32` | `lastProposalHash` |
| 4 | `address` | `actualProver` |
| 5 | `uint48` | `endBlockNumber` |
| 6 | `bytes32` | `endStateRoot` |
| 7 | `Transition[]` | `transitions` |

### 4.3 Commitment hash — hand-built, `abi.encode`-equivalent (`LibHashOptimized.sol:32-84`)

The comment at `LibHashOptimized.sol:37-51` documents the word layout reproduced by the Solady path:

- word 0 = `0x20` (offset to the struct)
- word 1 = `firstProposalId`, word 2 = `firstProposalParentBlockHash`, word 3 = `lastProposalHash`, word 4 = `actualProver` (left-padded uint160), word 5 = `endBlockNumber`, word 6 = `endStateRoot`, word 7 = `0xe0`
- word 8 = transitions length, then 3 words per transition (`proposer`, `timestamp`, `blockHash`)

Implementation: `EfficientHashLib.malloc(9 + len*3)` (`:52-54`) and `EfficientHashLib.hash(buffer)` (`:80`). There is **no domain separator** — the hash is byte-identical to `keccak256(abi.encode(commitment))`.

### 4.4 Wire encoding of the two inputs

`ProposeInput` — fixed **15 bytes** (`LibCodec.sol:17-29`): `deadline uint48 (6)` | `blobStartIndex uint16 (2)` | `numBlobs uint16 (2)` | `offset uint24 (3)` | `numForcedInclusions uint16 (2)`.

`ProveInput` (`LibCodec.sol:50-73`, size at `:105-121`): fixed **130 bytes** + `58 * transitions.length`:

| Bytes | Field |
| --- | --- |
| 6 | `firstProposalId` |
| 32 | `firstProposalParentBlockHash` |
| 32 | `lastProposalHash` |
| 20 | `actualProver` |
| 6 | `endBlockNumber` |
| 32 | `endStateRoot` |
| 2 | `transitions.length` (bounded by `P.checkArrayLength`, `:68`) |
| 58 × N | transitions: `address (20)` + `uint48 (6)` + `bytes32 (32)` |

`LibTransitionCodec.TRANSITION_SIZE = 58` — `LibTransitionCodec.sol:11`; encode/decode at `:13-34`.

### 4.5 Domain separation that does exist

Only the verifier public input is domain-separated (`LibPublicInput.sol:18-36`):

```solidity
return EfficientHashLib.hash(
    bytes32("VERIFY_PROOF"),
    bytes32(uint256(_chainId)),
    bytes32(uint256(uint160(_verifierContract))),
    _aggregatedProvingHash,
    bytes32(uint256(uint160(_proofSigner)))
);
```

`_aggregatedProvingHash` is the `hashCommitment` value handed to `verifyProof` by `Inbox.sol:396`. ZK aggregation layering (`LibPublicInput.sol:43-52`): `hashZKAggregationPublicInputs = EfficientHashLib.hash(blockProvingProgram, aggregatedProvingHash)`. Risc0 wraps it again: `journalDigest = sha256(abi.encodePacked(r0AggregationPublicInput))` (`Risc0Verifier.sol:74`). Bridge messages use a separate prefix: `keccak256(abi.encode("TAIKO_MESSAGE", _message))` (`Bridge.sol:536-539`). Signals use `keccak256(abi.encodePacked("SIGNAL", chainId, app, signal))` (`SignalService.sol:160-171`).

---
## 5. Bonds, contestation and forced inclusion

### 5.1 Bond ledger (`LibBonds.sol`, `IBondManager.sol`)

- `uint256 internal constant GWEI_UNIT = 1 gwei;` — `LibBonds.sol:18`. All bond amounts are **gwei-denominated `uint64`** and converted to 18-decimal token units at the ERC20 boundary (`LibBonds.sol:202-205`).
- `struct Bond { uint64 balance; uint48 withdrawalRequestedAt; }` — `IBondManager.sol:13-19`. `withdrawalRequestedAt == 0` = active.
- `deposit` credits and optionally cancels a pending withdrawal (`LibBonds.sol:35-54`); `depositTo` does not cancel it (`Inbox.sol:408-410`).
- `withdraw` bypasses the `_minBond` floor only once `block.timestamp >= withdrawalRequestedAt + withdrawalDelay` (`LibBonds.sol:76-81`); otherwise `require(balance - amount >= _minBond, MustMaintainMinBond())`.
- `hasSufficientBond` = `balance >= _minBond && withdrawalRequestedAt == 0` (`LibBonds.sol:130-141`).
- Liveness slash: `settleLivenessBond` debits best-effort and credits **half** to the actual prover; the other half is only removed from the ledger (`LibBonds.sol:143-170`): `payeeAmount = debited / 2; slashedAmount = debited - payeeAmount;` (`:161-162`). No ERC20 burn call exists; the tokens stay in the Inbox.
- Deadline (`Inbox.sol:729-744`): `livenessWindowDeadline = max(transitions[offset].timestamp + _provingWindow, _coreState.lastFinalizedTimestamp + _maxProofSubmissionDelay)` (`:731-733`); on-time (`block.timestamp <= deadline`) returns without settlement (`:736-738`).
- **Bond settlement is disabled whenever the prover whitelist is enabled** — `if (!isWhitelistEnabled) { _processLivenessBond(...) }` (`Inbox.sol:356-359`).

### 5.2 Numeric constants

Protocol-level constants:

| Name | Value | Source |
| --- | --- | --- |
| `MAX_FORCED_INCLUSIONS_PER_PROPOSAL` | `10` (comment: "Must be < 12") | `Inbox.sol:65` (`:62-64`) |
| `LibBonds.GWEI_UNIT` | `1 gwei` | `LibBonds.sol:18` |
| `LibTransitionCodec.TRANSITION_SIZE` | `58` bytes | `LibTransitionCodec.sol:11` |
| `LibInboxSetup.ACTIVATION_WINDOW` | `2 hours` | `LibInboxSetup.sol:18` |
| `LibInboxSetup.MIN_RING_BUFFER_SIZE` | `2` | `LibInboxSetup.sol:20` |
| `Anchor.GOLDEN_TOUCH_ADDRESS` | `0x0000777735367b36bC9B61C50022d9D0700dB4Ec` | `Anchor.sol:37` |
| `Anchor.ANCHOR_GAS_LIMIT` | `1_000_000` | `Anchor.sol:40` |
| `SignalService.VERSION` | `1` | `SignalService.sol:52` |
| `Bridge.GAS_RESERVE` | `800_000` | `Bridge.sol:44` |
| `Bridge.GAS_OVERHEAD` | `120_000` | `Bridge.sol:49` |
| `Bridge.RELAYER_MAX_PROOF_BYTES` | `200_000` | `Bridge.sol:52` |
| `Bridge._GAS_REFUND_PER_CACHE_OPERATION` | `20_000` | `Bridge.sol:55` |
| `Bridge._SEND_ETHER_GAS_LIMIT` | `135_000` | `Bridge.sol:95` |
| `Bridge._PLACEHOLDER` | `type(uint256).max` | `Bridge.sol:98` |
| `Bridge._CTX_SLOT` | `0xe4ece82196de19aabe639620d7f716c433d1348f96ce727c9989a982dbadc2b9` | `Bridge.sol:102-103` |
| `ERC20Vault.MIN_MIGRATION_DELAY` | `90 days` | `ERC20Vault.sol:29` |
| `ERC20Vault.PERMIT2` | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | `ERC20Vault.sol:35` |
| `QuotaManager.UNLIMITED_QUOTA` | `type(uint256).max` | `QuotaManager.sol:24` |
| `SgxVerifier.INSTANCE_EXPIRY` | `90 days` | `SgxVerifier.sol:50` |
| `SgxVerifier.SGX_FORBIDDEN_ATTRIBUTE_MASK` | `0x32000000000000000000000000000000` | `SgxVerifier.sol:62-63` |
| `SgxVerifier.SGX_FLAGS_DEBUG` | `0x02` | `SgxVerifier.sol:67` |
| `SgxVerifier` quote constants: `SGX_QUOTE_VERSION`, `SGX_QUOTE_BODY_TYPE`, `HEADER_LENGTH`, `ENCLAVE_REPORT_LENGTH` | `3`, `1`, `48`, `384` | `SgxVerifier.sol:79,77,81,83` |
| `SgxVerifier` proof-length check | `_proof.length == 89` (4 id + 20 addr + 65 sig) | `SgxVerifier.sol:467` |
| `PreconfWhitelist.OPERATOR_CHANGE_DELAY` | `2` epochs | `PreconfWhitelist.sol:26` |
| `PreconfWhitelist.RANDOMNESS_DELAY` | `2` epochs | `PreconfWhitelist.sol:30` |
| `LibPreconfConstants`: `SECONDS_IN_SLOT`, `SECONDS_IN_EPOCH`, `TWO_EPOCHS`, `DISPUTE_PERIOD`, `RANDOMNESS_DELAY_EPOCHS` | `12`, `SECONDS_IN_SLOT * 32` (=384), `2 * SECONDS_IN_EPOCH` (=768), `2 * SECONDS_IN_EPOCH` (=768), `2` | `LibPreconfConstants.sol:19,20,21,22,23` |
| `LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT` | `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` | `LibPreconfConstants.sol:11-12` |
| `TaikoToken` initial mint | `1_000_000_000 ether` | `TaikoToken.sol:41` |
| L2 Hoodi chain ID | `167013` | `LibL2HoodiAddrs.sol:5` |

**Mainnet deployment configuration (`MainnetInbox.sol`)** — the live values:

| Config field | Value | Line |
| --- | --- | --- |
| `_RING_BUFFER_SIZE` | `21_600` (`(3 days × 86_400) / 12`) | `:18` |
| `minBond` | `0` (`// During prover whitelist, bonds are not necessary`) | `:37` |
| `livenessBond` | `0` | `:38` |
| `withdrawalDelay` | `1 weeks` | `:39` |
| `provingWindow` | `4 hours` | `:40` |
| `permissionlessProvingDelay` | `5 days` | `:42` |
| `maxProofSubmissionDelay` | `3 minutes` | `:43` |
| `basefeeSharingPctg` | `100` | `:46` |
| `forcedInclusionDelay` | `576 seconds` | `:48` |
| `forcedInclusionFeeInGwei` | `1_000_000` (= 0.001 ETH) | `:49` |
| `forcedInclusionFeeDoubleThreshold` | `50` | `:50` |
| `permissionlessInclusionMultiplier` | `160` (comment: `160 * 576s = 92_160s (~25.6 hours)`) | `:52` |

**Vestigial parameters:** `_permissionlessProvingDelay` (`Inbox.sol:99`) and `_permissionlessInclusionMultiplier` (`Inbox.sol:121`) are assigned and echoed by `getConfig` (`:539,546`) but never read by any logic branch (grep over `contracts/` finds no other reference). Likewise `LibForcedInclusion.isOldestForcedInclusionDue` (`LibForcedInclusion.sol:152-170`) has **no call site** — `Inbox._consumeForcedInclusions` recomputes dueness inline (`Inbox.sol:653-661`).

### 5.3 Forced inclusion mechanics

- **Enqueue** — `saveForcedInclusion` (`Inbox.sol:431-443` → `LibForcedInclusion.sol:42-72`):
  - reverts with `IncorrectProposalCount` if `_proposalHashes[1] == 0` (`Inbox.sol:432-433`) — at least one non-activation proposal must exist first;
  - exactly one blob: `require(blobSlice.blobHashes.length == 1, OnlySingleBlobAllowed())` (`LibForcedInclusion.sol:52`);
  - fee formula: `fee = baseFee * (threshold + numPending) / threshold`, capped at `type(uint64).max` (`:89-93`);
  - `require(msg.value >= requiredFee, InsufficientFee())` (`:57`); excess refunded via `sendEtherAndVerify` (`Inbox.sol:440-442`);
  - FIFO append `$.queue[$.tail++]` (`:64`).
- **Dequeue / dueness** — `_consumeForcedInclusions` (`Inbox.sol:637-675`): an inclusion is due when `block.timestamp >= inclusion.blobSlice.timestamp + _forcedInclusionDelay` (`:656`); the proposer must request at least `dueToProcess` (`:662-664`, error `UnprocessedForcedInclusionIsDue`); capped at `MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10` (`:667`). Accumulated fees are forwarded to the proposer (`_feeRecipient.sendEtherAndVerify(totalFees * 1 gwei)`, `:710`).
- Forced-inclusion sources come first; the normal blob source is the **last** array element (`result.sources[result.sources.length - 1] = DerivationSource(false, ...)`, `Inbox.sol:598-599`).
- **Admin escape hatch**: `init3()` sets `$.head = tail`, permanently discarding all queued entries; fees are **not** refunded (`Inbox.sol:246-258`).

---
## 6. Addresses

Canonical names come from three places: `LibL1Addrs.sol` (mainnet L1 compile-time constants), `LibL2Addrs.sol` / `LibL2HoodiAddrs.sol` (L2), and the hand-maintained logs under `packages/protocol/deployments/`.

### 6.1 Ethereum mainnet (L1)

| Contract | Proxy address | Impl address | Source |
| --- | --- | --- | --- |
| SignalService | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0x1A06832992785766a105838C95c1E13a0045AC85` | `deployments/mainnet-contract-logs-L1.md:29-30`; `LibL1Addrs.sol:45` |
| Bridge | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | `0x1c94D798CFA08F396E5BA9F81697289c53273381` | `mainnet-contract-logs-L1.md:48-49`; `LibL1Addrs.sol:43` |
| ERC20Vault | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` | `mainnet-contract-logs-L1.md:87-88`; `LibL1Addrs.sol:46` |
| ERC721Vault | `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa` | `0xA4C5c20aB33C96B1c281Dca37D03E23609274C49` | `mainnet-contract-logs-L1.md:104-105`; `LibL1Addrs.sol:47` |
| ERC1155Vault | `0xaf145913EA4a56BE22E120ED9C24589659881702` | `0x838ed469db456b67EB3b0B74D759Be4DA999b9c8` | `mainnet-contract-logs-L1.md:120-121`; `LibL1Addrs.sol:48` |
| Inbox (Shasta) | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` | `mainnet-contract-logs-L1.md:215-216`; `LibL1Addrs.sol:37` |
| Inbox (legacy Pacaya) | `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a` | — | `LibL1Addrs.sol:36` |
| TaikoToken (TKO) | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | `0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106` | `mainnet-contract-logs-L1.md:12-13`; `LibL1Addrs.sol:73`; `TaikoToken.sol:12-13` |
| ProverWhitelist | `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | `0xebb393746A4Eee84Ad14EDFf3764c3F839D1034b` | `mainnet-contract-logs-L1.md:350-351`; `LibL1Addrs.sol:39` |
| PreconfWhitelist | `0xFD019460881e6EeC632258222393d5821029b2ac` | `0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149` | `mainnet-contract-logs-L1.md:334-335`; `LibL1Addrs.sol:38` |
| SharedResolver | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `0xFca4F0Ab7B95EEf2e3A60EF2Bc0c42DdAA62E66D` | `mainnet-contract-logs-L1.md:154-155`; `LibL1Addrs.sol:40` |
| QuotaManager (immutable) | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | n/a | `mainnet-contract-logs-L1.md:71`; `LibL1Addrs.sol:41` |
| ZkRequiredVerifier (active) | `0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec` | same | `mainnet-contract-logs-L1.md:321,330`; `LibL1Addrs.sol:56` |
| Risc0Verifier | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | same | `mainnet-contract-logs-L1.md:293`; `LibL1Addrs.sol:57` |
| SP1Verifier | `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | same | `mainnet-contract-logs-L1.md:307`; `LibL1Addrs.sol:59` |
| SecureSgxVerifier (geth) | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` | same | `mainnet-contract-logs-L1.md:282`; `LibL1Addrs.sol:61` |
| SecureSgxVerifier (reth) | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | same | `mainnet-contract-logs-L1.md:271`; `LibL1Addrs.sol:62` |
| MainnetVerifier (deprecated) | `0x71808449A6217898d602c1a392D95b931Ac5d878` (live instance) | same | `MainnetVerifier.sol:12`; `mainnet-contract-logs-L1.md:329` |
| MainnetDAOController | `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | `0x4347df63bdC82b8835fC9FF47bC5a71a12cC0f06` | `mainnet-contract-logs-L1.md:361-363` |
| ForcedInclusionStore (legacy) | `0x05d88855361808fA1d7fc28084Ef3fCa191c4e03` | — | `LibL1Addrs.sol:33` |

Recorded mainnet owners: `controller.taiko.eth` for TaikoToken/SignalService/Bridge/Inbox/PreconfWhitelist (`mainnet-contract-logs-L1.md:15,31,50,336`); `admin.taiko.eth` = `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` for QuotaManager (`:72`; `LibL1Addrs.sol:67`). The Inbox was upgraded to the Unzen implementation by Proposal0019 and `init3()` was called in the same bundle (`mainnet-contract-logs-L1.md:222-223`).

### 6.2 Taiko mainnet (L2)

| Contract | Address | Impl | Source |
| --- | --- | --- | --- |
| Anchor | `0x1670000000000000000000000000000000010001` | `0x7e83Af941FDcf90EB44ED7dc8754a201B156E0BA` | `mainnet-contract-logs-L2.md:123-124`; `LibL2Addrs.sol:9` |
| Bridge | `0x1670000000000000000000000000000000000001` | `0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83` | `mainnet-contract-logs-L2.md:48-49`; `LibL2Addrs.sol:11` |
| SignalService | `0x1670000000000000000000000000000000000005` | `0x18B27428cce679DFf84D09D6b07DF1E9EBb6fE28` | `mainnet-contract-logs-L2.md:108-109`; `LibL2Addrs.sol:14` |
| ERC20Vault | `0x1670000000000000000000000000000000000002` | `0xb96AbB41b01E3ad519D00E80355a1c3801910F62` | `mainnet-contract-logs-L2.md:67-68`; `LibL2Addrs.sol:15` |
| ERC721Vault | `0x1670000000000000000000000000000000000003` | `0xd532f20a4751156C566Da7745db95E7f80145B36` | `mainnet-contract-logs-L2.md:82-83`; `LibL2Addrs.sol:16` |
| ERC1155Vault | `0x1670000000000000000000000000000000000004` | `0xBBBC4ad39488b990E095042fa6c59A90d3817846` | `mainnet-contract-logs-L2.md:95-96`; `LibL2Addrs.sol:17` |
| BridgedTaikoToken | `0xA9d23408b9bA935c230493c40C73824Df71A0975` | `0x71583f1Ba66F292f6C626f37e25c438b152DD917` | `mainnet-contract-logs-L2.md:139-140`; `LibL2Addrs.sol:13` |
| SharedResolver | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | — | `LibL2Addrs.sol:10` |
| DelegateController | `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` | `0x6900f893Fb1dcf2868c7799Ac9a2dAf1c046c6bF` | `mainnet-contract-logs-L2.md:174-175`; `LibL2Addrs.sol:7` |
| **BondManager** | **not found** | **not found** | no implementation file and no deployment entry; only the generated `layer2/core/BondManager_Layout.sol` |

### 6.3 Hoodi — L1

| Contract | Address | Impl | Source |
| --- | --- | --- | --- |
| SignalService | `0x4c70b7F5E153D497faFa0476575903F9299ed811` | `0x2D0DF6900fBe181bE5246268Aafd1ecb6c4C8B35` | `deployments/taiko-hoodi-contract-logs.md:27-28` |
| Bridge | `0x6a4cf607DaC2C4784B7D934Bcb3AD7F2ED18Ed80` | `0x865acC241162575f887a0f926436a75a34ef5291` | `taiko-hoodi-contract-logs.md:37-38` |
| ERC20Vault | `0x0857cd029937E7a119e492434c71CB9a9Bb59aB0` | `0x4E385c0D2D285a790Af70786ED138E6e667719ea` | `taiko-hoodi-contract-logs.md:46-47` |
| ERC721Vault | `0x4876e7993dD40C22526c8B01F2D52AD8FdbdF768` | `0xd2751F9E5374a027E99E7a161d00cf220AD06312` | `taiko-hoodi-contract-logs.md:55-56` |
| ERC1155Vault | `0x81Ff6CcE1e5cFd6ebE83922F5A9608d1752C92c6` | `0x2288051cac7d137De4e571f45be6cBeF165D4293` | `taiko-hoodi-contract-logs.md:63-64` |
| Inbox | `0xeF4bB7A442Bd68150A3aa61A6a097B86b91700BF` | `0x15B304bab39CD34e043136328E48A14AdB9ea46e` | `taiko-hoodi-contract-logs.md:90-91` |
| TaikoToken | `0xf3b83e226202ECf7E7bb2419a4C6e3eC99e963DA` | `0x791a16ed5D4728CAEC441DDDa38f1A2991349b6c` | `taiko-hoodi-contract-logs.md:19-20` |
| ProverWhitelist | `0xa9a84b6667A2c60BFdE8c239918d0d9a11c77E89` | `0x8bc913253BbB2EcCAf1F74C35cdeb4F5Eebe3785` | `taiko-hoodi-contract-logs.md:110-111` |
| PreconfWhitelist | `0x8B969Fcf37122bC5eCB4E0e5Ad65CEEC3f1393ba` | `0xeB614BE0Fe964A26B71D8CC02F9D7876352d7d15` | `taiko-hoodi-contract-logs.md:101-102` |
| SharedResolver | `0x7bbacc9FFd29442DF3173b7685560fCE96E01b62` | `0xB2eAdD09D28bB9b21a3b31d6106d547989A333A0` | `taiko-hoodi-contract-logs.md:11-12` |

Hoodi L1 owner for all of the above: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190` (`taiko-hoodi-contract-logs.md:13,21,29,39,48,57,65,92`). There is **no LibL1HoodiAddrs-style Solidity address library** — "not found".

### 6.4 Hoodi — L2 (chain ID 167013)

| Contract | Address | Impl | Source |
| --- | --- | --- | --- |
| Anchor | `0x1670130000000000000000000000000000010001` | `0x70A65dDf64960b9901Df488825c1CBFBc9AE9685` | `taiko-hoodi-contract-logs.md:182-183`; `LibL2HoodiAddrs.sol:9` |
| Bridge | `0x1670130000000000000000000000000000000001` | `0x0B5B11A78aB89F1465c72D959e630138fD416047` | `taiko-hoodi-contract-logs.md:128-129`; `LibL2HoodiAddrs.sol:10` |
| ERC20Vault | `0x1670130000000000000000000000000000000002` | `0x9F147D8E70685E19119c33Bda7c9FBF59eCb75F3` | `taiko-hoodi-contract-logs.md:138-139`; `LibL2HoodiAddrs.sol:11` |
| ERC721Vault | `0x1670130000000000000000000000000000000003` | `0x0167013000000000000000000000000000000003` | `taiko-hoodi-contract-logs.md:148-149` |
| ERC1155Vault | `0x1670130000000000000000000000000000000004` | `0x0167013000000000000000000000000000000004` | `taiko-hoodi-contract-logs.md:156-157` |
| SignalService | `0x1670130000000000000000000000000000000005` | `0x22efa1915629712320C60E90E44CD412F0Ee98FE` | `taiko-hoodi-contract-logs.md:164-165`; `LibL2HoodiAddrs.sol:8` |
| SharedResolver | `0x1670130000000000000000000000000000000006` | `0x0167013000000000000000000000000000000006` | `taiko-hoodi-contract-logs.md:174-175` |
| DelegateController | `0xF7176c3aC622be8bab1B839b113230396E6877ab` | `0xEe9E92E8C237B22c8bddA6FBfeFe941876d21887` | `taiko-hoodi-contract-logs.md:122-123` |
| **BondManager** | **not found** | **not found** | — |

`LibL2HoodiAddrs.sol` declares only 4 of these (SignalService, Anchor, Bridge, ERC20Vault) — `LibL2HoodiAddrs.sol:8-11`.

### 6.5 Upgradeability and the fork-router pattern

**Upgradeable (ERC1967/UUPS proxy, `EssentialContract`):** every shared contract (SignalService, Bridge, all three vaults), Inbox, Anchor, TaikoToken, ProverWhitelist, PreconfWhitelist, SharedResolver, and the legacy QuotaManager proxy (the current QuotaManager is immutable — `mainnet-contract-logs-L1.md:71`). `EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable` (`shared/common/EssentialContract.sol:10`); `_authorizeUpgrade` is `onlyOwner` (`:207`).

**Not upgradeable:** the ZK/SGX verifiers. `SP1Verifier` and `Risc0Verifier` use plain OZ `Ownable2Step` (`SP1Verifier.sol:11`, `Risc0Verifier.sol:11`) with ordinary mappings plus a `uint256[49] __gap`. `SgxVerifier` / `SecureSgxVerifier` are likewise non-proxy and are replaced by redeployment (Proposal0017 replaced both SGX verifiers — `mainnet-contract-logs-L1.md:274,285`).

**ForkRouter** — `packages/protocol/contracts/shared/fork-router/ForkRouter.sol:22-67`:

```solidity
// ForkRouter.sol:40-64
fallback() external payable virtual { _fallback(); }
...
function _fallback() internal virtual {
    address fork = shouldRouteToOldFork(msg.sig) ? oldFork : newFork;
    assembly {
        calldatacopy(0, 0, calldatasize())
        let result := delegatecall(gas(), fork, 0, calldatasize(), 0, 0)
        ...
    }
}
```

- Immutable `oldFork` / `newFork` (`:23-24`), both non-zero and distinct (`:30-32`).
- Routing is per-selector via `shouldRouteToOldFork(bytes4)` (`:50`). The fork pair is **not** switchable at runtime: changing implementations requires a new router deployment, while the router's own implementation can be upgraded through `_authorizeUpgrade` — `onlyOwner` (`:66`).
- Storage warning (`:18-20`): "This contract uses 151 slots [0..150]. Routed contracts should reserve 151 slots to avoid collisions." `ForkRouter_Layout.sol:10-16` confirms it occupies only slots 0-150.
- `SignalService.sol:14-16` states the contract "will be initially deployed behind the fork router, which uses 151 slots [0..150]" and that its layout is "compatible and aligned with both the Pacaya version and the fork router (e.g. the owner slot is in the same position)".
- **However, no concrete ForkRouter subclass exists in this tree.** A grep for `is ForkRouter`, `shouldRouteToOldFork` and `ForkRouter(` across `contracts/`, `script/` and `test/` matches only the abstract base (`ForkRouter.sol:50,53`). The generated layout docs `SignalServiceForkRouter_Layout.sol` and `AnchorForkRouter_Layout.sol` exist, but the corresponding contracts do not. See §10.

---
## 7. Storage-layout compatibility for the D3 shared contracts

### 7.1 What the `*_Layout.sol` files are

Each is auto-generated by `gen-layouts.sh` and carries the header "This file is auto-generated by gen-layouts.sh. DO NOT EDIT MANUALLY." plus a `// DO NOT DELETE` import directive in the contract that consumes it (e.g. `SignalService.sol:9`, `Bridge_Layout.sol:6`, `ERC20Vault_Layout.sol:6`, `Anchor.sol:10`). They are documentation, not code: each is a block comment listing `name | type | Slot | Offset | Bytes`, regenerated from the compiler, so they record the real slot assignment.

### 7.2 The common reserved prefix (slots 0-250)

| Slot(s) | Owner of the slot | Source |
| --- | --- | --- |
| 0 | `_initialized` (uint8) + `_initializing` (bool) | `SignalService_Layout.sol:10-11` |
| 1-50 | `uint256[50] __gap` (Initializable) | `SignalService_Layout.sol:12` |
| 51 | `_owner` | `SignalService_Layout.sol:13` |
| 52-100 | `uint256[49] __gap` | `SignalService_Layout.sol:14` |
| 101 | `_pendingOwner` | `SignalService_Layout.sol:15` |
| 102-150 | `uint256[49] __gap` | `SignalService_Layout.sol:16` |
| 151-200 | `uint256[50] __gapFromOldAddressResolver` | `SignalService_Layout.sol:17` |
| 201 | `__reentry` (uint8) + `__paused` (uint8) | `SignalService_Layout.sol:18-19` |
| 202-250 | `uint256[49] __gap` | `SignalService_Layout.sol:20` |

Slots **0-150** are exactly the ForkRouter's own footprint (`ForkRouter.sol:18-20`); slots **151-250** are the extra `EssentialContract` reservation. The source marks slot 201 as vestigial for the reentry lock: "`__reentry` is deprecated: the reentry lock lives in transient storage (`_REENTRY_SLOT`); the storage slot is retained only for layout compatibility" (`EssentialContract.sol:31-34`).

### 7.3 Per-contract last-used slot, gap size, and the upgrade constraint

| Contract | Own storage starts | Last used slot(s) | Reserved after | Layout file |
| --- | --- | --- | --- | --- |
| Inbox / MainnetInbox | 251 | 257 (`_bondStorage`) | `uint256[43] __gap` (258-300) | `MainnetInbox_Layout.sol:21-26` |
| SignalService | 251 | 254 (`_checkpoints`) | `uint256[46] __gap` (255-300) | `SignalService_Layout.sol:21-24` |
| Bridge | 251 | 256 (`__reserved3`) | `uint256[44] __gap` (257-300) | `Bridge_Layout.sol:21-27` |
| ERC20Vault | 301 (251-300 is a `uint256[50] __gap` from BaseVault) | 304 (`lastMigrationStart`) | `uint256[46] __gap` (305-350) | `ERC20Vault_Layout.sol:21-26` |
| ERC721Vault | 301 | 302 (`canonicalToBridged`) | `uint256[48] __gap` (303-350) + `uint256[50]` (351-400) | `ERC721Vault_Layout.sol:21-25` |
| ERC1155Vault | 301 | 302 | `uint256[48]` + three `uint256[50]` gaps (303-350, 351-400, 401-450, 451-500) | `ERC1155Vault_Layout.sol:21-27` |
| Anchor | 251 | 256 (`_blockState`) | `uint256[43] __gap` (258-300) | `Anchor_Layout.sol:21-25` |
| ProverWhitelist | 251 | 252 (`proverCount`) | `uint256[48] __gap` (253-300) | `ProverWhitelist_Layout.sol:21-23` |
| PreconfWhitelist | 251 | 254 (`ejecters`) | `uint256[45] __gap` (255-299) | `PreconfWhitelist_Layout.sol:21-29` |
| BondManager (layout doc only) | 251 | 252 (`processedSignals`) | `uint256[44] __gap` (253-296) | `BondManager_Layout.sol:21-23` |
| AnchorForkRouter | — | 101 (`_pendingOwner`) | — (only 0-150 shown) | `AnchorForkRouter_Layout.sol:10-16` |
| SignalServiceForkRouter | — | 101 | — | `SignalServiceForkRouter_Layout.sol:10-16` |
| ForkRouter | — | 101 | — | `ForkRouter_Layout.sol:10-16` |

### 7.4 The exact constraint an upgrade must respect

Because every proxy delegatecalls into the implementation, the implementation's slot assignment **is** the proxy's storage. Therefore:

1. **Never reorder, retype, resize or delete an existing slot.** New state variables may only be appended after the concrete contract's last used slot, consuming the trailing `__gap` and shrinking it by exactly the number of slots taken (e.g. Inbox's `uint256[43] __gap` at slot 258 — `MainnetInbox_Layout.sol:26` — so the first new Inbox variable must land at slot 258).
2. **Deprecated slots are frozen, not free.** They were deliberately kept to preserve layout and must not be reused: `Anchor._pacayaSlots` (`Anchor.sol:59-63`), `Anchor._lastProposalId` (`:65-66`), `SignalService._slotsUsedByPacaya` (`SignalService.sol:58-61`), `Bridge.__reserved1/__ctx/__reserved2/__reserved3` (`Bridge.sol:116-133`; `init2()` zeroes them for future reuse, `:197-202`), `PreconfWhitelist._deprecatedOperatorChangeDelay/_deprecatedRandomnessDelay/_deprecatedHavingPerfectOperators` (`PreconfWhitelist.sol:55-60`), `EssentialContract.__reentry` (`EssentialContract.sol:31-33`).
3. **The 151-slot frozen prefix (0-150) must be identical** for anything routed through a fork router, since the router itself occupies that range (`ForkRouter.sol:18-20`).
4. The repo's operational rule is `pnpm layout` before and after every change (`packages/protocol/AGENTS.md`, sections "Storage Layout Verification" and "Upgrade Safety Guidelines").

**Implication for D3:** because Inbox, SignalService, Bridge and all three vaults are UUPS proxies whose implementations are swappable by the owner, "keeping the existing shared-contract addresses" is satisfiable by upgrading implementations **only if** the slot assignments above are preserved exactly. Adding new state (per-transition records, a sequencing registry, a proof-commitment record) requires space in the trailing gap of the contract that holds it: Inbox 43 slots, SignalService 46, Bridge 44, ERC20Vault 46, ERC721Vault 98, ERC1155Vault 198, Anchor 43 (each `uint256`; smaller packed types can share a slot).

---
## 8. SignalService + Bridge integration

### 8.1 How a signal is stored

`sendSignal(bytes32)` → `_sendSignal(msg.sender, _signal, _signal)` (`SignalService.sol:107-109`): the value written is the signal itself, at a name-derived slot, via raw `sstore` (`:220-237`):

```solidity
// SignalService.sol:232-235
slot_ = getSignalSlot(uint64(block.chainid), _app, _signal);
assembly {
    sstore(slot_, _value)
}
```

`getSignalSlot = keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal))` (`:160-171`). `isSignalSent` checks the slot is non-zero (`:146-153`, `:247-251`). The slot is a **plain keccak slot**, not a mapping slot of this contract.

### 8.2 How a message's storage proof is anchored — the checkpoint

`SignalService` stores checkpoints in `_checkpoints[VERSION][blockNumber] = CheckpointRecord{blockHash, stateRoot}` (`SignalService.sol:70-73`). Writing is restricted to a single immutable address set at construction — there is **no setter and no upgrade path for it**:

```solidity
// SignalService.sol:35-37
/// @dev Address that can save checkpoints to this contract.
/// @dev This is the inbox on L1 and the anchor on L2.
address internal immutable _authorizedSyncer;
```

```solidity
// SignalService.sol:174-177
function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
    if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();
    if (_checkpoint.stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
    if (_checkpoint.blockHash == bytes32(0)) revert SS_INVALID_CHECKPOINT();
```

**L1 side:** `Inbox.prove()` writes the L2 checkpoint into the L1 SignalService (`Inbox.sol:364-370`, quoted in §3.3), where `_authorizedSyncer == shastaInbox` (`script/layer1/core/DeployShastaContracts.s.sol:130`, `script/layer1/core/DeployProtocolOnL1.s.sol:284-287`).

**L2 side:** the Anchor is the only writer. `Anchor._validateBlock`:

```solidity
// Anchor.sol:182-185
if (_checkpoint.blockNumber > _blockState.anchorBlockNumber) {
    checkpointStore.saveCheckpoint(_checkpoint);
    _blockState.anchorBlockNumber = _checkpoint.blockNumber;
}
```

and the L2 SignalService is constructed with `authorizedSyncer = anchorProxy` (`script/layer2/DeployShastaL2Contracts.s.sol:46-53`; genesis equivalent `test/genesis/GenerateGenesis.g.sol:316`).

### 8.3 How a cross-chain signal is verified

`SignalService._verifySignalReceived` (`SignalService.sol:253-297`):

1. Empty proof → accept only if `_receivedSignals[VERSION][slot]` was set by a prior `proveSignalReceived` (`:266-269`, error `SS_SIGNAL_NOT_RECEIVED`).
2. Otherwise decode `HopProof[]` and require **exactly one hop** (`:271-272`).
3. Require both `accountProof` and `storageProof` non-empty (`:276-278`).
4. `checkpoint = _getCheckpoint(uint48(proof.blockId))` (`:284`) and `require(checkpoint.stateRoot == proof.rootHash)` (`:285-287`) — **this is the anchor linkage**: the queried state root must be the one the Inbox/Anchor previously checkpointed for that block number.
5. `LibTrieProof.verifyMerkleProof(checkpoint.stateRoot, _remoteSignalService, slot, _signal, accountProof, storageProof)` (`:289-296`) — against the remote SignalService's account and the `SIGNAL`-derived storage slot.

`getCheckpoint` reverts `SS_CHECKPOINT_NOT_FOUND` when the stored block hash is zero (`:206-218`).

### 8.4 Bridge

`Bridge` carries the immutable `signalService` (`Bridge.sol:105`) and proves message receipt through it:

```solidity
// Bridge.sol:637-645
try _signalService.proveSignalReceived(
    _chainId, resolve(_chainId, LibNames.B_BRIDGE, false), _signal, _proof
) returns (uint256 numCacheOps) {
    numCacheOps_ = uint32(numCacheOps);
} catch {
    revert B_SIGNAL_NOT_RECEIVED();
}
```

- `processMessage` calls `_proveSignalReceived(signalService, msgHash, _message.srcChainId, _proof)` (`:340-341`).
- `sendMessage` emits and publishes the signal: `signalService.sendSignal(msgHash_)` (`:251-254`).
- Failure/recall signals: `signalForFailedMessage(msgHash) = msgHash ^ bytes32(uint256(Status.FAILED))` i.e. `^ 3` (`:544-546`); sent by `failMessage` (`:463-464`) and by the last retry (`:438-441`); proven by `recallMessage` (`:278-280`) and `isMessageFailed` (`:482-487`).
- Message hash: `keccak256(abi.encode("TAIKO_MESSAGE", _message))` (`:536-539`). `Message` fields in order (`IBridge.sol:24-54`): `uint64 id, uint64 fee, uint32 gasLimit, address from, uint64 srcChainId, address srcOwner, uint64 destChainId, address destOwner, address to, uint256 value, bytes data`. Status enum (`IBridge.sol:9-15`): `NEW, RETRIABLE, DONE, FAILED, RECALLED`.
- The call context now lives in **transient storage** at `_CTX_SLOT` (`Bridge.sol:100-103`, `:659-669`); the storage slots are retained only for layout compatibility (`:125-127`).

### 8.5 Is an anchor-less L2 execution expressible today?

**No.** Three independent facts pin L2 state to the Anchor:

1. The L2 `SignalService` has exactly one checkpoint writer, fixed at construction and required non-zero (`SignalService.sol:37`, `:86-93`, `:174-175`). No setter, no role rotation, no batch/aggregate write path.
2. The Anchor's only state-changing entry point that reaches `saveCheckpoint` is `anchorV4`, hard-gated to a single hardcoded address:

```solidity
// Anchor.sol:36-37, 86-89
/// @notice Golden touch address is the only address that can do the anchor transaction.
address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
...
modifier onlyValidSender() {
    require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
    _;
}
```

```solidity
// Anchor.sol:124-127
function anchorV4(ICheckpointStore.Checkpoint calldata _checkpoint)
    external
    onlyValidSender
    nonReentrant
```

The other external function, `withdraw` (`:145-156`), is `onlyOwner` and never touches the checkpoint store.
3. Every cross-chain read on L2 (Bridge `processMessage`/`recallMessage`/`isMessageReceived`) resolves through `SignalService._verifySignalReceived` → `_getCheckpoint`, which can only be satisfied by a checkpoint the Anchor wrote (`SignalService.sol:284-296`; `Bridge.sol:307-341`, `:472-505`).

The Anchor additionally validates a rolling 255-block ancestor commitment (`Anchor.sol:194-229`) and refuses to change it arbitrarily: `require(_blockState.ancestorsHash == oldAncestorsHash, AncestorsHashMismatch())` (`Anchor.sol:175-179`). So "anchor-less L2 execution" is not a configuration toggle — it is a new code path.

### 8.6 L1 facts that L2 execution depends on today

1. `CoreState.lastFinalizedProposalId`/`lastFinalizedBlockHash` on L1 (Inbox), which define the canonical L2 chain tip.
2. The `Checkpoint{blockNumber, stateRoot, blockHash}` for that tip, written to the L1 SignalService by `prove()` and re-anchored on L2 by `anchorV4`.
3. `VERSION = 1` (`SignalService.sol:52`) — the namespace of both the received-signal cache and the checkpoint mapping; bumping it invalidates all cached proofs and checkpoints simultaneously (`:49-52`).
4. The remote SignalService address `_remoteSignalService` (`SignalService.sol:39-40`), immutable, used as the account whose storage is trie-proven (`:289-296`).
5. Origin/proposal metadata: `Proposal.originBlockNumber`/`originBlockHash` (`IInbox.sol:71-74`) and `basefeeSharingPctg` (`IInbox.sol:75-76`), which the derivation layer consumes from the `Proposed` event.

---
## 9. Verifier policy and privileged roles

### 9.1 The verifier interface

`packages/protocol/contracts/layer1/verifiers/IProofVerifier.sol:18-24`:

```solidity
function verifyProof(
    uint256 _proposalAge,
    bytes32 _commitmentHash,
    bytes calldata _proof
)
    external
    view;
```

Three parameters only: proposal age (0 for multi-proposal batches — `Inbox.sol:394-395`), the aggregated commitment hash, and opaque proof bytes. It is `view` and must **revert** on an invalid proof (`IProofVerifier.sol:9`). Every implementation in the tree is `external view` (`SP1Verifier.sol:55-56`, `Risc0Verifier.sol:54-55`, `SgxVerifier.sol:464-465`, `ComposeVerifier.sol:64-66`).

### 9.2 "Tiers" — not found

A grep for `tier|Tier|TIER` across all of `packages/protocol/contracts` returns **zero matches**. There is no proof-tier enum, no tier threshold, no `ProverWhitelist`-vs-tier coupling. The role "tier" played is filled by `ComposeVerifier.VerifierType` (`ComposeVerifier.sol:13-21`): `NONE, SGX_GETH, TDX_GETH, OP, SGX_RETH, RISC0_RETH, SP1_RETH`. The only numeric "threshold" is the required **count** of sub-proofs inside each concrete composition:

| Composer | Required set | Source |
| --- | --- | --- |
| `ComposeVerifier` base | sub-proof IDs strictly ascending; each sub-verifier non-zero and invoked; final `areVerifiersSufficient` veto | `ComposeVerifier.sol:74-90` |
| `ZkRequiredVerifier` (active mainnet) | exactly 2: SGX_GETH or SGX_RETH, plus RISC0_RETH or SP1_RETH; or RISC0_RETH + SP1_RETH | `ZkRequiredVerifier.sol:37-51` |
| `SgxAndZkVerifier` | exactly 2: SGX_RETH plus RISC0_RETH or SP1_RETH | `SgxAndZkVerifier.sol:31-34` |
| `AnyVerifier` | exactly 1: any of SGX_RETH, RISC0_RETH, SP1_RETH | `AnyVerifier.sol:31-34` |
| `MainnetVerifier` (**DEPRECATED**) | exactly 2: SGX_GETH plus SGX_RETH/RISC0/SP1, or SGX_RETH plus SGX_GETH/RISC0/SP1 | `MainnetVerifier.sol:42-61` |

`MainnetVerifier.sol:8-14` carries an explicit deprecation notice: it "still accepts the SGX-GETH + SGX-RETH (zero ZK) combination that finalized the June 2026 forged proofs. Do not wire into new deployments."

### 9.3 Whitelists and how proving is gated

**`ProverWhitelist`** (`layer1/core/impl/ProverWhitelist.sol`) gates who may call `Inbox.prove`:

```solidity
// Inbox.sol:771-779
function _checkProver(address _addr) private view returns (bool whitelistEnabled_) {
    if (address(_proverWhitelist) == address(0)) return false;
    (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
    if (proverCount == 0) return false;
    require(isWhitelisted, ProverNotWhitelisted());
    return true;
}
```

Called once per `prove()` (`Inbox.sol:337`); its boolean return doubles as the switch that disables bond settlement (`:356-359`). State: `mapping(address => bool) _provers` + `uint256 proverCount` + `uint256[48] __gap` (`ProverWhitelist.sol:24-30`). Mainnet whitelists provers via `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` (`LibL1Addrs.sol:39`); Hoodi records one prover `0x7B399987D24FC5951f3E94A4cb16E87414bF2229` (`taiko-hoodi-contract-logs.md:113-114`).

**`PreconfWhitelist`** (`layer1/preconf/impl/PreconfWhitelist.sol`) is the L1 `IProposerChecker` today: it selects exactly one operator per epoch from the beacon block root and rejects everyone else:

```solidity
// PreconfWhitelist.sol:136-140
address operator = _getOperatorForEpoch(epochStartTimestamp(0));
require(operator != address(0), InvalidProposer());
require(operator == _proposer, InvalidProposer());
// Slashing is not enabled for whitelisted preconfers, so we return 0
endOfSubmissionWindowTimestamp_ = 0;
```

Operator selection uses `_getRandomNumber(randomnessTs)` = the EIP-4788 beacon block root at `epochStart - RANDOMNESS_DELAY * SECONDS_IN_EPOCH` (`:275-314`; beacon root contract `LibPreconfConstants.sol:11-12`, read in `LibPreconfUtils.sol:46`). `IProposerChecker.checkProposer` is declared **non-view** (`IProposerChecker.sol:16-21`), so the configured checker may be state-changing.

**URC integration: not found.** `packages/protocol/package.json:63` pins `urc: github:eth-fabric/urc#main` and `foundry.toml:41` adds the remapping `eth-fabric/urc -> node_modules/urc/src/`; `node_modules/urc/src/` contains `IRegistry.sol`, `ISlasher.sol`, `Registry.sol`. But a grep for `eth-fabric/urc`, `urc/src`, `IRegistry`, `ISlasher` under `contracts/`, `script/` and `test/` returns **no imports**. The dependency is present but not wired into any Solidity contract at this commit.

### 9.4 Every privileged role / owner in the reviewed contracts

`owner` below means the OZ `Ownable2StepUpgradeable` owner (`EssentialContract.sol:10`), transferable via `transferOwnership`/`acceptOwnership` on any contract that inherits it.

| Contract | Role / holder | Exercising function (file:line) |
| --- | --- | --- |
| `Inbox` | owner | `activate` (`Inbox.sol:188`), `init2` (`:217`), `init3` (`:253`), `init` (`:181`), `upgradeToAndCall` (`EssentialContract.sol:207`), `pause/unpause` (`:150,159` — *no effect on Inbox logic*) |
| `Inbox` | — no other role | all economic/protocol parameters are constructor immutables (`Inbox.sol:153-173`), changeable only by upgrading the implementation |
| `Bridge` | owner | `init` (`Bridge.sol:192`), `init2` (`:197`), `init3` (`:208`), pause/unpause, upgrade |
| `Bridge` | `pauser` (immutable) | `_authorizePause` (`Bridge.sol:556`) → pause/unpause; **and** `receive()` accepts Ether only from it (`:186-188`) |
| `SignalService` | owner | `init` (`SignalService.sol:97`), pause/unpause via `_authorizePause` (`:201`), upgrade |
| `SignalService` | `pauser` (immutable) | pause/unpause (`SignalService.sol:201`) |
| `SignalService` | `_authorizedSyncer` (immutable; inbox on L1, anchor on L2) | `saveCheckpoint` (`SignalService.sol:174-175`) — the sole checkpoint writer |
| `SignalService` | `_remoteSignalService` (immutable) | the trie-proven account in `_verifySignalReceived` (`:289-296`) |
| `Anchor` | owner | `init` (`Anchor.sol:113`), `withdraw` (`:145-156`), pause/unpause, upgrade |
| `Anchor` | `GOLDEN_TOUCH_ADDRESS` (hardcoded constant) | `anchorV4` (`Anchor.sol:124-127`) — the only path to `saveCheckpoint` on L2 |
| `ERC20Vault` | owner | `changeBridgedToken` (`ERC20Vault.sol:200-207`, `onlyOwner`), `init` (`:192`), pause/unpause, upgrade |
| `ERC20Vault` | Bridge (via resolver) | `onMessageInvocation` (`ERC20Vault.sol:475`, `onlyFromNamed(B_BRIDGE)` via `checkProcessMessageContext`, `BaseVault.sol:53-62`) |
| `ERC721Vault` / `ERC1155Vault` | owner | `init` (`ERC721Vault.sol:27`, `ERC1155Vault.sol:27`), pause/unpause, upgrade |
| `ERC721Vault` / `ERC1155Vault` | Bridge (via resolver) | `onMessageRecalled` (`ERC721Vault.sol:129`, `ERC1155Vault.sol:140`, `onlyFromNamed(B_BRIDGE)`) |
| `ProverWhitelist` | owner **or** `_proverManager` (immutable) | `whitelistProver` (`ProverWhitelist.sol:74-80`; modifier `:45-48`; immutable `:18,56-59`) |
| `PreconfWhitelist` | owner **or** ejecter | `addOperator` (`PreconfWhitelist.sol:94`), `removeOperator` (`:100`), `removeOperatorByAddress` (`:108`); modifier `onlyOwnerOrEjecter` `:71-74` |
| `PreconfWhitelist` | owner **or** `_ejectorManager` (immutable) | `setEjecter` (`PreconfWhitelist.sol:115-124`; modifier `:76-79`) |
| `SP1Verifier` | owner (OZ `Ownable2Step`) | `setProgramTrusted` (`SP1Verifier.sol:44-47`) |
| `Risc0Verifier` | owner (OZ `Ownable2Step`) | `setImageIdTrusted` (`Risc0Verifier.sol:43-46`) |
| `SgxVerifier` | owner | `addInstances` (`SgxVerifier.sol:224-227`), `deleteInstances` (`:236`), `setMrEnclave` (`:258`), `setMrSigner` (`:283`), `toggleLocalReportCheck` (`:297`) |
| `SgxVerifier` | `registrar` (immutable) **or** owner | `registerInstance` (`SgxVerifier.sol:316-319`; owner fast-path at `:455`) |
| `SecureSgxVerifier` | owner | `setEnclaveAttributePolicy` (`SecureSgxVerifier.sol:85-91`) |
| `SecureSgxVerifier` | owner **or** `registrar` | `removeEnclaveAttributePolicy` (`SecureSgxVerifier.sol:138`, modifier `:70-76`) — can only fail-close, never relax |
| `QuotaManager` | owner | `updateQuota` (`QuotaManager.sol:70`), `setQuotaPeriod` (`:81`) |
| `QuotaManager` | `bridge` / `erc20Vault` (immutables) | `consumeQuota` (`QuotaManager.sol:86`) |
| `TaikoToken` | owner (recorded as `controller.taiko.eth`) | `init` (`TaikoToken.sol:35`), `init2` (`:44`), upgrade |
| `SharedResolver` (all vault/bridge lookups) | owner | address registration — controls `resolve()` results consumed by `Bridge.isDestChainEnabled` (`Bridge.sol:517-524`) and `BaseVault` (`BaseVault.sol:60,69`) |
| Any `EssentialContract` | owner | `transferOwnership`/`acceptOwnership` (OZ), `upgradeTo`/`upgradeToAndCall` (`EssentialContract.sol:207`), `pause`/`unpause` (`:150,159`) |

**Roles an R1/R2 design (permissionless sequencing + same-tx proof) would have to remove or neutralize** — currently live, each with the function that exercises it:

1. `Inbox` owner's `activate`/`init2`/`init3` — `init3` can unilaterally void the forced-inclusion queue (`Inbox.sol:253-258`).
2. The `IProposerChecker` indirection itself — mainnet's `_proposerChecker` is an epoch-based single-operator whitelist (`PreconfWhitelist.checkProposer`, `PreconfWhitelist.sol:127-141`), and `Inbox.propose` has no permissionless fallback (`Inbox.sol:601-603`).
3. `ProverWhitelist` owner/proverManager `whitelistProver` (`ProverWhitelist.sol:74`) plus the `Inbox` `ProverNotWhitelisted` gate (`Inbox.sol:337,777`).
4. `SignalService._authorizedSyncer` (immutable, single writer — `SignalService.sol:174-175`) and the Anchor golden-touch gate (`Anchor.sol:86-89,124-127`) for any L2-side change.
5. Every verifier owner's allowlist function (`setProgramTrusted`, `setImageIdTrusted`, `setMrEnclave`, `setMrSigner`, `setEnclaveAttributePolicy`, `addInstances`, `deleteInstances`, `toggleLocalReportCheck`, `registerInstance`).
6. `Bridge`/vault `pause` and the Bridge `pauser`'s `receive()` monopoly (`Bridge.sol:186-188`).
7. The resolver owner, because `Bridge` and the vaults resolve peer-chain addresses through it (`Bridge.sol:522`, `BaseVault.sol:60,69`).

Note the asymmetry worth exploiting in a redesign: **`Inbox.propose` and `Inbox.prove` are not pause-gated at all** (no `whenNotPaused` anywhere in `Inbox.sol`), while the Bridge, vaults and SignalService are.

---
## 10. Gaps and uncertainties

| # | Gap | What is missing / where to look |
| --- | --- | --- |
| 1 | **Prover "tiers"** | Grep for `tier|Tier|TIER` across `packages/protocol/contracts` returns zero matches — the concept does not exist at this commit. The nearest equivalent is `ComposeVerifier.VerifierType` + `areVerifiersSufficient` (`ComposeVerifier.sol:13-21,107-111`). |
| 2 | **BondManager implementation** | `packages/protocol/contracts/layer2/core/BondManager_Layout.sol` exists (auto-generated, slots 251-252, `uint256[44] __gap`) but there is no `BondManager.sol` and no deployment entry on any chain. `git log --all -- packages/protocol/contracts/layer2/core/BondManager.sol` would resolve whether it ever existed. `IBondManager` is implemented **on L1 by the Inbox itself** (`Inbox.sol:36,403-425`). |
| 3 | **Fork router deployments** | No concrete `ForkRouter` subclass and no `shouldRouteToOldFork` override exist in `contracts/`, `script/` or `test/` — only the abstract base (`shared/fork-router/ForkRouter.sol`). Yet `SignalService.sol:14-16` says the contract "will be initially deployed behind the fork router" and the generated layouts `SignalServiceForkRouter_Layout.sol` / `AnchorForkRouter_Layout.sol` exist. The routers are not in this checkout. |
| 4 | **URC wiring** | `package.json:63` + `foundry.toml:41` pull in `eth-fabric/urc`; no Solidity file under `contracts/`, `script/` or `test/` imports it. The preconf area is only `PreconfWhitelist` + `LibPreconfUtils/LibPreconfConstants`. |
| 5 | **Hoodi L1 address library** | No `LibL1HoodiAddrs` (or equivalent) exists; Hoodi L1 addresses appear only in `deployments/taiko-hoodi-contract-logs.md`. `LibL1Addrs.sol` is mainnet-only. |
| 6 | **Not read** | `MainnetDAOController.sol` + layout, `shared/libs/LibTrieProof.sol`, `shared/common/EssentialResolverContract.sol`, `shared/vault/BaseNFTVault.sol` (full), `shared/governance/TaikoTokenBase.sol`, the `SharedResolver` implementation, deploy/bundle scripts other than the three read, and all of `packages/taiko-client*` (off-chain derivation is out of scope and not covered here). For a complete privileged-role inventory, `packages/protocol/contracts/shared/governance/**` and `script/layer1/proposals/**` would need reading. |
| 7 | **`LibPackUnpack`** | Read only through its call sites. Byte-widths in §4.4 come from the explicit field order in `LibCodec.sol:59-72` and the size arithmetic at `LibCodec.sol:110-121`. For the exact little-endian layout of `packUint48`/`packUint24`, read `packages/protocol/contracts/layer1/core/libs/LibPackUnpack.sol` (321 lines). |
| 8 | **Addresses are as-recorded, not chain-verified** | Every address in §6 comes from a repo constant or a hand-maintained `deployments/*.md` log; no `eth_call`/explorer verification was performed. The logs note on-chain reads dated 2026-07-07 for QuotaManager (`mainnet-contract-logs-L1.md:72`). |
| 9 | **Live verifier wiring** | `LibL1Addrs.ZK_REQUIRED_VERIFIER` (`LibL1Addrs.sol:56`) and the log agree the active mainnet verifier is `ZkRequiredVerifier`; whether the **Inbox's immutable** `_proofVerifier` currently points at it can only be confirmed by `Inbox.getConfig().proofVerifier` on-chain (`Inbox.sol:530`) or by reading the upgrade bundle at `script/layer1/mainnet/DeployInboxUpgradeL1.s.sol:51-55`. |
| 10 | **No per-transition persistence** | Confirmed absent: the only persisted proof-side data are `CoreState.lastFinalizedBlockHash` and the `Checkpoint` (`Inbox.sol:376-378`, `:364-370`). If D3 needs per-transition records on L1, that is **new** state and must be carved out of the Inbox `__gap` (slots 258-300) or SignalService's gap (255-300). |
