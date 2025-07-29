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
        /// @notice Signal slots for cross-chain messages
        /// @custom: max size 16
        bytes32[] signalSlots;
        /// @notice Address that receives block rewards. If this address is address(0), use
        /// Batch.coinbase.
        /// @custom:encode optional
        address coinbase;
    }

    /// @notice Contains blob data for a batch
    /// @dev Supports both direct blob hashes and blob indices for different scenarios
    struct Blobs {
        /// @notice Direct blob hashes (if non-empty, firstBlobIndex and numBlobs must be 0)
        /// @custom:encode: max size 256
        bytes32[] hashes;
        /// @notice Index of the first blob in this batch (for blob index mode)
        /// @custom:encode optional
        uint8 firstBlobIndex;
        /// @notice Number of blobs in this batch
        /// @dev Blobs are concatenated and decompressed via Zlib
        /// @custom:encode optional
        uint8 numBlobs;
        /// @notice Byte offset of the blob data within the batch
        /// @custom:encode optional
        uint32 byteOffset;
        /// @notice Size of the blob data in bytes
        uint32 byteSize;
        /// @notice Block number when blobs were created (only for forced inclusion)
        /// @dev Non-zero only when hashes array is used
        /// @custom:encode optional
        uint48 createdIn;
    }

    /// @notice Represents a batch of blocks to be proposed
    /// @dev Contains all data needed for batch validation and processing
    struct Batch {
        /// @notice Coinbase address for block rewards (can be zero)
        /// @custom:encode optional
        address coinbase;
        /// @notice Timestamp of the last block in this batch
        uint48 lastBlockTimestamp;
        /// @notice Gas issuance rate per second for this batch
        uint32 gasIssuancePerSecond;
        /// @notice Whether this is a forced inclusion batch
        bool isForcedInclusion;
        /// @notice Prover authorization data
        bytes proverAuth;
        /// @notice Array of blocks in this batch
        /// @custom:encode max-size=512
        Block[] blocks;
        /// @notice Blob data for this batch
        Blobs blobs;
    }

    /// @notice Output structure containing validated batch information
    /// @dev This struct aggregates all validation results for efficient batch processing
    struct BatchContext {
        /// @notice Address authorized to prove this batch
        address prover;
        /// @notice Hash of all transactions in the batch
        bytes32 txsHash;
        /// @notice ID of the last anchor block referenced
        uint48 lastAnchorBlockId;
        /// @notice ID of the last block in this batch
        uint48 lastBlockId;
        /// @notice Block number when blobs were created
        uint48 blobsCreatedIn;
        /// @notice Bond amount for liveness guarantee (in Gwei)
        uint48 livenessBond;
        /// @notice Bond amount for provability guarantee (in Gwei)
        uint48 provabilityBond;
        /// @notice Percentage of base fee shared with validators (0-100)
        uint8 baseFeeSharingPctg;
        /// @notice Hashes of anchor blocks for verification (length <= type(uint16).max)
        /// @custom:encode max-size=512
        bytes32[] anchorBlockHashes;
        /// @notice Array of blob hashes referenced by this batch (length <= type(uint4).max)
        /// @custom:encode max-size=256
        bytes32[] blobHashes;
    }

    /// @notice Authorization data for proving a batch
    /// @dev Contains prover credentials, fee information, and validity constraints
    struct ProverAuth {
        /// @notice Address authorized to prove this batch
        address prover;
        /// @notice Token used for fee payment (ETH not supported)
        /// @custom:encode optional
        address feeToken;
        /// @notice Fee amount (in Gwei)
        uint48 fee;
        /// @notice Expiration timestamp (0 = no expiration)
        /// @custom:encode optional
        uint48 validUntil;
        /// @notice Batch ID restriction (0 = any batch)
        /// @custom:encode optional
        uint48 batchId;
        /// @notice Cryptographic signature authorizing the prover (length <= type(uint10).max)
        /// @custom: max size 128
        bytes signature;
    }

    /// @notice Metadata for building and validating a batch
    /// @dev Contains all necessary information for batch construction and verification
    struct BatchBuildMetadata {
        /// @notice Hash of all transactions in the batch
        bytes32 txsHash;
        /// @notice Array of blob hashes referenced by this batch
        /// @custom:encode max-size=256
        bytes32[] blobHashes;
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
        /// @notice Hashes of anchor blocks for verification
        /// @custom:encode max-size=512
        bytes32[] anchorBlockHashes;
        /// @notice Array of blocks contained in this batch
        /// @custom:encode max-size=512
        Block[] blocks;
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

    /// @notice Extra data to be embedded into each block header.
    /// @dev This struct needs to be encoded into the least significant 128 bits of the header's
    /// extraData field.
    struct HeaderExtraInfo {
        /// @notice Percentage of base fee shared with validators (0-100)
        uint8 sharingPctg;
        /// @notice Whether this is a forced inclusion batch
        bool isForcedInclusion;
        /// @notice Gas issuance per second for this batch
        uint32 gasIssuancePerSecond;
    }

    /// @notice Complete metadata for a batch combining all phases
    /// @dev Aggregates build, propose, and prove metadata for batch processing
    struct BatchMetadata {
        /// @notice Metadata for batch proving operations
        BatchProveMetadata proveMeta;
        /// @notice Metadata for batch proposal validation
        BatchProposeMetadata proposeMeta;
        /// @notice Metadata for batch building and validation
        BatchBuildMetadata buildMeta;
    }

    /// @notice Evidence structure for batch proposal metadata validation
    /// @dev Contains hashes and metadata needed to verify batch proposals
    struct ProposeBatchEvidence {
        /// @notice Left hash for merkle proof verification
        bytes32 leftHash;
        /// @notice Hash of the prove metadata
        bytes32 proveMetaHash;
        /// @notice Proposal metadata to be validated
        BatchProposeMetadata proposeMeta;
    }

    /// @notice Input structure for batch proving operations
    /// @dev Contains all data needed to prove a batch transition
    struct ProveBatchInput {
        /// @notice Left hash for merkle proof verification
        bytes32 leftHash;
        /// @notice Hash of the propose metadata
        bytes32 proposeMetaHash;
        /// @notice Metadata for the proving operation
        BatchProveMetadata proveMeta;
        /// @notice State transition to be proven
        Transition tran;
    }

    /// @notice Represents a state transition to be proven
    /// @dev Contains the essential data for proving a batch's state change
    struct Transition {
        /// @notice ID of the batch containing this transition
        uint48 batchId;
        /// @notice Hash of the parent block
        bytes32 parentHash;
        /// @notice Hash of the current block
        bytes32 blockHash;
        /// @notice New state root after this transition
        bytes32 stateRoot;
    }

    /// @notice Enumeration for proof submission timing
    /// @dev Determines the validation rules and rewards for proof submission
    enum ProofTiming {
        /// @notice Proof submitted after extended proving window expired
        OutOfExtendedProvingWindow,
        /// @notice Proof submitted within normal proving window
        InProvingWindow,
        /// @notice Proof submitted within extended proving window
        InExtendedProvingWindow
    }

    /// @notice Metadata for a transition proof
    /// @dev Contains all information about a submitted transition proof
    struct TransitionMeta {
        /// @notice ID of the batch
        uint48 batchId;
        /// @notice Timestamp when the transition is proved at
        uint48 provedAt;
        /// @notice Address that submitted the proof
        address prover;
        /// @notice Timing category of the proof submission
        ProofTiming proofTiming;
        /// @notice Hash of the block for this transition
        bytes32 blockHash;
        /// @notice State root after this transition
        /// @custom:encode optional
        bytes32 stateRoot;
        /// @notice ID of the last block in the batch
        uint48 lastBlockId;
        /// @notice how many batches this transition covers
        uint8 span;
        /// @notice Bond amount for provability guarantee (in Gwei)
        uint48 provabilityBond;
        /// @notice Bond amount for liveness guarantee (in Gwei)
        uint48 livenessBond;
    }

    /// @notice Struct representing transition storage
    /// @dev Uses 2 storage slots per transition for gas efficiency
    struct TransitionState {
        /// @notice Packed batch ID and partial parent hash for storage efficiency
        uint256 batchIdAndPartialParentHash;
        /// @notice Hash of the transition metadata
        bytes32 metaHash;
    }

    /// @notice Summary of the current protocol state
    /// @dev Contains key metrics and identifiers for protocol operation
    struct Summary {
        /// @notice ID to be assigned to the next batch
        uint48 nextBatchId;
        /// @notice ID of the last block synced from L1
        uint48 lastSyncedBlockId;
        /// @notice Timestamp of the last sync operation
        uint48 lastSyncedAt;
        /// @notice ID of the last batch that was verified
        uint48 lastVerifiedBatchId;
        /// @notice ID of the last block that was verified
        uint48 lastVerifiedBlockId;
        /// @notice Timestamp when gas issuance rate was last updated
        uint48 gasIssuanceUpdatedAt;
        /// @notice Current gas issuance rate per second
        uint32 gasIssuancePerSecond;
        /// @notice Hash of the last verified block
        bytes32 lastVerifiedBlockHash;
        /// @notice Hash of the last batch metadata
        bytes32 lastBatchMetaHash;
    }

    /// @notice Fork activation heights for protocol upgrades
    /// @dev All heights are L1 block numbers when forks activate
    struct ForkHeights {
        /// @notice Ontake fork activation height
        uint64 ontake;
        /// @notice Pacaya fork activation height
        uint64 pacaya;
        /// @notice Shasta fork activation height
        uint64 shasta;
        /// @notice Unzen fork activation height
        uint64 unzen;
        /// @notice Etna fork activation height
        uint64 etna;
        /// @notice Fuji fork activation height
        uint64 fuji;
    }

    /// @notice Configuration parameters for the Taiko protocol
    /// @dev Contains all configurable values for protocol operation
    struct Config {
        /// @notice Chain ID of the L2 network
        uint64 chainId;
        /// @notice Size of the ring buffer for batch storage
        uint24 batchRingBufferSize;
        /// @notice Maximum number of batches to verify in one operation
        /// @custom:encode max-size:63
        uint8 maxBatchesToVerify;
        /// @notice Bond amount for liveness guarantee (in Gwei)
        uint48 livenessBond;
        /// @notice Bond amount for provability guarantee (in Gwei)
        uint48 provabilityBond;
        /// @notice Interval for state root synchronization
        uint8 stateRootSyncInternal;
        /// @notice Maximum allowed offset for anchor block height
        uint16 maxAnchorHeightOffset;
        /// @notice Duration of the normal proving window (in L1 blocks)
        uint24 provingWindow;
        /// @notice Duration of the extended proving window (in L1 blocks)
        uint24 extendedProvingWindow;
        /// @notice Cooldown period before next operation (in L1 blocks)
        uint24 cooldownWindow;
        /// @notice Percentage of bond given as reward (0-100)
        uint8 bondRewardPtcg;
        /// @notice Fork activation heights
        ForkHeights forkHeights;
        /// @notice Address of the token used for bonds
        address bondToken;
        /// @notice Address of the forced inclusion store contract
        address forcedInclusionStore;
        /// @notice Address of the preconf whitelist contract
        address preconfWhitelist;
        /// @notice Address of the proof verifier contract
        address verifier;
        /// @notice Address of the signal service contract
        address signalService;
        /// @notice Delay before gas issuance updates take effect
        uint16 gasIssuanceUpdateDelay;
        /// @notice Percentage of base fee shared with validators (0-100)
        uint8 baseFeeSharingPctg;
    }

    /// @notice State variables for the Taiko protocol contract
    /// @dev Contains all persistent state including mappings and storage gaps for upgrades
    struct State {
        /// @notice Ring buffer for proposed and verified batch metadata hashes
        mapping(uint256 batchId_mod_batchRingBufferSize => bytes32 metaHash) batches;
        /// @notice Mapping from batch ID and parent hash to transition metadata hash
        mapping(uint256 batchId => mapping(bytes32 parentHash => bytes32 metahash))
            transitionMetaHashes;
        /// @notice Ring buffer for transition states
        mapping(
            uint256 batchId_mod_batchRingBufferSize
                => mapping(uint256 thisValueIsAlways1 => TransitionState ts)
        ) transitions;
        /// @notice Hash of the current protocol summary (storage slot 4)
        bytes32 summaryHash;
        /// @notice Deprecated statistics field (storage slot 5)
        bytes32 __deprecatedStats1;
        /// @notice Deprecated statistics field (storage slot 6)
        bytes32 __deprecatedStats2;
        /// @notice Mapping of account addresses to their bond balances
        mapping(address account => uint256 bond) bondBalance;
        /// @notice Storage gap for future upgrades
        uint256[43] __gap;
    }

    /// @notice Emitted when a new batch is proposed
    /// @param lastProposedBatchId The id of the last proposed batch
    /// @param proposeInputs The calldata inputs for propose4 function. Note that when the propose4
    /// function is called by an EOA, the proposeInputs will be empty.
    /// @param batchContexts The array of batch context encoded as bytes encoded as bytes
    /// @param summary The updated protocol summary encoded as bytes
    event Proposed(
        uint256 indexed lastProposedBatchId, bytes proposeInputs, bytes batchContexts, bytes summary
    );

    /// @notice Emitted when a batch transition is proven
    /// @param aggregatedBatchHash The hash of the aggregated batch
    /// @param tranMetas The transition metadata encoded as bytes
    event Proved(bytes32 aggregatedBatchHash, bytes tranMetas);

    /// @notice Emitted when a batch is verified and finalized
    /// @param batchId The unique identifier of the verified batch
    /// @param lastBlockId The unique identifier of the last block in the batch
    /// @param lastBlockHash The hash of the last block in the batch
    event Verified(uint256 indexed batchId, uint256 lastBlockId, bytes32 lastBlockHash);

    /// @notice Proposes and verifies batches
    /// @param _inputs The inputs to propose and verify batches that can be decoded into
    /// (IInbox.Summary
    /// memory, IInbox.Batch[] memory, IInbox.ProposeBatchEvidence memory, IInbox.TransitionMeta[]
    /// memory)
    /// @custom:encode max-size:7 for decoded IInbox.Batch[]
    function propose4(bytes calldata _inputs) external;

    /// @notice Proves batch transitions using cryptographic proofs
    /// @dev Validates and processes cryptographic proofs for batch state transitions
    /// @param _inputs encoded IInbox.ProveBatchInput[]
    /// @param _proof The cryptographic proof data for validation
    function prove4(bytes calldata _inputs, bytes calldata _proof) external;
}
