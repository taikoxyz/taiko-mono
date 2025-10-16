// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractFinalizeTest } from "./AbstractFinalize.t.sol";

/// @title InboxOptimized1Finalize
/// @notice Finalization tests for the InboxOptimized1 implementation
contract InboxOptimized1Finalize is AbstractFinalizeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }
}
