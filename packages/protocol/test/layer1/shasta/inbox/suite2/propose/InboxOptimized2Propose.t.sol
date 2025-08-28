// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { InboxOptimized2Base } from "../base/InboxOptimized2Base.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized2Propose
/// @notice Test suite for propose functionality on Optimized2 Inbox implementation
contract InboxOptimized2Propose is AbstractProposeTest, InboxOptimized2Base {
    function setUp() public virtual override(AbstractProposeTest, CommonTest) {
        AbstractProposeTest.setUp();
    }

    function getTestContractName()
        internal
        pure
        override(AbstractProposeTest, InboxOptimized2Base)
        returns (string memory)
    {
        return InboxOptimized2Base.getTestContractName();
    }

    function deployInbox(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override(AbstractProposeTest, InboxOptimized2Base)
        returns (Inbox)
    {
        return InboxOptimized2Base.deployInbox(
            bondToken, checkpointManager, proofVerifier, proposerChecker, forcedInclusionStore
        );
    }
}
