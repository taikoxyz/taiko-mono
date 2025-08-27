// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxOptimized2Base } from "../base/InboxOptimized2Base.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized2Prove
/// @notice Test suite for prove functionality on InboxOptimized2 implementation
contract InboxOptimized2Prove is AbstractProveTest, InboxOptimized2Base {
    function setUp() public virtual override(AbstractProveTest, CommonTest) {
        AbstractProveTest.setUp();
    }

    function getTestContractName()
        internal
        pure
        override(AbstractProveTest, InboxOptimized2Base)
        returns (string memory)
    {
        return InboxOptimized2Base.getTestContractName();
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

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override(AbstractProveTest, InboxOptimized2Base)
        returns (Inbox)
    {
        return InboxOptimized2Base.deployInbox(
            bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}
