// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTest } from "../base/InboxTest.t.sol";
import { TestInboxOptimized2 } from "./TestInbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized2Test
/// @notice Test suite for Optimized2 Inbox implementation
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized2Test is InboxTest {
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
