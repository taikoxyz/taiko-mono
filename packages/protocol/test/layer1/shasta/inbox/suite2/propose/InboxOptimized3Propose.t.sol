// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized3Base } from "../base/InboxOptimized3Base.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized3Propose
/// @notice Test suite for propose functionality on Optimized3 Inbox implementation
contract InboxOptimized3Propose is AbstractProposeTest, InboxOptimized3Base {
    function setUp() public virtual override(AbstractProposeTest, CommonTest) {
        AbstractProposeTest.setUp();
    }

    function getTestContractName()
        internal
        pure
        override(AbstractProposeTest, InboxOptimized3Base)
        returns (string memory)
    {
        return InboxOptimized3Base.getTestContractName();
    }

    function deployInbox(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override(AbstractProposeTest, InboxOptimized3Base)
        returns (Inbox)
    {
        return InboxOptimized3Base.deployInbox(
            bondToken, checkpointManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}
