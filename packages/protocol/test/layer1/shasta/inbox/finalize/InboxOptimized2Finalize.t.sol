// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractFinalizeTest } from "./AbstractFinalizeTest.t.sol";
import { InboxOptimized2Deployer } from "../deployers/InboxOptimized2Deployer.sol";

/// @title InboxOptimized2Finalize
/// @notice Finalize tests for InboxOptimized2 implementation
contract InboxOptimized2Finalize is AbstractFinalizeTest {
    function setUp() public override {
        setDeployer(new InboxOptimized2Deployer());
        super.setUp();
    }
}