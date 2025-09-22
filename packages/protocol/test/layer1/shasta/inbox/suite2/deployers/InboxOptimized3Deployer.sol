// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized3 } from "../implementations/TestInboxOptimized3.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized3Deployer
/// @notice Deployer for the InboxOptimized3 implementation
contract InboxOptimized3Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized3";
    }

    /// @inheritdoc IInboxDeployer
    function deployInbox(
        address bondToken,
        uint16 maxCheckpointHistory,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox)
    {
        address impl = address(
            new TestInboxOptimized3(bondToken, maxCheckpointHistory, proofVerifier, proposerChecker)
        );

        TestInboxOptimized3 inbox = TestInboxOptimized3(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.initV3, (Alice, bytes32(uint256(1))))
            })
        );

        return inbox;
    }
}
