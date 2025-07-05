// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibForks
/// @notice Library for managing protocol fork transitions and block range validation
/// @dev This library handles fork-related logic for Taiko's protocol upgrades:
///      - Validates block ranges against fork heights
///      - Ensures blocks are within the current active fork
///      - Manages transitions between protocol versions (Shasta, Unzen, etc.)
/// @custom:security-contact security@taiko.xyz
library LibForks {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Validates if a block range is within the current active fork
    /// @dev Checks that blocks are:
    ///      - Within a valid range (lastBlockId >= firstBlockId)
    ///      - After the Shasta fork activation
    ///      - Before the Unzen fork activation (if set)
    /// @param _conf Protocol configuration containing fork heights
    /// @param _firstBlockId First block ID in the range to validate
    /// @param _lastBlockId Last block ID in the range to validate
    /// @return True if the entire block range is within the current fork, false otherwise
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
    // Custom Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the block range is invalid (lastBlockId < firstBlockId)
    error InvalidBlockRange();
}
