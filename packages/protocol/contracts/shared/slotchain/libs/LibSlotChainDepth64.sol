// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain depth-64 vector algorithms
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
        return _previewAppend(_frontier, _count, _leaf, false);
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
        bytes32 treeRoot = _frontierTreeRoot(_frontier, _count, false, 0, bytes32(0), false);
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

    /// @dev Previews one terminal-tree append while reading only meaningful frontier words.
    function previewTerminalAppend(
        bytes32[64] storage _frontier,
        uint64 _count,
        bytes32 _leaf
    )
        internal
        view
        returns (uint8 writeHeight_, bytes32 carriedNode_, uint64 newCount_, bytes32 newRoot_)
    {
        return _previewAppend(_frontier, _count, _leaf, true);
    }

    /// @dev Reconstructs the wrapped terminal root while ignoring stale zero-bit words.
    function terminalRoot(
        bytes32[64] storage _frontier,
        uint64 _count
    )
        internal
        view
        returns (bytes32 root_)
    {
        bytes32 treeRoot = _frontierTreeRoot(_frontier, _count, false, 0, bytes32(0), true);
        return LibSlotChainEncoding.hashTerminalRoot(_count, treeRoot);
    }

    /// @dev Verifies one terminal leaf against exactly 64 bottom-up siblings.
    function verifyTerminalInclusion(
        uint64 _count,
        uint64 _index,
        bytes32 _leaf,
        bytes32[64] memory _siblings,
        bytes32 _expectedRoot
    )
        internal
        pure
        returns (bool valid_)
    {
        if (_index >= _count) return false;
        bytes32 node = _leaf;
        for (uint8 height; height < LibSlotChainConstants.TERMINAL_TREE_DEPTH; ++height) {
            bytes32 sibling = _siblings[height];
            node = ((_index >> height) & 1) == 1
                ? LibSlotChainEncoding.hashTerminalNode(height, sibling, node)
                : LibSlotChainEncoding.hashTerminalNode(height, node, sibling);
        }
        return LibSlotChainEncoding.hashTerminalRoot(_count, node) == _expectedRoot;
    }

    /// @dev Computes one append carry and virtually substitutes its sole frontier write.
    function _previewAppend(
        bytes32[64] storage _frontier,
        uint64 _count,
        bytes32 _leaf,
        bool _terminal
    )
        private
        view
        returns (uint8 writeHeight_, bytes32 carriedNode_, uint64 newCount_, bytes32 newRoot_)
    {
        if (_count == type(uint64).max) {
            revert TreeCapacityExceeded();
        }
        carriedNode_ = _leaf;
        while (((_count >> writeHeight_) & 1) == 1) {
            carriedNode_ = _hashNode(writeHeight_, _frontier[writeHeight_], carriedNode_, _terminal);
            ++writeHeight_;
        }
        newCount_ = _count + 1;
        bytes32 treeRoot =
            _frontierTreeRoot(_frontier, newCount_, true, writeHeight_, carriedNode_, _terminal);
        newRoot_ = _terminal
            ? LibSlotChainEncoding.hashTerminalRoot(newCount_, treeRoot)
            : LibSlotChainEncoding.hashForcedRoot(newCount_, treeRoot);
    }

    /// @dev Folds one frontier and canonical empty right subtrees for the selected fixed domain.
    function _frontierTreeRoot(
        bytes32[64] storage _frontier,
        uint64 _count,
        bool _hasOverride,
        uint8 _overrideHeight,
        bytes32 _overrideNode,
        bool _terminal
    )
        private
        view
        returns (bytes32 node_)
    {
        bytes32 empty = _terminal
            ? LibSlotChainEncoding.hashTerminalEmptyLeaf()
            : LibSlotChainEncoding.hashForcedEmptyLeaf();
        node_ = empty;
        for (uint8 height; height < 64; ++height) {
            if (((_count >> height) & 1) == 1) {
                bytes32 left =
                    _hasOverride && height == _overrideHeight ? _overrideNode : _frontier[height];
                node_ = _hashNode(height, left, node_, _terminal);
            } else {
                node_ = _hashNode(height, node_, empty, _terminal);
            }
            empty = _hashNode(height, empty, empty, _terminal);
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

    /// @dev Hashes one node without exposing the domain selector to callers.
    function _hashNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right,
        bool _terminal
    )
        private
        pure
        returns (bytes32 node_)
    {
        return _terminal
            ? LibSlotChainEncoding.hashTerminalNode(_height, _left, _right)
            : LibSlotChainEncoding.hashForcedNode(_height, _left, _right);
    }

    error TreeCapacityExceeded();
}
