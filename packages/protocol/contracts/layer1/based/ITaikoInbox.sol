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
    struct BlockParamsV3 {
        bytes32 parentMetaHash;
        uint64 anchorBlockId;
        bytes32 anchorInput;
        uint64 timestamp;
        uint32 txListOffset;
        uint32 txListSize;
        uint8 blobIndex;
        bytes32[] signalSlots;
    }

    struct BlockMetadataV3 {
        bytes32 difficulty;
        bytes32 txListHash;
        bytes32 extraData;
        address coinbase;
        uint64 blockId;
        uint32 gasLimit;
        uint64 timestamp;
        bytes32 parentMetaHash;
        address proposer;
        uint96 livenessBond;
        uint64 proposedAt; // Used by node/client post block proposal.
        uint64 proposedIn; // Used by node/client post block proposal.
        uint32 txListOffset;
        uint32 txListSize;
        uint8 blobIndex;
        uint64 anchorBlockId;
        bytes32 anchorBlockHash;
        bytes32[] signalSlots;
        bytes32 anchorInput;
        LibSharedData.BaseFeeConfig baseFeeConfig;
    }

    /// @notice Struct representing transition to be proven.
    struct TransitionV3 {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    /// @notice 3 slots used.
    struct BlockV3 {
        bytes32 metaHash; // slot 1
        address _reserved2;
        uint96 _reserved3;
        uint64 blockId; // slot 3
        uint64 timestamp;
        uint64 anchorBlockId;
        uint24 nextTransitionId;
        bool _reserved1;
        // The ID of the transaction that is used to verify this block. However, if this block is
        // not verified as the last block in a batch, verifiedTransitionId will remain zero.
        uint24 verifiedTransitionId;
    }

    /// @notice Forge is only able to run coverage in case the contracts by default capable of
    /// compiling without any optimization (neither optimizer runs, no compiling --via-ir flag).
    /// @notice In order to resolve stack too deep without optimizations, we needed to introduce
    /// outsourcing vars into structs below.
    struct Stats1 {
        uint64 __reserved1;
        uint64 __reserved2;
        uint64 lastSyncedBlockId;
        uint64 lastSyncedAt;
    }

    struct Stats2 {
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        bool paused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    struct ForkHeights {
        uint64 ontake;
        uint64 pacaya;
    }

    /// @notice Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct ConfigV3 {
        /// @notice The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        /// @notice The maximum number of verifications allowed when a block is proposed or proved.
        uint64 blockMaxProposals;
        /// @notice Size of the block ring buffer, allowing extra space for proposals.
        uint64 blockRingBufferSize;
        /// @notice The maximum number of verifications allowed when a block is proposed or proved.
        uint64 maxBlocksToVerify;
        /// @notice The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        /// @notice The amount of Taiko token as a prover liveness bond.
        uint96 livenessBond;
        /// @notice The number of L2 blocks between each L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        /// @notice The max differences of the anchor height and the current block number.
        uint64 maxAnchorHeightOffset;
        /// @notice Base fee configuration
        LibSharedData.BaseFeeConfig baseFeeConfig;
        /// @notice The proving window in seconds.
        uint16 provingWindow;
        /// @notice The maximum number of signals to be received by TaikoL2.
        uint8 maxSignalsToReceive;
        /// @notice Historical heights of the forks.
        ForkHeights forkHeights;
    }

    /// @notice Struct holding the state variables for the {Taiko} contract.
    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint256 blockId_mod_blockRingBufferSize => BlockV3 blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint256 blockId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint256 blockId_mod_blockRingBufferSize
                => mapping(uint24 transitionId => TransitionV3 ts)
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

    /// @notice Emitted when a block is synced.
    /// @param stats1 The Stats1 data structure.
    event Stats1Updated(Stats1 stats1);

    /// @notice Emitted when some state variable values changed.
    /// @param stats2 The Stats2 data structure.
    event Stats2Updated(Stats2 stats2);

    /// @notice Emitted when multiple blocks are proposed.
    /// @param metas The metadata of the proposed blocks.
    /// @param calldataUsed Whether calldata is used for txList DA.
    /// @param txListInCalldata The tx list in calldata.
    event BlocksProposedV3(BlockMetadataV3[] metas, bool calldataUsed, bytes txListInCalldata);

    /// @notice Emitted when multiple transitions are proved.
    /// @param verifier The address of the verifier.
    /// @param transitions The transitions data.
    event BlocksProvedV3(address verifier, uint64[] blockIds, TransitionV3[] transitions);

    /// @notice Emitted when a transition is overwritten by another one.
    /// @param blockId The block ID.
    /// @param tran The transition data that has been overwritten.
    event TransitionOverwrittenV3(uint64 blockId, TransitionV3 tran);

    /// @notice Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param blockHash The hash of the verified block.
    event BlockVerifiedV3(uint64 blockId, bytes32 blockHash);

    error AnchorBlockIdSmallerThanParent();
    error AnchorBlockIdTooSmall();
    error AnchorBlockIdTooLarge();
    error ArraySizesMismatch();
    error BlobIndexZero();
    error BlobNotFound();
    error BlockNotFound();
    error BlockVerified();
    error ContractPaused();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error EtherNotPaidAsBond();
    error InsufficientBond();
    error InvalidForkHeight();
    error InvalidGenesisBlockHash();
    error InvalidTransitionBlockHash();
    error InvalidTransitionParentHash();
    error InvalidTransitionStateRoot();
    error MetaHashMismatch();
    error MsgValueNotZero();
    error NoBlocksToPropose();
    error NoBlocksToProve();
    error NotPreconfRouter();
    error ParentMetaHashMismatch();
    error ProverNotPermitted();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBlocks();
    error TooManySignals();
    error TransitionNotFound();

    /// @notice Proposes multiple blocks with specified parameters and transaction list.
    /// @param _proposer The address of the proposer, which is set by the PreconfTaskManager if
    /// enabled; otherwise, it must be address(0).
    /// @param _coinbase The address that will receive the block rewards; defaults to the proposer's
    /// address if set to address(0).
    /// @param _blockParams An array containing the parameters for each block being proposed.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return An array of block metadata for each block proposed.
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        BlockParamsV3[] calldata _blockParams,
        bytes calldata _txList
    )
        external
        returns (BlockMetadataV3[] memory);

    /// @notice Proves state transitions for multiple blocks with a single aggregated proof.
    /// @param _metas Array of metadata for each block being proved.
    /// @param _transitions Array of block transitions to be proved.
    /// @param proof The aggregated cryptographic proof proving the blocks transitions.
    function proveBlocksV3(
        BlockMetadataV3[] calldata _metas,
        TransitionV3[] calldata _transitions,
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

    /// @notice Retrieves data about a specific block.
    /// @param _blockId The ID of the block to retrieve.
    /// @return blk_ The block data.
    function getBlockV3(uint64 _blockId) external view returns (BlockV3 memory blk_);

    /// @notice Retrieves a specific transition by block ID and transition ID. This function may
    /// revert if the transition is not found.
    /// @param _blockId The block ID.
    /// @param _tid The transition ID.
    /// @return The specified transition.
    function getTransitionV3(
        uint64 _blockId,
        uint24 _tid
    )
        external
        view
        returns (ITaikoInbox.TransitionV3 memory);

    /// @notice Retrieves the transition used for the last verified block.
    /// @return blockId_ The block ID of the last verified transition.
    /// @return tran_ The last verified transition.
    function getLastVerifiedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_);

    /// @notice Retrieves the transition used for the last synced block.
    /// @return blockId_ The block ID of the last synced transition.
    /// @return tran_ The last synced transition.
    function getLastSyncedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_);

    /// @notice Retrieves the transition used for verifying a block.
    /// @param _blockId The block ID.
    /// @return The transition used for verifying the block.
    function getBlockVerifyingTransition(uint64 _blockId)
        external
        view
        returns (TransitionV3 memory);

    /// @notice Retrieves the current protocol configuration.
    /// @return The current configuration.
    function getConfigV3() external view returns (ConfigV3 memory);
}
