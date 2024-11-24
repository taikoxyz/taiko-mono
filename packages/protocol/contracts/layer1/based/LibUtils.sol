// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/IResolver.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibMath.sol";
import "../tiers/ITierProvider.sol";
import "./TaikoData.sol";
import "./TaikoEvents.sol";

/// @title LibUtils
/// @notice A library that offers utility helper functions.
/// @custom:security-contact security@taiko.xyz
library LibUtils {
    using LibMath for uint256;

    uint256 internal constant SECONDS_IN_MINUTE = 60;

    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_PARAMS();
    error L1_INVALID_GENESIS_HASH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @dev Initializes the Taiko protocol state.
    /// @param _state The state to initialize.
    /// @param _genesisBlockHash The block hash of the genesis block.
    function init(TaikoData.State storage _state, bytes32 _genesisBlockHash) public {
        require(_genesisBlockHash != 0, L1_INVALID_GENESIS_HASH());
        // Init state
        _state.slotA.genesisHeight = uint64(block.number);
        _state.slotA.genesisTimestamp = uint64(block.timestamp);
        _state.slotB.numBlocks = 1;

        // Init the genesis block
        TaikoData.BlockV3 storage blk = _state.blocks[0];
        blk.nextTransitionId = 2;
        blk.timestamp = uint64(block.timestamp);
        blk.anchorBlockId = uint64(block.number);
        blk.verifiedTransitionId = 1;
        blk.metaHash = bytes32(uint256(1)); // Give the genesis metahash a non-zero value.

        // Init the first state transition
        TaikoData.TransitionStateV3 storage ts = _state.transitions[0][1];
        ts.blockHash = _genesisBlockHash;
        ts.prover = address(0);
        ts.timestamp = uint64(block.timestamp);

        emit TaikoEvents.BlockVerifiedV3({
            blockId: 0,
            prover: address(0),
            blockHash: _genesisBlockHash
        });
    }

    /// @dev Retrieves a block's block hash and state root.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _blockId Id of the block.
    /// @return blockHash_ The block's block hash.
    /// @return stateRoot_ The block's storage root.
    /// @return verifiedAt_ The timestamp when the block was proven at.
    function getBlockInfo(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        uint64 _blockId
    )
        public
        view
        returns (bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
    {
        (TaikoData.BlockV3 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        if (blk.verifiedTransitionId != 0) {
            TaikoData.TransitionStateV3 storage transition =
                _state.transitions[slot][blk.verifiedTransitionId];

            blockHash_ = transition.blockHash;
            stateRoot_ = transition.stateRoot;
            verifiedAt_ = transition.timestamp;
        }
    }

    /// @dev Gets the state transitions for a batch of block. For transition that doesn't exist, the
    /// corresponding transition state will be empty.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _blockIds Id array of the blocks.
    /// @param _parentHashes Parent hashes of the blocks.
    /// @return transitions_ The state transition pointer array.
    function getTransitions(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        uint64[] calldata _blockIds,
        bytes32[] calldata _parentHashes
    )
        public
        view
        returns (TaikoData.TransitionStateV3[] memory transitions_)
    {
        require(_blockIds.length != 0, L1_INVALID_PARAMS());
        require(_blockIds.length == _parentHashes.length, L1_INVALID_PARAMS());
        transitions_ = new TaikoData.TransitionStateV3[](_blockIds.length);
        for (uint256 i; i < _blockIds.length; ++i) {
            (TaikoData.BlockV3 storage blk, uint64 slot) = getBlock(_state, _config, _blockIds[i]);
            uint24 tid = getTransitionId(_state, blk, slot, _parentHashes[i]);
            if (tid != 0) {
                transitions_[i] = _state.transitions[slot][tid];
            }
        }
    }

    /// @dev Retrieves the transition with a given parentHash.
    /// @dev This function will revert if the transition is not found.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _blockId Id of the block.
    /// @param _parentHash Parent hash of the block.
    /// @return The state transition pointer.
    function getTransitionByParentHash(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        uint64 _blockId,
        bytes32 _parentHash
    )
        public
        view
        returns (TaikoData.TransitionStateV3 storage)
    {
        (TaikoData.BlockV3 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        uint24 tid = getTransitionId(_state, blk, slot, _parentHash);
        require(tid != 0, L1_TRANSITION_NOT_FOUND());

        return _state.transitions[slot][tid];
    }

    /// @dev Retrieves a block based on its ID.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _blockId Id of the block.
    /// @return blk_ The block storage pointer.
    /// @return slot_ The slot value.
    function getBlock(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        uint64 _blockId
    )
        internal
        view
        returns (TaikoData.BlockV3 storage blk_, uint64 slot_)
    {
        slot_ = _blockId % _config.blockRingBufferSize;
        blk_ = _state.blocks[slot_];
        require(blk_.blockId == _blockId, L1_INVALID_BLOCK_ID());
    }

    /// @dev Retrieves the transition with a transition ID.
    /// @dev This function will revert if the transition is not found.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _blockId Id of the block.
    /// @param _tid The transition id.
    /// @return The state transition pointer.
    function getTransitionById(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        uint64 _blockId,
        uint24 _tid
    )
        internal
        view
        returns (TaikoData.TransitionStateV3 storage)
    {
        (TaikoData.BlockV3 storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        require(_tid != 0, L1_TRANSITION_NOT_FOUND());
        require(_tid < blk.nextTransitionId, L1_TRANSITION_NOT_FOUND());
        return _state.transitions[slot][_tid];
    }

    /// @dev Retrieves the ID of the transition with a given parentHash. This function will return 0
    /// if the transition is not found.
    /// @param _state Pointer to the protocol's storage.
    /// @param _blk The block storage pointer.
    /// @param _slot The slot value.
    /// @param _parentHash The parent hash of the block.
    /// @return tid_ The transition ID.
    function getTransitionId(
        TaikoData.State storage _state,
        TaikoData.BlockV3 storage _blk,
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
            uint256 deadline =
                _tsTimestamp.max(_lastUnpausedAt) + _windowMinutes * SECONDS_IN_MINUTE;
            return block.timestamp >= deadline;
        }
    }

    /// @dev Determines if blocks should be verified based on the configuration and block ID.
    /// @param _config The TaikoData.Config.
    /// @param _blockId The ID of the block.
    /// @param _isBlockProposed Whether the block is proposed.
    /// @return True if blocks should be verified, false otherwise.
    function shouldVerifyBlocks(
        TaikoData.ConfigV3 memory _config,
        uint64 _blockId,
        bool _isBlockProposed
    )
        internal
        pure
        returns (bool)
    {
        if (_config.maxBlocksToVerify == 0) return false;
        // If maxBlocksToVerify = 16, segmentSize = 8, verification will be triggered by
        // proposeBlock(s) for blocks 0, 8, 16, 24, ..., and by proveBlock(s) for blocks 4, 12, 20,
        // 28, ...
        uint256 segmentSize = _config.maxBlocksToVerify >> 1;

        if (segmentSize <= 1) return true;

        return _blockId % segmentSize == (_isBlockProposed ? 0 : segmentSize >> 1);
    }

    /// @dev Determines if the state root should be synchronized based on the configuration and
    /// block ID.
    /// @param _stateRootSyncInternal The state root sync interval.
    /// @param _blockId The ID of the block.
    /// @return True if the state root should be synchronized, false otherwise.
    function isSyncBlock(
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
