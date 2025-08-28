// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized1Base.
abstract contract InboxOptimized1Base is CommonTest {
    function getTestContractName() internal pure virtual returns (string memory) {
        return "InboxOptimized1";
    }

    function deployInbox(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        virtual
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized1(
                bondToken, checkpointManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        TestInboxOptimized1 inbox = TestInboxOptimized1(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (Alice, bytes32(uint256(1))))
            })
        );

        inbox.fillTransitionRecordBuffer();

        return inbox;
    }
}
