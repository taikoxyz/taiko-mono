// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../shared/common/IAddressResolver.sol";
import "../../shared/common/LibStrings.sol";
import "../../shared/common/LibMath.sol";
import "../tiers/ITierProvider.sol";
import "../tiers/ITierRouter.sol";
import "./TaikoData.sol";

/// @title LibUtils
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibUtils {
    using LibMath for uint256;

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the
    /// block.
    /// @param blockHash The hash of the verified block.
    /// @param stateRoot Deprecated and is always zero.
    /// @param tier The tier ID of the proof.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed prover,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint16 tier
    );

    /// @dev Emitted when a block is verified.
    /// @param blockId The ID of the verified block.
    /// @param prover The prover whose transition is used for verifying the
    /// block.
    /// @param blockHash The hash of the verified block.
    /// @param tier The tier ID of the proof.
    event BlockVerifiedV2(
        uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier
    );

    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_PARAMS();
    error L1_INVALID_GENESIS_HASH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @notice Initializes the Taiko protocol state.
    /// @param _state The state to initialize.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        bytes32 _genesisBlockHash
    )
        internal
    {
        if (_genesisBlockHash == 0) revert L1_INVALID_GENESIS_HASH();
        // Init state
        _state.slotA.genesisHeight = uint64(block.number);
        _state.slotA.genesisTimestamp = uint64(block.timestamp);
        _state.slotB.numBlocks = 1;

        // Init the genesis block
        TaikoData.BlockV2 storage blk = _state.blocks[0];
        blk.nextTransitionId = 2;
        blk.proposedAt = uint64(block.timestamp);
        blk.verifiedTransitionId = 1;
        blk.metaHash = bytes32(uint256(1)); // Give the genesis metahash a non-zero value.

        // Init the first state transition
        TaikoData.TransitionState storage ts = _state.transitions[0][1];
        ts.blockHash = _genesisBlockHash;
        ts.prover = address(0);
        ts.timestamp = uint64(block.timestamp);

        if (_config.ontakeForkHeight == 0) {
            emit BlockVerifiedV2({
                blockId: 0,
                prover: address(0),
                blockHash: _genesisBlockHash,
                tier: 0
            });
        } else {
            emit BlockVerified({
                blockId: 0,
                prover: address(0),
                blockHash: _genesisBlockHash,
                stateRoot: 0,
                tier: 0
            });
        }
    }

    /// @dev Retrieves a block based on its ID.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
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
        if (blk_.blockId != _blockId) revert L1_INVALID_BLOCK_ID();
    }

    /// @dev Retrieves a block's block hash and state root.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @return blockHash_ The block's block hash.
    /// @return stateRoot_ The block's storage root.
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
    /// @dev Retrieves the transition with a given parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @param _tid The transition id.
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

        if (_tid == 0 || _tid >= blk.nextTransitionId) revert L1_TRANSITION_NOT_FOUND();
        return _state.transitions[slot][_tid];
    }

    /// @dev Retrieves the transitions with a batch of parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockIds Id array of the block.
    /// @param _tids The transition id array.
    /// @return transitions_ The state transition pointer array.
    function getTransitions(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64[] calldata _blockIds,
        uint32[] calldata _tids
    )
        internal
        view
        returns (TaikoData.TransitionState[] memory transitions_)
    {
        if (_blockIds.length == 0 || _blockIds.length != _tids.length) {
            revert L1_INVALID_PARAMS();
        }
        transitions_ = new TaikoData.TransitionState[](_blockIds.length);
        for (uint256 i; i < _blockIds.length; ++i) {
            transitions_[i] = getTransition(_state, _config, _blockIds[i], _tids[i]);
        }
    }

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @param _parentHash Parent hash of the block.
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
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        return _state.transitions[slot][tid];
    }

    /// @dev Retrieves the transitions with a batch of parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockIds Id array of the blocks.
    /// @param _parentHashes Parent hashes of the blocks.
    /// @return The state transition pointer array.
    function getTransitions(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64[] calldata _blockIds,
        bytes32[] calldata _parentHashes
    )
        internal
        view
        returns (TaikoData.TransitionState[] memory)
    {
        if (_blockIds.length == 0 || _blockIds.length != _parentHashes.length) {
            revert L1_INVALID_PARAMS();
        }
        TaikoData.TransitionState[] memory transitions =
            new TaikoData.TransitionState[](_blockIds.length);
        for (uint256 i; i < _blockIds.length; ++i) {
            transitions[i] = getTransition(_state, _config, _blockIds[i], _parentHashes[i]);
        }
        return transitions;
    }

    /// @dev Retrieves the ID of the transition with a given parentHash.
    /// This function will return 0 if the transition is not found.
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
            if (tid_ >= _blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
        } else {
            tid_ = _state.transitionIds[_blk.blockId][_parentHash];
            if (tid_ != 0 && tid_ >= _blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
        }
    }

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
        // been
        // proved, or on block 7 if it has been proposed. Over time, the ratio of blocks to
        // verification attempts averages 4:1, meaning each verification attempt typically covers 4
        // blocks. However, considering worst cases caused by blocks being proved out of order, some
        // verification attempts may verify few or no blocks. In such cases, additional
        // verifications are needed to catch up. Consequently, the `maxBlocksToVerify` parameter
        // should be set high enough, for example 16, to allow for efficient catch-up.

        // Now lets use `maxBlocksToVerify` as an input to calculate the size of each block
        // segment, instead of using 8 as a constant.
        uint256 segmentSize = _config.maxBlocksToVerify >> 1;

        if (segmentSize <= 1) return true;

        return _blockId % segmentSize == (_isBlockProposed ? 0 : segmentSize >> 1);
    }

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
