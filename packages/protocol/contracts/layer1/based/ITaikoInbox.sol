// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";

/// @title TaikoInbox
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR). The tier-based proof system and
/// contestation mechanisms have been removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with proof type management
///   delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:security-contact security@taiko.xyz
interface ITaikoInbox {
    struct BlockParams {
        // the max number of transactions in this block. Note that if there are not enough
        // transactions in calldata or blobs, the block will contains as many transactions as
        // possible.
        uint16 numTransactions;
        // The time difference (in seconds) between the timestamp of this block and
        // the timestamp of the parent block in the same batch. For the first block in a batch,
        // there is not parent block in the same batch, so the time shift should be 0.
        uint8 timeShift;
        // Signals sent on L1 and need to sync to this L2 block.
        bytes32[] signalSlots;
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
        uint64 createdIn;
    }

    struct BatchParams {
        address proposer;
        address coinbase;
        bytes32 parentMetaHash;
        uint64 anchorBlockId;
        uint64 lastBlockTimestamp;
        bool revertIfNotFirstProposal;
        // Specifies the number of blocks to be generated from this batch.
        BlobParams blobParams;
        BlockParams[] blocks;
    }

    /// @dev This struct holds batch information essential for constructing blocks offchain, but it
    /// does not include data necessary for batch proving.
    struct BatchInfo {
        bytes32 txsHash;
        // Data to build L2 blocks
        BlockParams[] blocks;
        bytes32[] blobHashes;
        bytes32 extraData;
        address coinbase;
        uint64 proposedIn; // Used by node/client
        uint64 blobCreatedIn;
        uint32 blobByteOffset;
        uint32 blobByteSize;
        uint32 gasLimit;
        uint64 lastBlockId;
        uint64 lastBlockTimestamp;
        // Data for the L2 anchor transaction, shared by all blocks in the batch
        uint64 anchorBlockId;
        // corresponds to the `_anchorStateRoot` parameter in the anchor transaction.
        // The batch's validity proof shall verify the integrity of these two values.
        bytes32 anchorBlockHash;
        LibSharedData.BaseFeeConfig baseFeeConfig;
    }

    /// @dev This struct holds batch metadata essential for proving the batch.
    struct BatchMetadata {
        bytes32 infoHash;
        address proposer;
        uint64 batchId;
        uint64 proposedAt; // Used by node/client
    }

    /// @notice Struct representing transition to be proven.
    struct Transition {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    //  @notice Struct representing transition storage
    /// @notice 4 slots used.
    struct TransitionState {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
        address prover;
        bool inProvingWindow;
        uint48 createdAt;
    }

    /// @notice 3 slots used.
    struct Batch {
        bytes32 metaHash; // slot 1
        uint64 lastBlockId; // slot 2
        uint96 reserved3;
        uint96 livenessBond;
        uint64 batchId; // slot 3
        uint64 lastBlockTimestamp;
        uint64 anchorBlockId;
        uint24 nextTransitionId;
        uint8 reserved4;
        // The ID of the transaction that is used to verify this batch. However, if this batch is
        // not verified as the last one in a transaction, verifiedTransitionId will remain zero.
        uint24 verifiedTransitionId;
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

    struct ForkHeights {
        uint64 ontake; // measured with block number.
        uint64 pacaya; // measured with the batch Id, not block number.
        uint64 shasta; // measured with the batch Id, not block number.
        uint64 unzen; // measured with the batch Id, not block number.
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
        uint96 livenessBondBase;
        /// @notice The amount of Taiko token as a prover liveness bond per block. This field is
        /// deprecated and its value will be ignored.
        uint96 livenessBondPerBlock;
        /// @notice The number of batches between two L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice Base fee configuration
        LibSharedData.BaseFeeConfig baseFeeConfig;
        /// @notice The proving window in seconds.
        uint16 provingWindow;
        /// @notice The time required for a transition to be used for verifying a batch.
        uint24 cooldownWindow;
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
        mapping(uint256 batchId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint256 batchId_mod_batchRingBufferSize
                => mapping(uint24 transitionId => TransitionState ts)
        ) transitions;
        bytes32 __reserve1; // slot 4 - was used as a ring buffer for Ether deposits
        Stats1 stats1; // slot 5
        Stats2 stats2; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
    }

    /// @notice Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a token is credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 amount);

    /// @notice Emitted when a token is debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 amount);

    /// @notice Emitted when a batch is synced.
    /// @param stats1 The Stats1 data structure.
    event Stats1Updated(Stats1 stats1);

    /// @notice Emitted when some state variable values changed.
    /// @param stats2 The Stats2 data structure.
    event Stats2Updated(Stats2 stats2);

    /// @notice Emitted when a batch is proposed.
    /// @param info The info of the proposed batch.
    /// @param meta The metadata of the proposed batch.
    /// @param txList The tx list in calldata.
    event BatchProposed(BatchInfo info, BatchMetadata meta, bytes txList);

    /// @notice Emitted when multiple transitions are proved.
    /// @param verifier The address of the verifier.
    /// @param transitions The transitions data.
    event BatchesProved(address verifier, uint64[] batchIds, Transition[] transitions);

    /// @notice Emitted when a transition is overwritten by a conflicting one with the same parent
    /// hash but different block hash or state root.
    /// @param batchId The batch ID.
    /// @param oldTran The old transition overwritten.
    /// @param newTran The new transition.
    event ConflictingProof(uint64 batchId, TransitionState oldTran, Transition newTran);

    /// @notice Emitted when a batch is verified.
    /// @param batchId The ID of the verified batch.
    /// @param blockHash The hash of the verified batch.
    event BatchesVerified(uint64 batchId, bytes32 blockHash);

    error AnchorBlockIdSmallerThanParent();
    error AnchorBlockIdTooLarge();
    error AnchorBlockIdTooSmall();
    error ArraySizesMismatch();
    error BatchNotFound();
    error BatchVerified();
    error BeyondCurrentFork();
    error BlobNotFound();
    error BlockNotFound();
    error BlobNotSpecified();
    error ContractPaused();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error EtherNotPaidAsBond();
    error FirstBlockTimeShiftNotZero();
    error ForkNotActivated();
    error InsufficientBond();
    error InvalidBlobCreatedIn();
    error InvalidBlobParams();
    error InvalidGenesisBlockHash();
    error InvalidParams();
    error InvalidTransitionBlockHash();
    error InvalidTransitionParentHash();
    error InvalidTransitionStateRoot();
    error MetaHashMismatch();
    error MsgValueNotZero();
    error NoBlocksToProve();
    error NotFirstProposal();
    error NotInboxWrapper();
    error ParentMetaHashMismatch();
    error SameTransition();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error TooManyBlocks();
    error TooManySignals();
    error TransitionNotFound();
    error ZeroAnchorBlockHash();

    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded parameters.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_, uint64 lastBlockId_);

    /// @notice Proves state transitions for multiple batches with a single aggregated proof.
    /// @param _params ABI-encoded parameter containing:
    /// - metas: Array of metadata for each batch being proved.
    /// - transitions: Array of batch transitions to be proved.
    /// @param _proof The aggregated cryptographic proof proving the batches transitions.
    function proveBatches(bytes calldata _params, bytes calldata _proof) external;

    /// @notice Deposits TAIKO tokens into the contract to be used as liveness bond.
    /// @param _amount The amount of TAIKO tokens to deposit.
    function depositBond(uint256 _amount) external payable;

    /// @notice Withdraws a specified amount of TAIKO tokens from the contract.
    /// @param _amount The amount of TAIKO tokens to withdraw.
    function withdrawBond(uint256 _amount) external;

    /// @notice Returns the TAIKO token balance of a specific user.
    /// @param _user The address of the user.
    /// @return The TAIKO token balance of the user.
    function bondBalanceOf(address _user) external view returns (uint256);

    /// @notice Retrieves the Bond token address. If Ether is used as bond, this function returns
    /// address(0).
    /// @return The Bond token address.
    function bondToken() external view returns (address);

    /// @notice Retrieves the first set of protocol statistics.
    /// @return Stats1 structure containing the statistics.
    function getStats1() external view returns (Stats1 memory);

    /// @notice Retrieves the second set of protocol statistics.
    /// @return Stats2 structure containing the statistics.
    function getStats2() external view returns (Stats2 memory);

    /// @notice Retrieves data about a specific batch.
    /// @param _batchId The ID of the batch to retrieve.
    /// @return batch_ The batch data.
    function getBatch(uint64 _batchId) external view returns (Batch memory batch_);

    /// @notice Retrieves a specific transition by batch ID and transition ID. This function may
    /// revert if the transition is not found.
    /// @param _batchId The batch ID.
    /// @param _tid The transition ID.
    /// @return The specified transition state.
    function getTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (ITaikoInbox.TransitionState memory);

    /// @notice Retrieves a specific transition by batch ID and parent Hash. This function may
    /// revert if the transition is not found.
    /// @param _batchId The batch ID.
    /// @param _parentHash The parent hash.
    /// @return The specified transition state.
    function getTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (ITaikoInbox.TransitionState memory);

    /// @notice Retrieves the transition used for the last verified batch.
    /// @return batchId_ The batch ID of the last verified transition.
    /// @return blockId_ The block ID of the last verified block.
    /// @return ts_ The last verified transition.
    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_);

    /// @notice Retrieves the transition used for the last synced batch.
    /// @return batchId_ The batch ID of the last synced transition.
    /// @return blockId_ The block ID of the last synced block.
    /// @return ts_ The last synced transition.
    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_);

    /// @notice Retrieves the transition used for verifying a batch.
    /// @param _batchId The batch ID.
    /// @return The transition used for verifying the batch.
    function getBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (TransitionState memory);

    /// @notice Retrieves the current protocol configuration.
    /// @return The current configuration.
    function pacayaConfig() external view returns (Config memory);
}
