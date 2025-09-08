// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized4 } from "contracts/layer1/shasta/impl/InboxOptimized4.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxOptimized4
/// @notice Test implementation of InboxOptimized4 that can be instantiated
contract TestInboxOptimized4 is InboxOptimized4 {
    constructor(IInbox.Config memory _config) InboxOptimized4(_config) { }
}