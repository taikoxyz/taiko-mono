// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized3Propose
/// @notice Test suite for propose functionality on Optimized3 Inbox implementation
contract InboxOptimized3Propose is AbstractProposeTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "InboxOptimized3";
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
            new TestInboxOptimized3(
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