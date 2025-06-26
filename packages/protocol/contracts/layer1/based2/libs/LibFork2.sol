// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibFork2 {
    error InvalidBlockRange();
    /// @notice Check if the given block range is in the current fork.

    function isBlocksInCurrentFork(
        I.Config memory _config,
        uint256 _firstBlockId,
        uint256 _lastBlockId
    )
        internal
        pure
        returns (bool)
    {
        require(_lastBlockId >= _firstBlockId, InvalidBlockRange());

        if (_config.forkHeights.unzen != 0 && _lastBlockId >= _config.forkHeights.unzen) {
            return false;
        }

        return _firstBlockId >= _config.forkHeights.shasta;
    }
}
