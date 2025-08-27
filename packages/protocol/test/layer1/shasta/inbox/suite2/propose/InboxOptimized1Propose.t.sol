// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized1Base } from "../base/InboxOptimized1Base.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized1Propose
/// @notice Test suite for propose functionality on Optimized1 Inbox implementation
contract InboxOptimized1Propose is AbstractProposeTest, InboxOptimized1Base {
    function setUp() public virtual override(AbstractProposeTest, CommonTest) {
        AbstractProposeTest.setUp();
    }
    function getTestContractName() 
        internal 
        pure 
        override(AbstractProposeTest, InboxOptimized1Base) 
        returns (string memory) 
    {
        return InboxOptimized1Base.getTestContractName();
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override(AbstractProposeTest, InboxOptimized1Base)
        returns (Inbox)
    {
        return InboxOptimized1Base.deployInbox(
            bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}