// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../SlotChainTypes.sol";
import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain per-block manifest-tree construction
/// @custom:security-contact security@taiko.xyz
library LibSlotChainManifestTree {
    /// @dev Builds the next-power-of-two manifest tree with canonical empty padding.
    function root(
        uint16 _expectedBlockOrdinal,
        SlotChainTypes.ManifestEntryV1[] calldata _entries
    )
        internal
        pure
        returns (bytes32 root_)
    {
        uint256 count = _entries.length;
        if (
            _expectedBlockOrdinal >= LibSlotChainConstants.MAX_CANDIDATE_BLOCKS
                || count > LibSlotChainConstants.MAX_MANIFEST_ENTRIES
        ) {
            revert InvalidManifestTree();
        }

        bytes32 emptyLeaf = LibSlotChainEncoding.hashManifestEmptyLeaf();
        if (count == 0) return LibSlotChainEncoding.hashManifestRoot(0, emptyLeaf);

        bytes32[12] memory frontier;
        for (uint16 position; position < count; ++position) {
            bytes32 carry = LibSlotChainEncoding.hashManifestLeaf(
                _expectedBlockOrdinal, position, _entries[position]
            );
            uint8 writeHeight;
            while (((position >> writeHeight) & 1) == 1) {
                carry = LibSlotChainEncoding.hashManifestNode(
                    writeHeight, frontier[writeHeight], carry
                );
                ++writeHeight;
            }
            frontier[writeHeight] = carry;
        }

        uint8 treeDepth = _ceilingLog2(count);
        bytes32 treeRoot;
        if ((count & (count - 1)) == 0) {
            treeRoot = frontier[treeDepth];
        } else {
            bytes32 node = emptyLeaf;
            bytes32 empty = emptyLeaf;
            uint16 recordCount = uint16(count);
            for (uint8 height; height < treeDepth; ++height) {
                node = ((recordCount >> height) & 1) == 1
                    ? LibSlotChainEncoding.hashManifestNode(height, frontier[height], node)
                    : LibSlotChainEncoding.hashManifestNode(height, node, empty);
                empty = LibSlotChainEncoding.hashManifestNode(height, empty, empty);
            }
            treeRoot = node;
        }
        return LibSlotChainEncoding.hashManifestRoot(uint16(count), treeRoot);
    }

    /// @dev Returns the least depth whose perfect tree can contain the requested count.
    function _ceilingLog2(uint256 _count) private pure returns (uint8 depth_) {
        uint256 size = 1;
        while (size < _count) {
            size <<= 1;
            ++depth_;
        }
    }

    error InvalidManifestTree();
}
