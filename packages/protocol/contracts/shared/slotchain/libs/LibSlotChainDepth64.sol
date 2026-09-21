// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain depth-64 forced-vector algorithms
/// @custom:security-contact security@taiko.xyz
library LibSlotChainDepth64 {
    struct RangeState {
        uint256 start;
        uint256 end;
        uint256 proofIndex;
        uint256 revealedIndex;
        bool valid;
    }

    /// @dev Previews one forced-tree append while reading only meaningful frontier words.
    function previewForcedAppend(
        bytes32[64] storage _frontier,
        uint64 _count,
        bytes32 _leaf
    )
        internal
        view
        returns (uint8 writeHeight_, bytes32 carriedNode_, uint64 newCount_, bytes32 newRoot_)
    {
        if (_count == type(uint64).max) {
            revert TreeCapacityExceeded();
        }
        carriedNode_ = _leaf;
        while (((_count >> writeHeight_) & 1) == 1) {
            carriedNode_ = LibSlotChainEncoding.hashForcedNode(
                writeHeight_, _frontier[writeHeight_], carriedNode_
            );
            ++writeHeight_;
        }
        newCount_ = _count + 1;
        bytes32 treeRoot = _frontierTreeRoot(_frontier, newCount_, true, writeHeight_, carriedNode_);
        newRoot_ = LibSlotChainEncoding.hashForcedRoot(newCount_, treeRoot);
    }

    /// @dev Reconstructs the wrapped forced root while ignoring stale zero-bit words.
    function forcedRoot(
        bytes32[64] storage _frontier,
        uint64 _count
    )
        internal
        view
        returns (bytes32 root_)
    {
        bytes32 treeRoot = _frontierTreeRoot(_frontier, _count, false, 0, bytes32(0));
        return LibSlotChainEncoding.hashForcedRoot(_count, treeRoot);
    }

    /// @dev Verifies the unique depth-first range proof for a nonempty contiguous interval.
    function verifyForcedRange(
        uint64 _count,
        uint64 _start,
        bytes32[] calldata _revealed,
        bytes32[] calldata _proof,
        bytes32 _expectedRoot
    )
        internal
        pure
        returns (bool valid_)
    {
        uint256 revealedLength = _revealed.length;
        if (
            revealedLength == 0 || revealedLength > LibSlotChainConstants.MAX_FORCED_DESCRIPTOR_ROWS
                || _proof.length > LibSlotChainConstants.MAX_FORCED_DESCRIPTOR_ROWS
                || _start >= _count || revealedLength > uint256(_count) - uint256(_start)
        ) {
            return false;
        }

        RangeState memory state = RangeState({
            start: uint256(_start),
            end: uint256(_start) + revealedLength - 1,
            proofIndex: 0,
            revealedIndex: 0,
            valid: true
        });
        bytes32 treeRoot = _visitForcedRange(64, 0, _revealed, _proof, state);
        return state.valid && state.proofIndex == _proof.length
            && state.revealedIndex == revealedLength
            && LibSlotChainEncoding.hashForcedRoot(_count, treeRoot) == _expectedRoot;
    }

    /// @dev Folds one frontier and canonical empty right subtrees under the forced domains.
    function _frontierTreeRoot(
        bytes32[64] storage _frontier,
        uint64 _count,
        bool _hasOverride,
        uint8 _overrideHeight,
        bytes32 _overrideNode
    )
        private
        view
        returns (bytes32 node_)
    {
        bytes32 empty = LibSlotChainEncoding.hashForcedEmptyLeaf();
        node_ = empty;
        for (uint8 height; height < 64; ++height) {
            if (((_count >> height) & 1) == 1) {
                bytes32 left =
                    _hasOverride && height == _overrideHeight ? _overrideNode : _frontier[height];
                node_ = LibSlotChainEncoding.hashForcedNode(height, left, node_);
            } else {
                node_ = LibSlotChainEncoding.hashForcedNode(height, node_, empty);
            }
            empty = LibSlotChainEncoding.hashForcedNode(height, empty, empty);
        }
    }

    /// @dev Traverses the depth-64 tree in canonical DFS order and consumes exact inputs.
    function _visitForcedRange(
        uint8 _height,
        uint256 _nodeIndex,
        bytes32[] calldata _revealed,
        bytes32[] calldata _proof,
        RangeState memory _state
    )
        private
        pure
        returns (bytes32 node_)
    {
        if (!_state.valid) return bytes32(0);
        uint256 left = _nodeIndex << _height;
        uint256 right = left + (uint256(1) << _height) - 1;
        if (right < _state.start || left > _state.end) {
            if (_state.proofIndex >= _proof.length) {
                _state.valid = false;
                return bytes32(0);
            }
            node_ = _proof[_state.proofIndex];
            ++_state.proofIndex;
            return node_;
        }
        if (_height == 0) {
            if (_state.revealedIndex >= _revealed.length) {
                _state.valid = false;
                return bytes32(0);
            }
            node_ = _revealed[_state.revealedIndex];
            ++_state.revealedIndex;
            return node_;
        }

        bytes32 leftNode = _visitForcedRange(_height - 1, _nodeIndex * 2, _revealed, _proof, _state);
        bytes32 rightNode =
            _visitForcedRange(_height - 1, _nodeIndex * 2 + 1, _revealed, _proof, _state);
        if (!_state.valid) return bytes32(0);
        return LibSlotChainEncoding.hashForcedNode(_height - 1, leftNode, rightNode);
    }

    error TreeCapacityExceeded();
}
