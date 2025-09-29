# Taiko Proposer Guide

This guide provides comprehensive instructions for proposers interacting with Taiko's Shasta fork inbox contract. It covers the propose method workflow, requirements, and best practices for successful block proposal submission.

## Overview

As a proposer in Taiko's based rollup architecture, you submit L2 block proposals to the L1 inbox contract. The propose function handles:
- Proposer authorization verification
- Automatic finalization of eligible proposals
- Forced inclusion processing
- Ring buffer state management
- Bond instruction aggregation

## Prerequisites

### 1. Proposer Authorization

Before proposing, you must be authorized by the `ProposerChecker` contract:
- Your address must pass proposer validation checks
- The checker returns an `endOfSubmissionWindowTimestamp` for your proposal window
- Proposals must be submitted before this timestamp expires

### 2. Sufficient L2 Bonds

Maintain adequate bond balance in the L2 `BondManager` contract:
- Bonds cover proving fees and ensure proposal integrity
- Low-bond proposals trigger default manifest replacement (single empty block)
- Check your bond status before proposing to avoid penalties

### 3. Blob Preparation

Proposals use EIP-4844 blobs for data availability:
- Prepare your proposal manifest as a `ProposalManifest` struct
- RLP encode the manifest
- Compress using ZLIB
- Package into blobs with proper versioning (version `0x1` for Shasta)
- Calculate blob references with correct offset and size

## Propose Function Workflow

### Step 1: Prepare ProposeInput

```solidity
struct ProposeInput {
    uint48 deadline;                    // Optional: transaction deadline (0 = no deadline)
    Proposal[] parentProposals;         // 1-2 proposals proving chain head
    CoreState coreState;               // Current core state
    TransitionRecord[] transitionRecords; // Records for finalization (optional)
    Checkpoint checkpoint;              // L2 checkpoint for finalization
    uint256 numForcedInclusions;       // Number of forced inclusions to process
    LibBlobs.BlobReference blobReference; // Your proposal data reference
}
```

### Step 2: Chain Head Verification

Provide correct parent proposals to prove you're building on the chain head:

**Case 1: Next ring buffer slot is empty**
- Include only the latest proposal in `parentProposals[0]`
- Array length must be exactly 1

**Case 2: Next ring buffer slot is occupied**
- Include latest proposal in `parentProposals[0]`
- Include the older proposal in that slot as `parentProposals[1]`
- Array length must be exactly 2
- Ensures `parentProposals[1].id < parentProposals[0].id`

### Step 3: Forced Inclusion Processing

The proposer must handle forced inclusions when due:

**Minimum Requirements:**
- Process at least `config.minForcedInclusionCount` if any are due
- Due = older than `config.forcedInclusionDelay` seconds
- Failure to process due forced inclusions causes transaction revert

**Processing Logic:**
- Specify `numForcedInclusions` in your input
- System consumes oldest forced inclusions first (FIFO)
- Each forced inclusion becomes a `DerivationSource` in your proposal
- Your regular proposal is added as the last derivation source

**Important:** If ring buffer capacity is limited, forced inclusions take priority over your regular proposal.

### Step 4: Optional Finalization

Help maintain chain health by including finalization data:

```solidity
// Include transition records for proposals ready to finalize
input.transitionRecords = [...]; // Up to maxFinalizationCount records

// Provide the L2 checkpoint matching the last finalized record
input.checkpoint = Checkpoint({
    blockNumber: ...,
    blockHash: ...,
    stateRoot: ...
});
```

**Benefits of Finalization:**
- Frees ring buffer space for new proposals
- Processes bond instructions
- Updates chain checkpoints
- Improves overall system throughput

### Step 5: Submit Transaction

Call the propose function with proper encoding:

```solidity
bytes memory lookahead = ""; // Currently unused, pass empty bytes
bytes memory data = abi.encode(proposeInput);
inbox.propose(lookahead, data);
```

## Proposal Manifest Structure

Your blob data should contain a properly formatted `ProposalManifest`:

```solidity
struct ProposalManifest {
    bytes proverAuthBytes;        // Prover designation (optional)
    BlockManifest[] blocks;       // Array of blocks to propose
}

struct BlockManifest {
    uint48 timestamp;             // Block timestamp
    address coinbase;             // Coinbase recipient (0 = use proposer)
    uint48 anchorBlockNumber;     // L1 anchor block (0 = use parent's)
    uint48 gasLimit;              // Block gas limit (0 = use parent's)
    SignedTransaction[] transactions; // Transactions for this block
}
```

### Prover Designation

Include `proverAuthBytes` to designate a specific prover:

1. **Create ProverAuth struct:**
   ```solidity
   ProverAuth {
       uint48 proposalId;      // Must match proposal.id
       address proposer;       // Your proposer address
       uint64 provingFeeGwei;  // Fee offered to prover
       Signature signature;    // ECDSA signature of above fields
   }
   ```

2. **Sign the message:**
   ```solidity
   bytes32 message = keccak256(abi.encode(proposalId, proposer, provingFeeGwei));
   // Sign with prover's private key
   ```

3. **ABI encode the struct** and include in manifest

**Note:** Invalid prover auth falls back to proposer as designated prover (no default manifest trigger).

## Validation Rules and Constraints

### Timestamp Constraints

Block timestamps must satisfy:
- **Upper bound:** `timestamp ≤ proposal.timestamp`
- **Lower bound:** `timestamp ≥ max(parent.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET)`
- Violations cause automatic adjustment (not rejection)

### Anchor Block Requirements

L1 anchor blocks must be:
- **Monotonic:** `anchorBlockNumber ≥ parent.anchorBlockNumber`
- **Not future:** `anchorBlockNumber < proposal.originBlockNumber - ANCHOR_MIN_OFFSET`
- **Not stale:** `anchorBlockNumber ≥ proposal.originBlockNumber - ANCHOR_MAX_OFFSET`

**Critical:** Non-forced proposals with no valid anchors trigger default manifest replacement.

### Gas Limit Adjustments

Gas limits are constrained by `BLOCK_GAS_LIMIT_MAX_CHANGE` (default: 10 permyriad = ±0.1% per block):
- Changes beyond limits are clamped
- Minimum enforced: `MIN_BLOCK_GAS_LIMIT`
- Zero values inherit from parent

### Transaction Inclusion

Transactions must be properly formatted `types.Transactions` structs:
- Follow EIP-2718 typed transaction format
- Include valid signatures
- Ensure sufficient gas for execution
- Consider L2 base fee when setting gas prices

## Error Handling

Common revert reasons and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `ACCESS_DENIED` | Not authorized proposer | Check ProposerChecker authorization |
| `DeadlineExceeded` | Proposal deadline passed | Submit transaction faster or increase deadline |
| `NotEnoughCapacity` | Ring buffer full | Wait for finalization or help finalize |
| `UnprocessedForcedInclusionIsDue` | Missed forced inclusions | Increase `numForcedInclusions` |
| `IncorrectProposalCount` | Wrong parent proposals | Verify chain head correctly |
| `InvalidState` | Core state mismatch | Sync with latest chain state |
| `CannotProposeInCurrentBlock` | Block number too early | Wait for `nextProposalBlockId` |

## Best Practices

### 1. Monitor Ring Buffer Capacity

```solidity
uint256 availableCapacity = ringBufferSize - 1 - (nextProposalId - lastFinalizedProposalId - 1);
```
Help finalize when capacity is low to maintain system health.

### 2. Process Forced Inclusions Proactively

Check for due forced inclusions before proposing:
```solidity
bool isDue = inbox.isOldestForcedInclusionDue();
```

### 3. Optimize Gas Usage

- Include finalization data when possible (frees buffer space)
- Batch multiple blocks in a single proposal
- Use efficient transaction packing

### 4. Handle Failures Gracefully

- Implement retry logic with exponential backoff
- Monitor proposal events for success confirmation
- Track bond balance to avoid low-bond scenarios

### 5. Coordinate with Provers

- Designate reliable provers with sufficient bonds
- Offer competitive proving fees
- Monitor proof submission for your proposals

## Events and Monitoring

Monitor these events for proposal tracking:

```solidity
event Proposed(bytes data);  // Emitted on successful proposal
event Proved(bytes data);    // Tracks proof submissions
```

Decode event data to extract:
- Proposal ID and metadata
- Derivation sources and blob references
- Core state updates
- Bond instruction processing

## Security Considerations

1. **Private Key Management:** Secure proposer and prover signing keys
2. **Bond Security:** Maintain bonds in secure L2 wallets
3. **Blob Validation:** Verify blob data integrity before submission
4. **Front-running Protection:** Use commit-reveal or flashbots for sensitive proposals
5. **Rate Limiting:** Respect one proposal per Ethereum block limitation

## Conclusion

Successful proposing requires:
- Understanding the ring buffer mechanics
- Proper chain head verification
- Timely forced inclusion processing
- Coordination with provers
- Maintaining sufficient bonds

Follow this guide to ensure smooth proposal submission and contribute to Taiko's rollup security and liveness.
