// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxDeployer } from "../deployers/InboxDeployer.sol";

/// @title InboxProve
/// @notice Test suite for prove functionality on standard Inbox implementation
contract InboxProve is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }

    function _getExpectedAggregationBehavior(
        uint256 proposalCount,
        bool consecutive
    )
        internal
        pure
        override
        returns (uint256 expectedEvents, uint256 expectedMaxSpan)
    {
        if (consecutive) {
            return (1, proposalCount); // One event with span=proposalCount (aggregation built-in)
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }
}
