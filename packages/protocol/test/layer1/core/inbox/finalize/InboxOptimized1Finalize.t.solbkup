// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractOptimizedFinalize } from "./AbstractOptimizedFinalize.t.sol";

/// @title InboxOptimized1Finalize
/// @notice Finalization tests for the InboxOptimized1 implementation
contract InboxOptimized1Finalize is AbstractOptimizedFinalize {
    function _createDeployer() internal override returns (IInboxDeployer) {
        return new InboxOptimized1Deployer();
    }
}
