// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTest } from "../base/InboxTest.t.sol";
import { TestInbox } from "./TestInbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";

/// @title InboxTest
/// @notice Test suite for simple Inbox implementation
/// @custom:security-contact security@taiko.xyz
contract InboxSimpleTest is InboxTest {
    function getTestContractName() internal pure override returns (string memory) {
        return "Inbox";
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
            new TestInbox(
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
