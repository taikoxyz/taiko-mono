// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxWithSlotOptimization } from "./InboxWithSlotOptimization.sol";

/// @title Inbox
/// @notice Default inbox implementation with storage slot optimization
/// @dev Inherits from InboxWithSlotOptimization for backward compatibility
/// @custom:security-contact security@taiko.xyz
abstract contract Inbox is InboxWithSlotOptimization {
    /// @notice Initializes the Inbox contract
    constructor() InboxWithSlotOptimization() { }

    // This contract now simply inherits from InboxWithSlotOptimization
    // All functionality is provided by the parent contracts
}
