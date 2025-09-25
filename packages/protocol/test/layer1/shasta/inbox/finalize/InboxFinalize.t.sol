// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractFinalizeTest } from "./AbstractFinalizeTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";

/// @title InboxFinalize
/// @notice Finalize tests for the basic Inbox implementation
contract InboxFinalize is AbstractFinalizeTest {
    function setUp() public override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}