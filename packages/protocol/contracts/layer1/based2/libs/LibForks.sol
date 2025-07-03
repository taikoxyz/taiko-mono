// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibForks
/// @notice Library for managing fork-related logic
/// @custom:security-contact security@taiko.xyz
library LibForks {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Checks if the given block range is in the current fork
    /// @param _conf The configuration containing fork heights
    /// @param _firstBlockId The first block ID in the range
    /// @param _lastBlockId The last block ID in the range
    /// @return True if the block range is in the current fork, false otherwise
    function isBlocksInCurrentFork(
        I.Config memory _conf,
        uint256 _firstBlockId,
        uint256 _lastBlockId
    )
        internal
        pure
        returns (bool)
    {
        require(_lastBlockId >= _firstBlockId, InvalidBlockRange());

        // Check if blocks are beyond the unzen fork height
        if (_conf.forkHeights.unzen != 0 && _lastBlockId >= _conf.forkHeights.unzen) {
            return false;
        }

        // Check if blocks are within the shasta fork
        return _firstBlockId >= _conf.forkHeights.shasta;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the block range is invalid (last < first)
    error InvalidBlockRange();
}
