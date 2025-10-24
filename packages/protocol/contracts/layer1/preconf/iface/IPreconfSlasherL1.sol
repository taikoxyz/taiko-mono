// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISlasher} from "@eth-fabric/urc/ISlasher.sol";
import {IBridge, IMessageInvocable} from "src/shared/bridge/IBridge.sol";

/// @title IPreconfSlasherL1
/// @dev This contract inherits from ISlasher which contains the definition for the `slash` function
/// that is called by the URC.
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasherL1 is ISlasher, IMessageInvocable {
    struct SlashAmount {
        uint256 livenessFault;
        uint256 safetyFault;
    }

    error CallerIsNotPreconfSlasherL2();
    error ChallengerIsNotSelf();
    error CallerIsNotURC();
    error MissedSlot();

    /// @notice Returns the slash amount for each violation type
    /// @return slashAmount The slash amount for each violation type
    function getSlashAmount() external pure returns (SlashAmount memory slashAmount);
}
