// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProve.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";

/// @title InboxProve
/// @notice Test suite for prove functionality on standard Inbox implementation
contract InboxProve is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}
