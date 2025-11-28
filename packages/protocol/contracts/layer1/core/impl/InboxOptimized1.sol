// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { Inbox } from "./Inbox.sol";

/// @title InboxOptimized1
/// @notice Compatibility wrapper that reuses the optimized Inbox implementation.
contract InboxOptimized1 is Inbox {
    constructor(IInbox.Config memory _config) Inbox(_config) { }
}
