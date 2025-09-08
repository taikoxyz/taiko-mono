// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxOptimized4Deployer } from "../deployers/InboxOptimized4Deployer.sol";

/// @title InboxOptimized4Prove
/// @notice Test suite for prove functionality on InboxOptimized4 implementation
contract InboxOptimized4Prove is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized4Deployer());
        super.setUp();
    }

}