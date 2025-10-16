// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";

/// @title InboxOptimized1Prove
/// @notice Test suite for prove functionality on InboxOptimized1 implementation
contract InboxOptimized1Prove is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
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
            return (1, proposalCount); // One event with span=proposalCount
        } else {
            return (proposalCount, 1); // Individual events for gaps
        }
    }
}
