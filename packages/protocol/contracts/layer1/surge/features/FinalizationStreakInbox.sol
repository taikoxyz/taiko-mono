// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Inbox } from "../../core/impl/Inbox.sol";

/// @title FinalizationStreakInbox
/// @notice A feature-contract that maintains a finalization streak that can used to monitor chain
/// finalization disruptions.
/// @dev This feature is used by `SurgeTimelockController` to lock execution during disruptions.
/// @custom:security-contact security@nethermind.io
abstract contract FinalizationStreakInbox is Inbox {
    /// @dev Maximum grace period after which the finalization streak is reset
    uint48 public immutable maxFinalizationDelayBeforeStreakReset;

    /// @dev The timestamp at which the current finalization streak started
    /// @dev Slot 0
    uint48 internal _finalizationStreakStartedAt;

    uint256[49] private __gap;

    constructor(uint48 _maxFinalizationDelayBeforeStreakReset) {
        maxFinalizationDelayBeforeStreakReset = _maxFinalizationDelayBeforeStreakReset;
    }

    // ---------------------------------------------------------------
    // External views
    // ---------------------------------------------------------------

    /// @notice Returns the current finalization streak in seconds.
    /// @return The duration in seconds of the current finalization streak, or 0 if broken.
    function getFinalizationStreak() external view returns (uint48) {
        if (
            block.timestamp - _coreState.lastFinalizedTimestamp
                > maxFinalizationDelayBeforeStreakReset
        ) {
            return 0;
        } else {
            return uint48(block.timestamp) - _finalizationStreakStartedAt;
        }
    }

    // ---------------------------------------------------------------
    // Overrides
    // ---------------------------------------------------------------

    /// @dev Initialize the state of this feature contract right after activation
    function _afterActivate() internal virtual override {
        _finalizationStreakStartedAt = uint48(block.timestamp);
        super._afterActivate();
    }

    /// @dev Reset the finalization streak if the grace period has been crossed
    function _beforeProve() internal virtual override {
        if (
            block.timestamp - _coreState.lastFinalizedTimestamp
                > maxFinalizationDelayBeforeStreakReset
        ) {
            _finalizationStreakStartedAt = uint48(block.timestamp);
        }
        super._beforeProve();
    }
}
