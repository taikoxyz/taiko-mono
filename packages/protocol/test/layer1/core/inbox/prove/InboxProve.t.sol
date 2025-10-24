// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";

/// @title InboxProve
/// @notice Test suite for prove functionality on standard Inbox implementation
contract InboxProve is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}
