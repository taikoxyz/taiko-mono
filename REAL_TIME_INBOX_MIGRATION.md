# Real-Time Inbox: Technical Reference

> Documents the shift from the standard two-phase `Inbox` (Shasta) to the single-phase
> `RealTimeInbox` for real-time proving.

---

## 1. Architectural Shift

### Standard Inbox — Two-Phase Model

```
Phase 1: propose(lookahead, data)  →  Store proposal hash in ring buffer, emit Proposed
Phase 2: prove(data, proof)        →  Verify proof for a BATCH of proposals, finalize state
```

Proposals accumulate on-chain. A prover later submits a single proof covering a contiguous range
of proposals `[N..M]`. The contract maintains `CoreState`, a ring buffer of proposal hashes,
forced inclusion queues, and bond balances.

### RealTimeInbox — Atomic Single-Phase Model

```
propose(data, checkpoint, proof)  →  Build proposal + Verify proof + Finalize (one tx)
```

Each proposal is proven immediately in the same transaction. Only `bytes32 lastProposalHash` is
persisted. No batching — exactly one proposal per proof. No bonds, forced inclusions, proposer
checks, prover whitelist, or ring buffer.

The prover must execute L2 blocks and generate the ZK proof **before** submitting the
transaction.

---

## 2. Type Changes

### 2.1 Config

**Inbox** `IInbox.Config` — 17 fields:

```solidity
struct Config {
    address proofVerifier;
    address proposerChecker;                // REMOVED
    address proverWhitelist;                // REMOVED
    address signalService;
    address bondToken;                      // REMOVED
    uint64  minBond;                        // REMOVED
    uint64  livenessBond;                   // REMOVED
    uint48  withdrawalDelay;                // REMOVED
    uint48  provingWindow;                  // REMOVED
    uint48  permissionlessProvingDelay;     // REMOVED
    uint48  maxProofSubmissionDelay;        // REMOVED
    uint48  ringBufferSize;                 // REMOVED
    uint8   basefeeSharingPctg;
    uint16  forcedInclusionDelay;           // REMOVED
    uint64  forcedInclusionFeeInGwei;       // REMOVED
    uint64  forcedInclusionFeeDoubleThreshold; // REMOVED
    uint8   permissionlessInclusionMultiplier; // REMOVED
}
```

**RealTimeInbox** `IRealTimeInbox.Config` — 3 fields:

```solidity
struct Config {
    address proofVerifier;      // SurgeVerifier address
    address signalService;      // SignalService address
    uint8   basefeeSharingPctg; // % of basefee paid to coinbase
}
```

### 2.2 ProposeInput

**Inbox** `IInbox.ProposeInput`:

```solidity
struct ProposeInput {
    uint48                 deadline;             // REMOVED
    LibBlobs.BlobReference blobReference;
    uint16                 numForcedInclusions;  // REMOVED
}
```

**RealTimeInbox** `IRealTimeInbox.ProposeInput`:

```solidity
struct ProposeInput {
    LibBlobs.BlobReference blobReference;
    bytes32[]              signalSlots;           // NEW — L1 signal slots to relay
    uint48                 maxAnchorBlockNumber;  // NEW — highest L1 anchor block
}
```

- `signalSlots` is now a first-class input. Each slot is verified via
  `_signalService.isSignalSent(slot)` and hashed into the proposal.
- `maxAnchorBlockNumber` must satisfy `blockhash(maxAnchorBlockNumber) != 0`
  (within last 256 L1 blocks). The corresponding `maxAnchorBlockHash` is read on-chain via
  `blockhash()` and included in the proposal. These new max anchor block values will be used
  for verifying anchor linkage — the L2 node uses them to verify that anchor transactions
  reference a valid, recent L1 block.

### 2.3 Proposal

**Inbox** `IInbox.Proposal` — stored in ring buffer:

```solidity
struct Proposal {
    uint48                 id;                              // REMOVED
    uint48                 timestamp;                       // REMOVED
    uint48                 endOfSubmissionWindowTimestamp;   // REMOVED
    address                proposer;                        // REMOVED
    bytes32                parentProposalHash;
    uint48                 originBlockNumber;               // REMOVED
    bytes32                originBlockHash;                  // REMOVED
    uint8                  basefeeSharingPctg;
    DerivationSource[]     sources;
    bytes32                signalSlotsHash;
}
```

**RealTimeInbox** `IRealTimeInbox.Proposal` — **transient, never stored** (only hashed):

```solidity
struct Proposal {
    uint48                   maxAnchorBlockNumber;  // NEW — highest L1 anchor block number
    bytes32                  maxAnchorBlockHash;    // NEW — blockhash(maxAnchorBlockNumber)
    uint8                    basefeeSharingPctg;
    IInbox.DerivationSource[] sources;              // Reuses IInbox.DerivationSource
    bytes32                  signalSlotsHash;
}
```

- Standalone — no parent linkage. State continuity is enforced via `Commitment.lastBlockHash`.
- No sequential `id` — proposals identified by hash only.
- No `timestamp`, `proposer`, or `endOfSubmissionWindowTimestamp`.
- `originBlockNumber`/`originBlockHash` replaced by `maxAnchorBlockNumber`/`maxAnchorBlockHash`.
  The semantics shift from "L1 block the proposal was made in" to "highest L1 block the L2
  derivation can reference." The new max anchor block values will be used for verifying anchor
  linkage — the L2 execution layer uses `maxAnchorBlockNumber` and `maxAnchorBlockHash` to
  validate that anchor transactions in L2 blocks correctly reference an L1 block at or before
  this height, ensuring L1-L2 state consistency.

### 2.4 Commitment (Critical for Provers)

**Inbox** `IInbox.Commitment` — covers a batch:

```solidity
struct Commitment {
    uint48      firstProposalId;
    bytes32     firstProposalParentBlockHash;
    bytes32     lastProposalHash;
    address     actualProver;
    uint48      endBlockNumber;
    bytes32     endStateRoot;
    Transition[] transitions;   // Per-proposal: { proposer, timestamp, blockHash }
}
```

**RealTimeInbox** `IRealTimeInbox.Commitment` — covers exactly one proposal:

```solidity
struct Commitment {
    bytes32                       proposalHash;
    bytes32                       lastFinalizedBlockHash;  // Block hash of last finalized L2 block (proof starting state)
    ICheckpointStore.Checkpoint   checkpoint;              // { blockNumber, blockHash, stateRoot }
}
```

No batch support. No `actualProver`, no `Transition[]`. The `lastFinalizedBlockHash` binds the
proof to the correct starting state (must match `lastFinalizedBlockHash` on-chain). The checkpoint
contains the finalized L2 state for the single proposal.

### 2.5 Removed Types

| Type                 | Purpose                                                           |
| -------------------- | ----------------------------------------------------------------- |
| `CoreState`          | Tracked nextProposalId, lastFinalizedProposalId, timestamps, etc. |
| `Transition`         | Per-proposal transition data in batch proofs                      |
| `ProveInput`         | Wrapper for Commitment in `prove()`                               |
| `ProvedEventPayload` | Event payload struct                                              |

### 2.6 Shared Types (Unchanged)

```solidity
// IInbox — reused by RealTimeInbox
struct DerivationSource {
    bool                isForcedInclusion;  // Always false in RealTimeInbox
    LibBlobs.BlobSlice  blobSlice;
}

// LibBlobs
struct BlobReference { uint16 blobStartIndex; uint16 numBlobs; uint24 offset; }
struct BlobSlice     { bytes32[] blobHashes; uint24 offset; uint48 timestamp; }

// ICheckpointStore
struct Checkpoint { uint48 blockNumber; bytes32 blockHash; bytes32 stateRoot; }
```

---

## 3. Function Signatures

### Activation

```solidity
// Inbox
function activate(bytes32 _lastPacayaBlockHash) external onlyOwner;
// Sets up CoreState, stores genesis proposal hash in ring buffer slot 0

// RealTimeInbox
function activate(bytes32 _genesisBlockHash) external onlyOwner;
// Sets lastFinalizedBlockHash = _genesisBlockHash. Can only be called once.
```

### Propose

```solidity
// Inbox — proposal only, no proof
function propose(bytes calldata _lookahead, bytes calldata _data) external;

// RealTimeInbox — atomic propose + prove
function propose(
    bytes calldata _data,                           // abi.encode(IRealTimeInbox.ProposeInput)
    ICheckpointStore.Checkpoint calldata _checkpoint,
    bytes calldata _proof
) external;
```

### Prove (Removed)

```solidity
// Inbox
function prove(bytes calldata _data, bytes calldata _proof) external;

// RealTimeInbox — does not exist. Proving is embedded in propose().
```

### Removed Function Groups

- **Bond management**: `deposit`, `depositTo`, `withdraw`, `requestWithdrawal`, `cancelWithdrawal`, `getBond`
- **Forced inclusions**: `saveForcedInclusion`, `getCurrentForcedInclusionFee`, `getForcedInclusions`, `getForcedInclusionState`

### State Queries

```solidity
// Inbox
function getCoreState() external view returns (CoreState memory);
function getProposalHash(uint256 _proposalId) external view returns (bytes32);

// RealTimeInbox — replaces both with:
function getLastFinalizedBlockHash() external view returns (bytes32);
```

### Encoding Helpers

RealTimeInbox uses plain `abi.encode`/`abi.decode` (no `LibCodec` or `LibHashOptimized`):

```solidity
function encodeProposeInput(ProposeInput calldata) public pure returns (bytes memory);
function decodeProposeInput(bytes calldata) public pure returns (ProposeInput memory);
function hashProposal(Proposal memory) public pure returns (bytes32);       // keccak256(abi.encode(...))
function hashCommitment(Commitment memory) public pure returns (bytes32);   // keccak256(abi.encode(...))
function hashSignalSlots(bytes32[] memory) public pure returns (bytes32);   // keccak256(abi.encode(...))
```

---

## 4. On-Chain State

**Inbox**:

```solidity
uint48 public activationTimestamp;
CoreState internal _coreState;                                    // 2 slots
mapping(uint256 bufferSlot => bytes32 proposalHash) _proposalHashes;  // ring buffer
LibForcedInclusion.Storage _forcedInclusionStorage;               // 2 slots
LibBonds.Storage _bondStorage;
```

**RealTimeInbox**:

```solidity
bytes32 public lastFinalizedBlockHash;   // 1 slot — block hash of last finalized L2 block
```

---

## 5. Events

**Inbox** emits separate events for proposing and proving:

```solidity
event Proposed(
    uint48 indexed id, address indexed proposer,
    bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp,
    uint8 basefeeSharingPctg, DerivationSource[] sources, bytes32 signalSlotsHash
);

event Proved(
    uint48 firstProposalId, uint48 firstNewProposalId,
    uint48 lastProposalId, address indexed actualProver
);
```

**RealTimeInbox** emits a single combined event:

```solidity
event ProposedAndProved(
    bytes32 indexed proposalHash,
    bytes32 lastFinalizedBlockHash,
    uint48  maxAnchorBlockNumber,
    uint8   basefeeSharingPctg,
    IInbox.DerivationSource[] sources,
    bytes32[] signalSlots,
    ICheckpointStore.Checkpoint checkpoint
);
```

- Indexed by `proposalHash` instead of sequential `id`.
- `lastFinalizedBlockHash` replaces `parentProposalHash` — the block hash of the last finalized L2 block.
- Includes the finalized `Checkpoint` directly.
- No `proposer` or `actualProver` field.

---

## 6. Proof Verification

Both contracts call `IProofVerifier.verifyProof(uint256, bytes32, bytes)`. The interface is
unchanged.

**Inbox**:

```
proposalAge = block.timestamp - transitions[offset].timestamp
commitmentHash = LibHashOptimized.hashCommitment(commitment)
verifyProof(proposalAge, commitmentHash, proof)
```

**RealTimeInbox**:

```
proposalAge = 0                                          // always 0
commitmentHash = keccak256(abi.encode(commitment))       // plain abi.encode
verifyProof(0, commitmentHash, proof)
```

### Commitment Hash Reconstruction

For off-chain reconstruction of the commitment hash:

```
proposalHash = keccak256(abi.encode(
    uint48  maxAnchorBlockNumber,       // padded to 32 bytes by abi.encode
    bytes32 maxAnchorBlockHash,
    uint8   basefeeSharingPctg,         // padded to 32 bytes by abi.encode
    IInbox.DerivationSource[] sources,  // dynamic array encoding
    bytes32 signalSlotsHash
))

commitmentHash = keccak256(abi.encode(
    bytes32 proposalHash,
    bytes32 lastFinalizedBlockHash,    // last finalized L2 block hash
    uint48  checkpoint.blockNumber,     // padded to 32 bytes by abi.encode
    bytes32 checkpoint.blockHash,
    bytes32 checkpoint.stateRoot
))
```

### Signal Slots Hash

```solidity
signalSlotsHash = bytes32(0)                             // if empty
signalSlotsHash = keccak256(abi.encode(signalSlots))     // if non-empty (bytes32[])
```

---

## 7. L2 Anchor Integration — Signal Slot Relay

`signalSlots` provided in `ProposeInput` must be relayed to L2 so that nodes can verify L1→L2
cross-chain messages without a separate proof. The relay happens through the L2 anchor
transaction of the **first block** in the batch.

### Anchor Function

The standard `anchorV4` is replaced by `anchorV4WithSignalSlots`:

```solidity
// Anchor.sol (L2)

// Standard — no signal relay
function anchorV4(ICheckpointStore.Checkpoint calldata _checkpoint) external;

// Real-time inbox — relays signal slots in the first block's anchor tx
function anchorV4WithSignalSlots(
    ICheckpointStore.Checkpoint calldata _checkpoint,
    bytes32[]              calldata _signalSlots
) external;
```

### Placement Rule

Only the **first block** of a batch carries all signal slots. Subsequent blocks in the same
batch call `anchorV4WithSignalSlots` with an empty `_signalSlots` array (or `anchorV4`).

```
Batch (from one propose() call)
├── Block 0 — anchorV4WithSignalSlots(checkpoint, signalSlots)   ← all slots here
├── Block 1 — anchorV4WithSignalSlots(checkpoint, [])
└── Block N — anchorV4WithSignalSlots(checkpoint, [])
```

### What the Anchor Does with Signal Slots

```solidity
if (_signalSlots.length > 0) {
    ISignalService(address(checkpointStore)).setSignalsReceived(_signalSlots);
}
```

Each slot is marked as received in the `SignalService`, making L1 signals immediately
consumable on L2 without a merkle proof — consistent with the real-time proving model where
L1 state is already finalized before the L2 block is executed.

### Relationship to `signalSlotsHash`

The same `signalSlots` array that is passed to `anchorV4WithSignalSlots` on L2 is also hashed
into the proposal on L1:

```
L1 propose():  signalSlotsHash = keccak256(abi.encode(signalSlots))  →  committed in proposalHash
L2 anchor():   anchorV4WithSignalSlots(checkpoint, signalSlots)       →  signals set in SignalService
```

The ZK proof covers both sides, ensuring the same set of slots is committed on L1 and
activated on L2.

---

## 8. Removed Features Summary

| Feature                            | Impact                                    |
| ---------------------------------- | ----------------------------------------- |
| Batch proving                      | One proposal per proof; no `Transition[]` |
| Ring buffer                        | No historical proposal hash queries       |
| Bonds                              | No economic security from proposer stakes |
| Forced inclusions                  | No censorship resistance mechanism        |
| Proposer checker / lookahead       | Anyone can propose                        |
| Prover whitelist                   | Anyone can prove                          |
| Proving window / liveness slashing | No deadlines or slashing                  |
| One-per-block limit                | Multiple proposals per L1 block allowed   |
| Transaction deadline               | No `deadline` field in input              |
