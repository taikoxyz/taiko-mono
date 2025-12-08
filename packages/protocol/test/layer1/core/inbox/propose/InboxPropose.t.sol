// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { AbstractProposeTest } from "./AbstractPropose.t.sol";

/// @title InboxPropose
/// @notice Test suite for propose functionality on standard Inbox implementation
contract InboxPropose is AbstractProposeTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}
