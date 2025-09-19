// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized4Deployer } from "../deployers/InboxOptimized4Deployer.sol";

/// @title InboxOptimized4Propose
/// @notice Test suite for propose functionality on Optimized4 Inbox implementation
contract InboxOptimized4Propose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized4Deployer());
        super.setUp();
    }
}