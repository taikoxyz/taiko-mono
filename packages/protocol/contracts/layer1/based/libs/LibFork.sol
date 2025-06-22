// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibFork {
    /// @dev Check this batch is between current fork height (inclusive) and next fork height
    /// (exclusive)
    function checkBlocksInShastaFork(
        I.Config memory _config,
        uint256 _firstBlockId,
        uint256 _lastBlockId
    )
        internal
        pure
    {
        require(_firstBlockId >= _config.forkHeights.shasta, I.ForkNotActivated());
        require(
            _config.forkHeights.unzen == 0 || _lastBlockId < _config.forkHeights.unzen,
            I.BeyondCurrentFork()
        );
    }
}
