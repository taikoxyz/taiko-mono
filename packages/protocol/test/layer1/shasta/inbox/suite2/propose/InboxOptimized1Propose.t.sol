// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized1Propose
/// @notice Test suite for propose functionality on Optimized1 Inbox implementation
contract InboxOptimized1Propose is AbstractProposeTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "InboxOptimized1";
    }

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        override
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized1(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (owner, GENESIS_BLOCK_HASH))
            })
        );
    }
}