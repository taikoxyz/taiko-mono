// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibForks
/// @notice Library for validating block ranges against protocol fork boundaries
/// @dev Handles fork transition validation for Taiko's protocol upgrades:
///      - Validates block ranges are within valid bounds
///      - Ensures blocks are after Shasta fork activation
///      - Prevents blocks from crossing into future Unzen fork
///      - Manages protocol version boundaries for batch processing
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
        IInbox.Config memory _conf,
        uint256 _firstBlockId,
        uint256 _lastBlockId
    )
        internal
        pure
        returns (bool)
    {
        if (_lastBlockId < _firstBlockId) revert InvalidBlockRange();

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

    error InvalidBlockRange();
}
