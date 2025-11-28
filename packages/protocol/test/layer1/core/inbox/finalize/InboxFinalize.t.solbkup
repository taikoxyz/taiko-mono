// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { AbstractFinalizeTest } from "./AbstractFinalize.t.sol";

/// @title InboxFinalize
/// @notice Finalization tests for the standard Inbox implementation
contract InboxFinalize is AbstractFinalizeTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}
