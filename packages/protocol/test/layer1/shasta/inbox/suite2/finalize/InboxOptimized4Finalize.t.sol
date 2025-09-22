// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractFinalizeTest } from "./AbstractFinalizeTest.t.sol";
import { InboxOptimized4Deployer } from "../deployers/InboxOptimized4Deployer.sol";

/// @title InboxOptimized4Finalize
/// @notice Finalize tests for InboxOptimized4 implementation
contract InboxOptimized4Finalize is AbstractFinalizeTest {
    function setUp() public override {
        setDeployer(new InboxOptimized4Deployer());
        super.setUp();
    }
}