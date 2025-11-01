// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ForkRouter } from "src/shared/fork-router/ForkRouter.sol";

/// @title SignalServiceForkRouter
/// @notice Routes SignalService delegatecalls between Pacaya and Shasta implementations based on fork timestamp.
/// @custom:security-contact security@taiko.xyz
contract SignalServiceForkRouter is ForkRouter {
    /// @notice Timestamp that flips routing from the legacy (Pacaya) implementation to the Shasta version.
    uint64 public immutable shastaForkTimestamp;

    constructor(
        address _oldFork,
        address _newFork,
        uint64 _shastaForkTimestamp
    )
        ForkRouter(_oldFork, _newFork)
    {
        shastaForkTimestamp = _shastaForkTimestamp;
    }

    function shouldRouteToOldFork(bytes4) public view override returns (bool) {
        return block.timestamp < shastaForkTimestamp;
    }
}

