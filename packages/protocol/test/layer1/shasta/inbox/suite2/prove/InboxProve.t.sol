// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { InboxBase } from "../base/InboxBase.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxProve
/// @notice Test suite for prove functionality on simple Inbox implementation
contract InboxProve is AbstractProveTest, InboxBase {
    function setUp() public virtual override(AbstractProveTest, CommonTest) {
        AbstractProveTest.setUp();
    }
    function getTestContractName() 
        internal 
        pure 
        override(AbstractProveTest, InboxBase) 
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
        override(AbstractProveTest, InboxBase)
        returns (Inbox)
    {
        return InboxBase.deployInbox(
            bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}