// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2Deployer } from "../deployers/InboxOptimized2Deployer.sol";
import { AbstractFinalizeTest } from "./AbstractFinalize.t.sol";

/// @title InboxOptimized2Finalize
/// @notice Finalization tests for the InboxOptimized2 implementation
contract InboxOptimized2Finalize is AbstractFinalizeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized2Deployer());
        super.setUp();
    }
}
