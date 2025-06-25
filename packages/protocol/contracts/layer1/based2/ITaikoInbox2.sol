// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

interface ITaikoInbox2 {
    struct BlockParams {
        // the max number of transactions in this block. Note that if there are not enough
        // transactions in calldata or blobs, the block will contain as many transactions as
        // possible.
        uint16 numTransactions;
        // The time difference (in seconds) between the timestamp of this block and
        // the timestamp of the parent block in the same batch. For the first block in a batch,
        // there is no parent block in the same batch, so the time shift should be 0.
        uint8 timeShift;
        // Signals sent on L1 and need to sync to this L2 block.
        bytes32[] signalSlots;
        // Optional anchor block id.
        uint48 anchorBlockId;
    }

    struct BlobParams {
        // The hashes of the blob. Note that if this array is not empty.  `firstBlobIndex` and
        // `numBlobs` must be 0.
        bytes32[] blobHashes;
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

    struct BatchParams {
        address proposer;
        address coinbase;
        uint48 lastBlockTimestamp;
        bool revertIfNotFirstProposal;
        bool isForcedInclusion;
        // Specifies the number of blocks to be generated from this batch.
        BlobParams blobParams;
        BlockParams[] blocks;
        bytes proverAuth;
    }

    struct AnchorBlock {
        uint64 blockId;
        bytes32 blockHash;
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
        AnchorBlock[] anchorBlocks;
        BlockParams[] blocks;
        LibSharedData.BaseFeeConfig baseFeeConfig;
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
        uint96 livenessBond;
        uint96 provabilityBond;
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

    struct BatchProveMetadataEvidence {
        bytes32 idAndBuildHash; // aka leftHash
        bytes32 proposeMetaHash;
        BatchProveMetadata proveMeta;
    }

    /// @notice Struct representing transition to be proven.
    struct Transition {
        uint48 batchId;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    enum ProofTiming {
        OutOfExtendedProvingWindow, // 0
        InProvingWindow, // 1
        InExtendedProvingWindow // 2

    }

    struct TransitionMeta {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
        address prover;
        ProofTiming proofTiming;
        uint48 createdAt;
        bool byAssignedProver;
        uint48 lastBlockId;
        uint96 provabilityBond;
        uint96 livenessBond;
    }

    //  @notice Struct representing transition storage
    /// @notice 2 slots used for each transition.
    struct TransitionState {
        bytes32 parentHash;
        bytes32 metaHash;
    }

    struct Batch {
        bytes32 metaHash;
    }

    /// @notice Forge is only able to run coverage in case the contracts by default capable of
    /// compiling without any optimization (neither optimizer runs, no compiling --via-ir flag).
    struct Stats1 {
        uint64 genesisHeight;
        uint64 __reserved2;
        uint64 lastSyncedBatchId;
        uint64 lastSyncedAt;
    }

    struct Stats2 {
        uint64 numBatches;
        uint64 lastVerifiedBatchId;
        bool paused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    struct Summary {
        uint48 numBatches;
        uint48 lastProposedIn;
        uint48 lastUnpausedAt;
        uint48 lastSyncedBlockId;
        uint48 lastSyncedAt;
        uint48 lastVerifiedBatchId;
        bytes32 lastVerifiedBlockHash;
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
        uint96 livenessBond;
        /// @notice The amount of Taiko token as a proposer's provability bond per batch.
        uint96 provabilityBond;
        /// @notice The number of batches between two L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice Base fee configuration
        LibSharedData.BaseFeeConfig baseFeeConfig;
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
    }

    /// @notice Struct holding the state variables for the {Taiko} contract.
    struct State {
        // Ring buffer for proposed batches and a some recent verified batches.
        mapping(uint256 batchId_mod_batchRingBufferSize => Batch batch) batches;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint256 batchId => mapping(bytes32 parentHash => bytes32 metahash))
            transitionMetaHashes;
        // Ring buffer for transitions
        mapping(
            uint256 batchId_mod_batchRingBufferSize
                => mapping(uint256 thisValueIsAlways1 => TransitionState ts)
        ) transitions;
        bytes32 __reserve1; // slot 4 - was used as a ring buffer for Ether deposits
        Stats1 stats1; // slot 5
        Summary summary; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
        bytes32 summaryHash;
    }

    struct ProverAuth {
        address prover;
        address feeToken;
        uint96 fee;
        uint64 validUntil; // optional
        uint64 batchId; // optional
        bytes signature;
    }

    /// @notice Emitted when a batch is synced.
    /// @param summary The Summary data structure.
    /// @param summaryHash The hash of the summary.
    event SummaryUpdated(Summary summary, bytes32 summaryHash);

    /// @notice Emitted when a batch is proposed.
    /// @param batchId The ID of the proposed batch.
    /// @param meta The metadata of the proposed batch.
    event BatchProposed(uint256 batchId, BatchMetadata meta);

    /// @notice Emitted when multiple transitions are proved.
    /// @param verifier The address of the verifier.
    /// @param tranMetas The transition metadata.
    event BatchesProved(address verifier, TransitionMeta[] tranMetas);

    /// @notice Emitted when a batch is verified.
    /// @param batchId The ID of the verified batch.
    /// @param blockHash The hash of the verified batch.
    event BatchesVerified(uint64 batchId, bytes32 blockHash);

    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error ArraySizesMismatch();
    error BatchNotFound();
    error BatchVerified();
    error BeyondCurrentFork();
    error BlobNotFound();
    error BlobNotSpecified();
    error BlockNotFound();
    error ContractPaused();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error EtherAsFeeTokenNotSupportedYet();
    error EtherNotPaidAsBond();
    error FirstBlockTimeShiftNotZero();
    error ForkNotActivated();
    error InsufficientBond();
    error InvalidBatchId();
    error InvalidBlobCreatedIn();
    error InvalidBlobParams();
    error InvalidForcedInclusion();
    error InvalidGenesisBlockHash();
    error InvalidParams();
    error InvalidProver();
    error InvalidSignature();
    error InvalidTransitionBlockHash();
    error InvalidTransitionParentHash();
    error InvalidTransitionStateRoot();
    error InvalidValidUntil();
    error MetaHashMismatch();
    error MsgValueNotZero();
    error NoAnchorBlockIdWithinThisBatch();
    error NoBlocksToProve();
    error NotFirstProposal();
    error NotInboxWrapper();
    error ParentMetaHashMismatch();
    error SameTransition();
    error SignalNotSent();
    error SignatureNotEmpty();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error TooManyBatchesToProve();
    error TooManyBlocks();
    error TooManySignals();
    error TransitionNotFound();
    error ZeroAnchorBlockHash();
}
