// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized } from "src/layer1/shasta/impl/InboxOptimized.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title TestInboxOptimized
/// @notice Test contract for InboxOptimized
/// @custom:security-contact security@taiko.xyz
contract TestInboxOptimized is InboxOptimized {
    IInbox.Config private config;

    constructor(IInbox.Config memory _config) {
        config = _config;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return config;
    }
}
