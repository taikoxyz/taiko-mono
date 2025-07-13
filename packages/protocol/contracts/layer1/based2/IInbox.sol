// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IInbox {
    struct Block {
        // the max number of transactions in this block. Note that if there are not enough
        // transactions in calldata or blobs, the block will contain as many transactions as
        // possible.
        uint16 numTransactions;
        // The time difference (in seconds) between the timestamp of this block and
        // the timestamp of the parent block in the same batch. For the first block in a batch,
        // there is no parent block in the same batch, so the time shift should be 0.
        uint8 timeShift;
        // Optional anchor block id.
        uint48 anchorBlockId;
        // The number of signals in this block.
        uint8 numSignals;
        // Whether this block has an anchor block.
        bool hasAnchor;
    }

    struct Blobs {
        // The hashes of the blob. Note that if this array is not empty.  `firstBlobIndex` and
        // `numBlobs` must be 0.
        bytes32[] hashes;
        // The index of the first blob in this batch.
        uint8 firstBlobIndex;
        // The number of blobs in this batch. Blobs are initially concatenated and subsequently
        // decompressed via Zlib.
        uint8 numBlobs;
        // The byte offset of the blob in the batch.
        uint32 byteOffset;
        // The byte size of the blob.
        uint32 byteSize;
        // The block number when the blob was created. This value is only non-zero when
        // `blobHashes` are non-empty.
        uint48 createdIn;
    }

    struct Batch {
        address proposer;
        address coinbase;
        uint48 lastBlockTimestamp;
        uint32 gasIssuancePerSecond;
        bool isForcedInclusion;
        bytes proverAuth;
        bytes32[] signalSlots;
        uint48[] anchorBlockIds;
        Block[] blocks;
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
        uint32 blockMaxGasLimit;
        uint48 livenessBond;
        uint48 provabilityBond;
        uint8 baseFeeSharingPctg;
        bytes32[] anchorBlockHashes; // length <= type(uint16).max
        bytes32[] blobHashes; // length <= type(uint16).max
    }

    struct ProverAuth {
        address prover;
        address feeToken;
        uint96 fee;
        uint64 validUntil; // optional
        uint64 batchId; // optional
        bytes signature;
    }

    struct BatchBuildMetadata {
        bytes32 txsHash;
        bytes32[] blobHashes;
        bytes32 extraData;
        address coinbase;
        uint48 proposedIn;
        uint48 blobCreatedIn;
        uint48 blobByteOffset;
        uint48 blobByteSize;
        uint48 gasLimit;
        uint48 lastBlockId;
        uint48 lastBlockTimestamp;
        uint48[] anchorBlockIds;
        bytes32[] anchorBlockHashes;
        Block[] blocks;
    }

    struct BatchProposeMetadata {
        uint48 lastBlockTimestamp;
        uint48 lastBlockId;
        uint48 lastAnchorBlockId;
    }

    struct BatchProveMetadata {
        address proposer;
        address prover;
        uint48 proposedAt;
        uint48 firstBlockId;
        uint48 lastBlockId;
        uint48 livenessBond;
        uint48 provabilityBond;
    }

    struct BatchMetadata {
        // [batchId] [buildMetaHash] [proposeMetaHash] [proveMetaHash]
        BatchProveMetadata proveMeta;
        BatchProposeMetadata proposeMeta;
        BatchBuildMetadata buildMeta;
    }

    struct BatchProposeMetadataEvidence {
        bytes32 idAndBuildHash; // aka leftHash
        bytes32 proveMetaHash;
        BatchProposeMetadata proposeMeta;
    }

    struct BatchProveInput {
        bytes32 idAndBuildHash; // aka leftHash
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

    // This struct takes 109 bytes if packed
    struct TransitionMeta {
        bytes32 blockHash; // 32 bytes
        bytes32 stateRoot; // 32 bytes
        address prover; // 20 bytes
        ProofTiming proofTiming; // 1 byte
        uint48 createdAt; // 6 bytes
        bool byAssignedProver; // 1 byte
        uint48 lastBlockId; // 6 bytes
        uint48 provabilityBond; // 12 bytes
        uint48 livenessBond; // 12 bytes
    }

    //  @notice Struct representing transition storage
    /// @notice 2 slots used for each transition.
    struct TransitionState {
        uint256 batchIdAndPartialParentHash;
        bytes32 metaHash;
    }

    struct Summary {
        uint48 numBatches;
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

    /// @notice Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct Config {
        /// @notice The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        /// @notice The maximum number of unverified batches the protocol supports.
        uint64 maxUnverifiedBatches;
        /// @notice Size of the batch ring buffer, allowing extra space for proposals.
        uint64 batchRingBufferSize;
        /// @notice The maximum number of verifications allowed when a batch is proposed or proved.
        uint64 maxBatchesToVerify;
        /// @notice The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        /// @notice The amount of Taiko token as a prover liveness bond per batch.
        uint48 livenessBond;
        /// @notice The amount of Taiko token as a proposer's provability bond per batch.
        uint48 provabilityBond;
        /// @notice The number of batches between two L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice The proving window in seconds.
        uint16 provingWindow;
        /// @notice The extended proving window in seconds before provability bond is used as
        /// reward.
        uint24 extendedProvingWindow;
        /// @notice The time required for a transition to be used for verifying a batch.
        uint24 cooldownWindow;
        uint8 bondRewardPtcg; // 0-100
        /// @notice The maximum number of signals to be received by TaikoL2.
        uint8 maxSignalsToReceive;
        /// @notice The maximum number of blocks per batch.
        uint16 maxBlocksPerBatch;
        /// @notice Historical heights of the forks.
        ForkHeights forkHeights;
        /// @notice The token used for bonding.
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
    /// @param _packedTrans The packed transition metadata for verification
    /// @return The updated summary
    function propose4(
        bytes calldata _packedSummary,
        bytes calldata _packedBatches,
        bytes calldata _packedEvidence,
        bytes calldata _packedTrans
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
