// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { InboxOptimized2Deployer } from "../deployers/InboxOptimized2Deployer.sol";
import { AbstractOptimizedFinalize } from "./AbstractOptimizedFinalize.t.sol";

/// @title InboxOptimized2Finalize
/// @notice Finalization tests for the InboxOptimized2 implementation
contract InboxOptimized2Finalize is AbstractOptimizedFinalize {
    function _createDeployer() internal override returns (IInboxDeployer) {
        return new InboxOptimized2Deployer();
    }
}
