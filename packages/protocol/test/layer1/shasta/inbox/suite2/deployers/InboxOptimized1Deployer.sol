// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { SimpleCodec } from "src/layer1/shasta/impl/SimpleCodec.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized1Deployer
/// @notice Deployer for the InboxOptimized1 implementation
contract InboxOptimized1Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized1";
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
        address simpleCodec = address(new SimpleCodec());
        address impl = address(
            new TestInboxOptimized1(
                simpleCodec, bondToken, maxCheckpointHistory, proofVerifier, proposerChecker
            )
        );

        TestInboxOptimized1 inbox = TestInboxOptimized1(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.initV3, (Alice, bytes32(uint256(1))))
            })
        );

        return inbox;
    }
}
