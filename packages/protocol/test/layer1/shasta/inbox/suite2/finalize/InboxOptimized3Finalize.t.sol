// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractFinalizeTest } from "./AbstractFinalizeTest.t.sol";
import { InboxOptimized3Deployer } from "../deployers/InboxOptimized3Deployer.sol";

/// @title InboxOptimized3Finalize
/// @notice Finalize tests for InboxOptimized3 implementation
contract InboxOptimized3Finalize is AbstractFinalizeTest {
    function setUp() public override {
        setDeployer(new InboxOptimized3Deployer());
        super.setUp();
    }
}