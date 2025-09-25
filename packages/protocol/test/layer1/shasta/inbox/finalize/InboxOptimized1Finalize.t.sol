// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractFinalizeTest } from "./AbstractFinalizeTest.t.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";

/// @title InboxOptimized1Finalize
/// @notice Finalize tests for InboxOptimized1 implementation
contract InboxOptimized1Finalize is AbstractFinalizeTest {
    function setUp() public override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }
}