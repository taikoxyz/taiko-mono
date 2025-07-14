// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInbox
/// @notice Interface for the Taiko Alethia protocol inbox
/// @dev Defines all data structures and function signatures for the simplified
///      based rollup protocol without tier-based proof system
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Represents a block within a batch
    /// @dev Contains block-specific parameters and anchor information
    struct Block {
        /// @notice Maximum number of transactions in this block
        /// @dev If insufficient transactions in calldata/blobs, block contains as many as possible
        uint16 numTransactions;
        /// @notice Time difference in seconds between this block and its parent within the batch
        /// @dev For the first block in a batch, this should be 0 (no parent in same batch)
        uint8 timeShift;
        /// @notice Optional anchor block ID for L1-L2 synchronization
        uint48 anchorBlockId;
        /// @notice Number of cross-chain signals in this block
        uint8 numSignals;
        /// @notice Whether this block references an anchor block
        bool hasAnchor;
    }

    /// @notice Contains blob data for a batch
    /// @dev Supports both direct blob hashes and blob indices for different scenarios
    struct Blobs {
        /// @notice Direct blob hashes (if non-empty, firstBlobIndex and numBlobs must be 0)
        bytes32[] hashes; // length <= type(uint4).max
        /// @notice Index of the first blob in this batch (for blob index mode)
        uint8 firstBlobIndex;
        /// @notice Number of blobs in this batch
        /// @dev Blobs are concatenated and decompressed via Zlib
        uint8 numBlobs;
        /// @notice Byte offset of the blob data within the batch
        uint32 byteOffset;
        /// @notice Size of the blob data in bytes
        uint32 byteSize;
        /// @notice Block number when blobs were created (only for forced inclusion)
        /// @dev Non-zero only when hashes array is used
        uint48 createdIn;
    }

    /// @notice Represents a batch of blocks to be proposed
    /// @dev Contains all data needed for batch validation and processing
    struct Batch {
        /// @notice Address that proposed this batch
        address proposer;
        /// @notice Coinbase address for block rewards (can be zero)
        address coinbase;
        /// @notice Timestamp of the last block in this batch
        uint48 lastBlockTimestamp;
        /// @notice Gas issuance rate per second for this batch
        uint32 gasIssuancePerSecond;
        /// @notice Whether this is a forced inclusion batch
        bool isForcedInclusion;
        /// @notice Prover authorization data
        bytes proverAuth; // length <= type(uint16).max
        /// @notice Signal slots for cross-chain messages
        bytes32[] signalSlots; // length <= type(uint8).max
        /// @notice Anchor block IDs for L1-L2 synchronization
        uint48[] anchorBlockIds; // length <= type(uint16).max
        /// @notice Array of blocks in this batch
        Block[] blocks; // length <= type(uint16).max
        /// @notice Blob data for this batch
        Blobs blobs;
    }

    /// @notice Output structure containing validated batch information
    /// @dev This struct aggregates all validation results for efficient batch processing
    struct BatchContext {
        address prover;
        bytes32 txsHash;
        uint48 lastAnchorBlockId;
        uint48 lastBlockId;
        uint48 blobsCreatedIn;
        uint48 livenessBond; // Gwei
        uint48 provabilityBond; // Gwei
        uint8 baseFeeSharingPctg;
        bytes32[] anchorBlockHashes; // length <= type(uint16).max
        bytes32[] blobHashes; // length <= type(uint4).max
    }

    /// @notice Authorization data for proving a batch
    /// @dev Contains prover credentials, fee information, and validity constraints
    struct ProverAuth {
        /// @notice Address authorized to prove this batch
        address prover;
        /// @notice Token used for fee payment (ETH not supported for simplicity)
        address feeToken; // Ether not supported!
        /// @notice Fee amount in Gwei
        uint48 fee; // Gwei
        /// @notice Optional expiration timestamp (0 = no expiration)
        uint48 validUntil; // optional
        /// @notice Optional batch ID restriction (0 = any batch)
        uint48 batchId; // optional
        /// @notice Cryptographic signature authorizing the prover
        /// @dev Maximum length is 1023 bytes (type(uint10).max)
        bytes signature; // length <= type(uint10).max
    }

    /// @notice Metadata for building and validating a batch
    /// @dev Contains all necessary information for batch construction and verification
    struct BatchBuildMetadata {
        /// @notice Hash of all transactions in the batch
        bytes32 txsHash;
        /// @notice Array of blob hashes referenced by this batch
        bytes32[] blobHashes; // length <= type(uint4).max
        /// @notice Additional arbitrary data for the batch
        bytes32 extraData;
        /// @notice Address to receive block rewards
        address coinbase;
        /// @notice Block number when this batch was proposed
        uint48 proposedIn;
        /// @notice Block number when blobs were created
        uint48 blobCreatedIn;
        /// @notice Byte offset within blob data
        uint48 blobByteOffset;
        /// @notice Size of blob data in bytes
        uint48 blobByteSize;
        /// @notice ID of the last block in this batch
        uint48 lastBlockId;
        /// @notice Timestamp of the last block in this batch
        uint48 lastBlockTimestamp;
        /// @notice Array of anchor block IDs for L1-L2 synchronization
        uint48[] anchorBlockIds; // length <= type(uint16).max
        /// @notice Hashes of anchor blocks for verification
        bytes32[] anchorBlockHashes; // length <= type(uint16).max
        /// @notice Array of blocks contained in this batch
        Block[] blocks; // length <= type(uint16).max
    }

    /// @notice Simplified metadata for batch proposals
    /// @dev Contains minimal information needed for proposal validation
    struct BatchProposeMetadata {
        /// @notice Timestamp of the last block in the batch
        uint48 lastBlockTimestamp;
        /// @notice ID of the last block in the batch
        uint48 lastBlockId;
        /// @notice ID of the last anchor block referenced
        uint48 lastAnchorBlockId;
    }

    /// @notice Metadata for batch proving operations
    /// @dev Contains information about proposer, prover, and bond requirements
    struct BatchProveMetadata {
        /// @notice Address that originally proposed this batch
        address proposer;
        /// @notice Address authorized to prove this batch
        address prover;
        /// @notice Timestamp when the batch was proposed
        uint48 proposedAt;
        /// @notice ID of the first block in the batch
        uint48 firstBlockId;
        /// @notice ID of the last block in the batch
        uint48 lastBlockId;
        /// @notice Bond amount for liveness guarantee in Gwei
        uint48 livenessBond; // Gwei
        /// @notice Bond amount for provability guarantee in Gwei
        uint48 provabilityBond; // Gwei
    }

    struct BatchMetadata {
        // [batchId] [buildMetaHash] [proposeMetaHash] [proveMetaHash]
        BatchProveMetadata proveMeta;
        BatchProposeMetadata proposeMeta;
        BatchBuildMetadata buildMeta;
    }

    struct BatchProposeMetadataEvidence {
        bytes32 leftHash;
        bytes32 proveMetaHash;
        BatchProposeMetadata proposeMeta;
    }

    struct BatchProveInput {
        bytes32 leftHash;
        bytes32 proposeMetaHash;
        BatchProveMetadata proveMeta;
        Transition tran;
    }

    /// @notice Struct representing transition to be proven.
    struct Transition {
        uint48 batchId;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    enum ProofTiming {
        OutOfExtendedProvingWindow,
        InProvingWindow,
        InExtendedProvingWindow
    }

    struct TransitionMeta {
        bytes32 blockHash;
        bytes32 stateRoot;
        address prover;
        ProofTiming proofTiming;
        uint48 createdAt;
        bool byAssignedProver;
        uint48 lastBlockId;
        uint48 provabilityBond;
        uint48 livenessBond;
    }

    /// @notice Struct representing transition storage
    /// @dev Uses 2 storage slots per transition for gas efficiency
    struct TransitionState {
        uint256 batchIdAndPartialParentHash;
        bytes32 metaHash;
    }

    struct Summary {
        uint48 nextBatchId;
        uint48 lastSyncedBlockId;
        uint48 lastSyncedAt;
        uint48 lastVerifiedBatchId;
        uint48 gasIssuanceUpdatedAt;
        uint32 gasIssuancePerSecond;
        bytes32 lastVerifiedBlockHash;
        bytes32 lastBatchMetaHash;
    }

    /// @notice Struct holding the fork heights.
    /// @dev All for heights are block based.
    struct ForkHeights {
        uint64 ontake;
        uint64 pacaya;
        uint64 shasta;
        uint64 unzen;
        uint64 etna;
        uint64 fuji;
    }

    /// @notice Struct holding Taiko configuration parameters
    struct Config {
        uint64 chainId;
        uint24 batchRingBufferSize;
        uint8 maxBatchesToVerify;
        uint48 livenessBond; // Gwei
        uint48 provabilityBond; // Gwei
        uint8 stateRootSyncInternal;
        uint16 maxAnchorHeightOffset;
        uint24 provingWindow;
        uint24 extendedProvingWindow;
        uint24 cooldownWindow;
        uint8 bondRewardPtcg; // 0-100
        ForkHeights forkHeights;
        address bondToken;
        address inboxWrapper;
        address verifier;
        address signalService;
        uint16 gasIssuanceUpdateDelay;
        uint8 baseFeeSharingPctg;
    }

    /// @notice Struct holding the state variables for the {Taiko} contract.
    struct State {
        // Ring buffer for proposed batches and a some recent verified batches.
        mapping(uint256 batchId_mod_batchRingBufferSize => bytes32 metaHash) batches;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint256 batchId => mapping(bytes32 parentHash => bytes32 metahash))
            transitionMetaHashes;
        // Ring buffer for transitions
        mapping(
            uint256 batchId_mod_batchRingBufferSize
                => mapping(uint256 thisValueIsAlways1 => TransitionState ts)
        ) transitions;
        bytes32 summaryHash; // slot 4
        bytes32 __deprecatedStats1; // slot 5
        bytes32 __deprecatedStats2; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
    }

    /// @notice Emitted when a batch is synced.
    /// @param summary The Summary data structure.
    event SummaryUpdated(Summary summary);

    /// @notice Emitted when a batch is proposed.
    /// @param batchId The ID of the proposed batch.
    /// @param packedContext The batch context data packed into bytes.
    event Proposed(uint48 batchId, bytes packedContext);

    /// @notice Emitted when a batch is proved.
    /// @param batchId The ID of the proved batch.
    /// @param packedTranMeta The transition metadata packed into bytes.
    event Proved(uint256 indexed batchId, bytes packedTranMeta);

    /// @notice Emitted when a batch is verified.
    /// @param uint48_batchId_uint48_blockId The ID of the verified batch and The ID of the last
    /// block in this batch.
    /// @param blockHash The hash of the verified batch.
    // solhint-disable var-name-mixedcase
    event Verified(uint256 uint48_batchId_uint48_blockId, bytes32 blockHash);

    /// @notice Proposes and verifies batches
    /// @param _packedSummary The current summary, packed into bytes
    /// @param _packedBatches The batches to propose, packed into bytes
    /// @param _packedEvidence The batch proposal evidence, packed into bytes
    /// @param _packedTransitionMetas The packed transition metadata for verification
    /// @return The updated summary
    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTransitionMetas
    )
        external
        returns (Summary memory);

    /// @notice Proves batches with cryptographic proof
    /// @param _packedSummary The current summary packed as bytes
    /// @param _packedBatchProveInputs The batch prove inputs
    /// @param _proof The cryptographic proof
    /// @return The updated summary
    function prove4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatchProveInputs,
        bytes calldata _proof
    )
        external
        returns (Summary memory);
}
