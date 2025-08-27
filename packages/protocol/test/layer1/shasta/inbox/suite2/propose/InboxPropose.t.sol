// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxBase } from "../base/InboxBase.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxPropose
/// @notice Test suite for propose functionality on simple Inbox implementation
contract InboxPropose is AbstractProposeTest, InboxBase {
    function setUp() public virtual override(AbstractProposeTest, CommonTest) {
        AbstractProposeTest.setUp();
    }
    function getTestContractName() 
        internal 
        pure 
        override(AbstractProposeTest, InboxBase) 
        returns (string memory) 
    {
        return InboxBase.getTestContractName();
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override(AbstractProposeTest, InboxBase)
        returns (Inbox)
    {
        return InboxBase.deployInbox(
            bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}