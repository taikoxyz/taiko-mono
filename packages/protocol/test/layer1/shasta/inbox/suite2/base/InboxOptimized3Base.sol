// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxOptimized3Base
/// @notice Base contract providing deployment logic for InboxOptimized3 implementation
abstract contract InboxOptimized3Base is CommonTest {
    function getTestContractName() internal pure virtual returns (string memory) {
        return "InboxOptimized3";
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
            new TestInboxOptimized3(
                bondToken, checkpointManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );

        TestInboxOptimized3 inbox = TestInboxOptimized3(
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
