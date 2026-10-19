// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibStakeSchedule
/// @dev Unsigned Fenwick sums over all uint64 block coordinates. Work is bounded by the
/// coordinate width, independent of the number of events or elapsed blocks.
/// @custom:security-contact security@taiko.xyz
library LibStakeSchedule {
    struct Tree {
        mapping(uint256 index => uint256 amount) nodes;
    }

    uint256 internal constant SIZE = uint256(1) << 64;

    /// @dev Adds an event; each node uses checked full-width amount arithmetic.
    /// @param _self The tree.
    /// @param _block The event block (inclusive).
    /// @param _amount The event amount.
    function add(Tree storage _self, uint64 _block, uint256 _amount) internal {
        uint256 index = uint256(_block) + 1;
        while (index <= SIZE) {
            _self.nodes[index] += _amount;
            // index is positive and at most 2^64; its next ancestor is at most 2^65.
            index += index & (~index + 1);
        }
    }

    /// @dev Cancels an existing event, visiting at most 65 nodes.
    /// @param _self The tree.
    /// @param _block The original event block.
    /// @param _amount The original event amount.
    function remove(Tree storage _self, uint64 _block, uint256 _amount) internal {
        uint256 index = uint256(_block) + 1;
        while (index <= SIZE) {
            _self.nodes[index] -= _amount;
            index += index & (~index + 1);
        }
    }

    /// @dev Returns the inclusive sum through a block, visiting at most 64 disjoint nodes.
    /// @param _self The tree.
    /// @param _block The inclusive upper block.
    /// @return amount_ The summed amount.
    function prefix(
        Tree storage _self,
        uint64 _block
    )
        internal
        view
        returns (uint256 amount_)
    {
        uint256 index = uint256(_block) + 1;
        while (index != 0) {
            amount_ += _self.nodes[index];
            index &= index - 1;
        }
    }
}
