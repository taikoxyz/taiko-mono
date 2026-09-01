// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain fixed-tree algorithms
/// @custom:security-contact security@taiko.xyz
library LibSlotChainFixedTrees {
    /// @dev Returns the reviewed root of 64 canonical empty registry leaves.
    function emptyRegistryRoot() internal pure returns (bytes32 root_) {
        return LibSlotChainConstants.EMPTY_REGISTRY_ROOT;
    }

    /// @dev Returns the reviewed root of 2,048 position-bound empty admission leaves.
    function emptyAdmissionRoot() internal pure returns (bytes32 root_) {
        return LibSlotChainConstants.EMPTY_ADMISSION_ROOT;
    }

    /// @dev Returns the reviewed root of 64 canonical empty ranked-entry leaves.
    function emptyRankedEntryRoot() internal pure returns (bytes32 root_) {
        return LibSlotChainConstants.EMPTY_RANKED_ENTRY_ROOT;
    }

    /// @dev Returns the reviewed root of 512 position-bound empty tranche leaves.
    function emptyTrancheRoot() internal pure returns (bytes32 root_) {
        return LibSlotChainConstants.EMPTY_TRANCHE_ROOT;
    }

    /// @dev Folds exactly 64 registry leaves into the six-level registry root.
    /// @param _leaves Position-bound registry leaves in ascending index order.
    /// @return root_ The unwrapped fixed-tree root.
    function registryRoot(bytes32[64] memory _leaves) internal pure returns (bytes32 root_) {
        return _foldSixLevels(_leaves, false);
    }

    /// @dev Folds exactly 64 ranked-entry leaves into the six-level entry root.
    /// @param _leaves Rank-bound entry leaves in ascending rank order.
    /// @return root_ The unwrapped fixed-tree root.
    function rankedEntryRoot(bytes32[64] memory _leaves) internal pure returns (bytes32 root_) {
        return _foldSixLevels(_leaves, true);
    }

    /// @dev Reconstructs a registry root from one leaf and six bottom-up siblings.
    function computeRegistryRoot(
        uint8 _index,
        bytes32 _leaf,
        bytes32[6] memory _siblings
    )
        internal
        pure
        returns (bytes32 root_)
    {
        if (_index >= LibSlotChainConstants.REGISTRY_CELL_COUNT) revert InvalidTreeIndex();
        return _computeSixLevelRoot(_index, _leaf, _siblings, false);
    }

    /// @dev Reconstructs a ranked-entry root from one leaf and six bottom-up siblings.
    function computeRankedEntryRoot(
        uint8 _index,
        bytes32 _leaf,
        bytes32[6] memory _siblings
    )
        internal
        pure
        returns (bytes32 root_)
    {
        if (_index >= LibSlotChainConstants.RANKED_ENTRY_LEAF_COUNT) revert InvalidTreeIndex();
        return _computeSixLevelRoot(_index, _leaf, _siblings, true);
    }

    /// @dev Reconstructs an admission root from one leaf and eleven bottom-up siblings.
    function computeAdmissionRoot(
        uint16 _index,
        bytes32 _leaf,
        bytes32[11] memory _siblings
    )
        internal
        pure
        returns (bytes32 root_)
    {
        if (_index >= LibSlotChainConstants.ADMISSION_LEAF_COUNT) revert InvalidTreeIndex();
        root_ = _leaf;
        for (uint8 height; height < LibSlotChainConstants.ADMISSION_TREE_DEPTH; ++height) {
            bytes32 sibling = _siblings[height];
            root_ = ((_index >> height) & 1) == 1
                ? LibSlotChainEncoding.hashAdmissionNode(height, sibling, root_)
                : LibSlotChainEncoding.hashAdmissionNode(height, root_, sibling);
        }
    }

    /// @dev Reconstructs a tranche root from one leaf and nine bottom-up siblings.
    function computeTrancheRoot(
        uint16 _index,
        bytes32 _leaf,
        bytes32[9] memory _siblings
    )
        internal
        pure
        returns (bytes32 root_)
    {
        if (_index >= LibSlotChainConstants.TRANCHE_LEAF_COUNT) revert InvalidTreeIndex();
        root_ = _leaf;
        for (uint8 height; height < LibSlotChainConstants.TRANCHE_TREE_DEPTH; ++height) {
            bytes32 sibling = _siblings[height];
            root_ = ((_index >> height) & 1) == 1
                ? LibSlotChainEncoding.hashTrancheNode(height, sibling, root_)
                : LibSlotChainEncoding.hashTrancheNode(height, root_, sibling);
        }
    }

    /// @dev Verifies an old registry leaf and returns the root after replacing it.
    function updateRegistryRoot(
        bytes32 _expectedRoot,
        uint8 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[6] memory _siblings
    )
        internal
        pure
        returns (bytes32 newRoot_)
    {
        if (computeRegistryRoot(_index, _oldLeaf, _siblings) != _expectedRoot) {
            revert TreeRootMismatch();
        }
        return computeRegistryRoot(_index, _newLeaf, _siblings);
    }

    /// @dev Verifies an old ranked leaf and returns the root after replacing it.
    function updateRankedEntryRoot(
        bytes32 _expectedRoot,
        uint8 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[6] memory _siblings
    )
        internal
        pure
        returns (bytes32 newRoot_)
    {
        if (computeRankedEntryRoot(_index, _oldLeaf, _siblings) != _expectedRoot) {
            revert TreeRootMismatch();
        }
        return computeRankedEntryRoot(_index, _newLeaf, _siblings);
    }

    /// @dev Verifies and updates one used admission position; padding cannot be written.
    function updateAdmissionUsedRoot(
        bytes32 _expectedRoot,
        uint16 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[11] memory _siblings
    )
        internal
        pure
        returns (bytes32 newRoot_)
    {
        if (_index >= LibSlotChainConstants.ADMISSION_USED_LEAF_COUNT) {
            revert InvalidTreeIndex();
        }
        if (computeAdmissionRoot(_index, _oldLeaf, _siblings) != _expectedRoot) {
            revert TreeRootMismatch();
        }
        return computeAdmissionRoot(_index, _newLeaf, _siblings);
    }

    /// @dev Verifies an old tranche leaf and returns the root after replacing it.
    function updateTrancheRoot(
        bytes32 _expectedRoot,
        uint16 _index,
        bytes32 _oldLeaf,
        bytes32 _newLeaf,
        bytes32[9] memory _siblings
    )
        internal
        pure
        returns (bytes32 newRoot_)
    {
        if (computeTrancheRoot(_index, _oldLeaf, _siblings) != _expectedRoot) {
            revert TreeRootMismatch();
        }
        return computeTrancheRoot(_index, _newLeaf, _siblings);
    }

    /// @dev Folds one exact six-level tree without exposing a caller-selected domain.
    function _foldSixLevels(
        bytes32[64] memory _nodes,
        bool _rankedEntry
    )
        private
        pure
        returns (bytes32 root_)
    {
        uint256 width = 64;
        for (uint8 height; height < 6; ++height) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] = _rankedEntry
                    ? LibSlotChainEncoding.hashRankedEntryNode(height, _nodes[i], _nodes[i + 1])
                    : LibSlotChainEncoding.hashRegistryNode(height, _nodes[i], _nodes[i + 1]);
            }
            width >>= 1;
        }
        return _nodes[0];
    }

    /// @dev Reconstructs one exact six-level proof under a fixed internal domain choice.
    function _computeSixLevelRoot(
        uint8 _index,
        bytes32 _leaf,
        bytes32[6] memory _siblings,
        bool _rankedEntry
    )
        private
        pure
        returns (bytes32 root_)
    {
        root_ = _leaf;
        for (uint8 height; height < 6; ++height) {
            bytes32 sibling = _siblings[height];
            bool siblingOnLeft = ((_index >> height) & 1) == 1;
            if (_rankedEntry) {
                root_ = siblingOnLeft
                    ? LibSlotChainEncoding.hashRankedEntryNode(height, sibling, root_)
                    : LibSlotChainEncoding.hashRankedEntryNode(height, root_, sibling);
            } else {
                root_ = siblingOnLeft
                    ? LibSlotChainEncoding.hashRegistryNode(height, sibling, root_)
                    : LibSlotChainEncoding.hashRegistryNode(height, root_, sibling);
            }
        }
    }

    error InvalidTreeIndex();
    error TreeRootMismatch();
}
