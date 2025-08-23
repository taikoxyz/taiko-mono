// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTest } from "../base/InboxTest.t.sol";
import { SimpleInbox } from "./SimpleInbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized3Test
/// @notice Test suite for Optimized3 Inbox implementation
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized3Test is InboxTest {
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
        // TODO: Deploy actual InboxOptimized3 implementation
        // For now, using the same SimpleInbox
        address impl = address(
            new SimpleInbox(
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
