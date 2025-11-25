// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { IMessageInvocable } from "src/shared/bridge/IBridge.sol";

/// @title IPreconfSlasherL1
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasherL1 is IMessageInvocable {
    struct SlashAmount {
        uint256 livenessFault;
        uint256 safetyFault;
    }

    /// @notice Called by the URC to slash for preconfirmation faults.
    /// @param _commitment The preconfirmation commitment
    /// @param _evidence Evidence for the detected fault
    /// @return Slash amount applied for the given evidence and commitment
    function slash(
        ISlasher.Commitment calldata _commitment,
        bytes calldata _evidence,
        address _challenger
    )
        external
        view
        returns (uint256);

    /// @notice Returns the slash amount for each violation type
    /// @return slashAmount The slash amount for each violation type
    function getSlashAmount() external pure returns (SlashAmount memory slashAmount);
}
