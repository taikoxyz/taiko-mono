// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized3Deployer } from "../deployers/InboxOptimized3Deployer.sol";

/// @title InboxOptimized3Propose
/// @notice Test suite for propose functionality on Optimized3 Inbox implementation
contract InboxOptimized3Propose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized3Deployer());
        super.setUp();
    }
}
