// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { AbstractProveTest } from "./AbstractProveTest.t.sol";
import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title InboxOptimized1Prove
/// @notice Test suite for prove functionality on InboxOptimized1 implementation
contract InboxOptimized1Prove is AbstractProveTest {
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
        // Deploy implementation
        address impl = address(
            new TestInboxOptimized1(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        // Deploy proxy using the helper function
        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (owner, GENESIS_BLOCK_HASH))
            })
        );
    }
}