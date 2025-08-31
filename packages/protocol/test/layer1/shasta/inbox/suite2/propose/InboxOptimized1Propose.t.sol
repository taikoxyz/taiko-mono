// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";

/// @title InboxOptimized1Propose
/// @notice Test suite for propose functionality on Optimized1 Inbox implementation
contract InboxOptimized1Propose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }
}
