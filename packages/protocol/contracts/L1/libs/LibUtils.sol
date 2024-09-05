// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/IAddressResolver.sol";
import "../../common/LibStrings.sol";
import "../../libs/LibMath.sol";
import "../tiers/ITierProvider.sol";
import "../tiers/ITierRouter.sol";
import "../TaikoData.sol";

/// @title LibUtils
/// @notice A library that offers helper functions for the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibUtils {
    using LibMath for uint256;

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the block.
    /// @param blockHash The hash of the verified block.
    /// @param tier The tier ID of the proof.
    event BlockVerifiedV2(
        uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier
    );

    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_GENESIS_HASH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @notice Initializes the Taiko protocol state.
    /// @param _state The state to initialize.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(TaikoData.State storage _state, bytes32 _genesisBlockHash) internal {
        require(_genesisBlockHash != bytes32(0), L1_INVALID_GENESIS_HASH());
        // Initialize state
        _state.slotA.genesisHeight = uint64(block.number);
        _state.slotA.genesisTimestamp = uint64(block.timestamp);
        _state.slotB.numBlocks = 1;

        // Initialize the genesis block
        TaikoData.BlockV2 storage blk = _state.blocks[0];
        blk.nextTransitionId = 2;
        blk.proposedAt = uint64(block.timestamp);
        blk.verifiedTransitionId = 1;
        blk.metaHash = bytes32(uint256(1)); // Give the genesis metahash a non-zero value.

        // Initialize the first state transition
        TaikoData.TransitionState storage ts = _state.transitions[0][1];
        ts.blockHash = _genesisBlockHash;
        ts.prover = address(0);
        ts.timestamp = uint64(block.timestamp);

        emit BlockVerifiedV2({
            blockId: 0,
            prover: address(0),
            blockHash: _genesisBlockHash,
            tier: 0
        });
    }

    /// @dev Retrieves a block based on its ID.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @return blk_ The block storage pointer.
    /// @return slot_ The slot value.
    function getBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId
    )
        internal
        view
        returns (TaikoData.BlockV2 storage blk_, uint64 slot_)
    {
        slot_ = _blockId % _config.blockRingBufferSize;
        blk_ = _state.blocks[slot_];
        require(blk_.blockId == _blockId, L1_INVALID_BLOCK_ID());
    }

    /// @dev Retrieves a block's block hash and state root.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @return blockHash_ The block's block hash.
    /// @return stateRoot_ The block's storage root.
    /// @return verifiedAt_ The timestamp when the block was verified.
    function getBlockInfo(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId
    )
        internal
        view
        returns (bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        (TaikoData.BlockV2 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        if (blk.verifiedTransitionId != 0) {
            TaikoData.TransitionState storage transition =
                _state.transitions[slot][blk.verifiedTransitionId];

            blockHash_ = transition.blockHash;
            stateRoot_ = transition.stateRoot;
            verifiedAt_ = transition.timestamp;
        }
    }

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given transition ID.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @param _tid The transition ID.
    /// @return The state transition pointer.
    function getTransition(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId,
        uint32 _tid
    )
        internal
        view
        returns (TaikoData.TransitionState storage)
    {
        (TaikoData.BlockV2 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        require(_tid != 0 && _tid < blk.nextTransitionId, L1_TRANSITION_NOT_FOUND());
        return _state.transitions[slot][_tid];
    }

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given parent hash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @param _parentHash The parent hash of the block.
    /// @return The state transition pointer.
    function getTransition(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId,
        bytes32 _parentHash
    )
        internal
        view
        returns (TaikoData.TransitionState storage)
    {
        (TaikoData.BlockV2 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        uint24 tid = getTransitionId(_state, blk, slot, _parentHash);
        require(tid != 0, L1_TRANSITION_NOT_FOUND());

        return _state.transitions[slot][tid];
    }

    /// @dev Retrieves the ID of the transition with a given parent hash.
    /// This function will return 0 if the transition is not found.
    /// @param _state Current TaikoData.State.
    /// @param _blk The block storage pointer.
    /// @param _slot The slot value.
    /// @param _parentHash The parent hash of the block.
    /// @return tid_ The transition ID.
    function getTransitionId(
        TaikoData.State storage _state,
        TaikoData.BlockV2 storage _blk,
        uint64 _slot,
        bytes32 _parentHash
    )
        internal
        view
        returns (uint24 tid_)
    {
        if (_state.transitions[_slot][1].key == _parentHash) {
            tid_ = 1;
            require(tid_ < _blk.nextTransitionId, L1_UNEXPECTED_TRANSITION_ID());
        } else {
            tid_ = _state.transitionIds[_blk.blockId][_parentHash];
            require(tid_ == 0 || tid_ < _blk.nextTransitionId, L1_UNEXPECTED_TRANSITION_ID());
        }
    }

    /// @dev Checks if the current timestamp is past the deadline.
    /// @param _tsTimestamp The timestamp to check.
    /// @param _lastUnpausedAt The last unpaused timestamp.
    /// @param _windowMinutes The window in minutes.
    /// @return True if the current timestamp is past the deadline, false otherwise.
    function isPostDeadline(
        uint256 _tsTimestamp,
        uint256 _lastUnpausedAt,
        uint256 _windowMinutes
    )
        internal
        view
        returns (bool)
    {
        unchecked {
            uint256 deadline = _tsTimestamp.max(_lastUnpausedAt) + _windowMinutes * 60;
            return block.timestamp >= deadline;
        }
    }

    /// @dev Determines if blocks should be verified based on the configuration and block ID.
    /// @param _config The TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @param _isBlockProposed Whether the block is proposed.
    /// @return True if blocks should be verified, false otherwise.
    function shouldVerifyBlocks(
        TaikoData.Config memory _config,
        uint64 _blockId,
        bool _isBlockProposed
    )
        internal
        pure
        returns (bool)
    {
        if (_config.maxBlocksToVerify == 0) return false;

        // Consider each segment of 8 blocks, verification is attempted either on block 3 if it has
        // been proved, or on block 7 if it has been proposed. Over time, the ratio of blocks to
        // verification attempts averages 4:1, meaning each verification attempt typically covers 4
        // blocks. However, considering worst cases caused by blocks being proved out of order, some
        // verification attempts may verify few or no blocks. In such cases, additional
        // verifications are needed to catch up. Consequently, the `maxBlocksToVerify` parameter
        // should be set high enough, for example 16, to allow for efficient catch-up.

        // Now let's use `maxBlocksToVerify` as an input to calculate the size of each block
        // segment, instead of using 8 as a constant.
        uint256 segmentSize = _config.maxBlocksToVerify >> 1;

        if (segmentSize <= 1) return true;

        return _blockId % segmentSize == (_isBlockProposed ? 0 : segmentSize >> 1);
    }

    /// @dev Determines if the state root should be synchronized based on the configuration and
    /// block ID.
    /// @param _stateRootSyncInternal The state root sync interval.
    /// @param _blockId The ID of the block.
    /// @return True if the state root should be synchronized, false otherwise.
    function shouldSyncStateRoot(
        uint256 _stateRootSyncInternal,
        uint256 _blockId
    )
        internal
        pure
        returns (bool)
    {
        if (_stateRootSyncInternal <= 1) return true;
        unchecked {
            // We could use `_blockId % _stateRootSyncInternal == 0`, but this will break many unit
            // tests as in most of these tests, we test block#1, so by setting
            // config._stateRootSyncInternal = 2, we can keep the tests unchanged.
            return _blockId % _stateRootSyncInternal == _stateRootSyncInternal - 1;
        }
    }
}
