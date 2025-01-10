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
        uint16 numTransactions;
        uint8 timeThift;
    }

    struct BatchParams {
        bytes32 parentMetaHash;
        uint64 anchorBlockId;
        bytes32 anchorInput;
        uint64 timestamp;
        uint32 txListOffset;
        uint32 txListSize;
        uint8[] blobIndices;
        bytes32[] signalSlots;
        BlockParams[] blocks;
    }

    struct BatchMetadata {
        bytes32 txListHash;
        bytes32 extraData;
        address coinbase;
        uint64 batchId;
        uint32 gasLimit;
        uint64 timestamp;
        bytes32 parentMetaHash;
        address proposer;
        uint96 livenessBond;
        uint64 proposedAt; // Used by node/client
        uint64 proposedIn; // Used by node/client
        uint32 txListOffset;
        uint32 txListSize;
        uint8[] blobIndices;
        uint64 anchorBlockId;
        bytes32 anchorBlockHash;
        bytes32[] signalSlots;
        BlockParams[] blocks;
        bytes32 anchorInput;
        LibSharedData.BaseFeeConfig baseFeeConfig;
    }

    /// @notice Struct representing transition to be proven.
    struct Transition {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    /// @notice 3 slots used.
    struct Batch {
        bytes32 metaHash; // slot 1
        address _reserved2;
        uint96 _reserved3;
        uint64 batchId; // slot 3
        uint64 timestamp;
        uint64 anchorBlockId;
        uint24 nextTransitionId;
        uint8 numSubBlocks;
        // The ID of the transaction that is used to verify this batch. However, if this batch is
        // not verified as the last one in a transaction, verifiedTransitionId will remain zero.
        uint24 verifiedTransitionId;
    }

    /// @notice Forge is only able to run coverage in case the contracts by default capable of
    /// compiling without any optimization (neither optimizer runs, no compiling --via-ir flag).
    struct Stats1 {
        uint64 __reserved1;
        uint64 __reserved2;
        uint64 lastSyncedBatch;
        uint64 lastSyncedAt;
    }

    struct Stats2 {
        uint64 numBatches;
        uint64 lastVerifiedBatch;
        bool paused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    struct ForkHeights {
        uint64 ontake;
        uint64 pacaya;
    }

    /// @notice Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct Config {
        /// @notice The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        /// @notice The maximum number of verifications allowed when a batch is proposed or proved.
        uint64 maxBatchProposals;
        /// @notice Size of the batch ring buffer, allowing extra space for proposals.
        uint64 batchRingBufferSize;
        /// @notice The maximum number of verifications allowed when a batch is proposed or proved.
        uint64 maxBatchesToVerify;
        /// @notice The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        /// @notice The amount of Taiko token as a prover liveness bond.
        uint96 livenessBond;
        /// @notice The number of batches between two L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice Base fee configuration
        LibSharedData.BaseFeeConfig baseFeeConfig;
        /// @notice The proving window in seconds.
        uint16 provingWindow;
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
            uint256 batchId_mod_batchRingBufferSize => mapping(uint24 transitionId => Transition ts)
        ) transitions;
        bytes32 __reserve1; // Used as a ring buffer for Ether deposits
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
    /// @param meta The metadata of the proposed batch.
    /// @param calldataUsed Whether calldata is used for txList DA.
    /// @param txListInCalldata The tx list in calldata.
    event BatchProposed(BatchMetadata meta, bool calldataUsed, bytes txListInCalldata);

    /// @notice Emitted when multiple transitions are proved.
    /// @param verifier The address of the verifier.
    /// @param transitions The transitions data.
    event BatchesProved(address verifier, uint64[] batchIds, Transition[] transitions);

    /// @notice Emitted when a transition is overwritten by another one.
    /// @param batchId The batch ID.
    /// @param tran The transition data that has been overwritten.
    event TransitionOverwritten(uint64 batchId, Transition tran);

    /// @notice Emitted when a batch is verified.
    /// @param batchId The ID of the verified batch.
    /// @param blockHash The hash of the verified batch.
    event BatchesVerified(uint64 batchId, bytes32 blockHash);

    error AnchorBlockIdSmallerThanParent();
    error AnchorBlockIdTooSmall();
    error AnchorBlockIdTooLarge();
    error ArraySizesMismatch();
    error BatchNotFound();
    error BatchVerified();
    error BlobIndexZero();
    error BlobNotFound();
    error ContractPaused();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error EtherNotPaidAsBond();
    error InsufficientBond();
    error InvalidBlockParams();
    error InvalidForkHeight();
    error InvalidGenesisBlockHash();
    error InvalidTransitionBlockHash();
    error InvalidTransitionParentHash();
    error InvalidTransitionStateRoot();
    error MetaHashMismatch();
    error MsgValueNotZero();
    error NoBlocksToProve();
    error NotPreconfRouter();
    error ParentMetaHashMismatch();
    error ProverNotPermitted();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error TooManySignals();
    error TransitionNotFound();

    /// @notice Proposes a batch of blocks.
    /// @param _proposer The address of the proposer, which is set by the PreconfTaskManager if
    /// enabled; otherwise, it must be address(0).
    /// @param _coinbase The address that will receive the block rewards; defaults to the proposer's
    /// address if set to address(0).
    /// @param _batchParams Batch parameters.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return Batch metadata.
    function proposeBatch(
        address _proposer,
        address _coinbase,
        BatchParams calldata _batchParams,
        bytes calldata _txList
    )
        external
        returns (BatchMetadata memory);

    /// @notice Proves state transitions for multiple batches with a single aggregated proof.
    /// @param _metas Array of metadata for each batch being proved.
    /// @param _transitions Array of batch transitions to be proved.
    /// @param proof The aggregated cryptographic proof proving the batches transitions.
    function proveBatches(
        BatchMetadata[] calldata _metas,
        Transition[] calldata _transitions,
        bytes calldata proof
    )
        external;

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
    /// @return The specified transition.
    function getTransition(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (ITaikoInbox.Transition memory);

    /// @notice Retrieves the transition used for the last verified batch.
    /// @return batchId_ The batch ID of the last verified transition.
    /// @return tran_ The last verified transition.
    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, Transition memory tran_);

    /// @notice Retrieves the transition used for the last synced batch.
    /// @return batchId_ The batch ID of the last synced transition.
    /// @return tran_ The last synced transition.
    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, Transition memory tran_);

    /// @notice Retrieves the transition used for verifying a batch.
    /// @param _batchId The batch ID.
    /// @return The transition used for verifying the batch.
    function getBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (Transition memory);

    /// @notice Retrieves the current protocol configuration.
    /// @return The current configuration.
    function getConfig() external view returns (Config memory);
}
