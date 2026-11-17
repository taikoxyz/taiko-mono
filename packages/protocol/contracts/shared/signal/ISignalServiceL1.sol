// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ISignalService } from "./ISignalService.sol";

/// @title ISignalServiceL1
/// @notice The L1 SignalService used when an Unzen network switches to Etna.
/// @dev Keeps the existing checkpoint and signal API while authorizing both Inbox proxies.
/// @custom:security-contact security@taiko.xyz
interface ISignalServiceL1 is ISignalService {
    /// @notice Returns the Unzen Inbox authorized to save checkpoints.
    /// @dev After the Etna start is written, its checkpoints cannot be above the start height.
    /// @return unzenInbox_ The Unzen Inbox proxy address.
    function unzenInbox() external view returns (address unzenInbox_);

    /// @notice Returns the Etna Inbox authorized to save checkpoints.
    /// @dev The SignalService reads this proxy's Etna start to bound Unzen checkpoints.
    /// @return etnaInbox_ The Etna Inbox proxy address.
    function etnaInbox() external view returns (address etnaInbox_);
}
