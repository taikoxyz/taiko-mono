// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized2Deployer } from "../deployers/InboxOptimized2Deployer.sol";

/// @title InboxOptimized2Propose
/// @notice Test suite for propose functionality on Optimized2 Inbox implementation
contract InboxOptimized2Propose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized2Deployer());
        super.setUp();
    }
}
