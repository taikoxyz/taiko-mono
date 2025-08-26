// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractProposeTest } from "./AbstractProposeTest.t.sol";
import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized2Propose
/// @notice Test suite for propose functionality on Optimized2 Inbox implementation
contract InboxOptimized2Propose is AbstractProposeTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "InboxOptimized2";
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
            new TestInboxOptimized2(
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