// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInbox } from "../implementations/TestInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { CodecSimple } from "src/layer1/shasta/impl/CodecSimple.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxDeployer
/// @notice Deployer for the standard Inbox implementation
contract InboxDeployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "Inbox";
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
        address simpleCodec = address(new CodecSimple());
        address impl = address(
            new TestInbox(
                simpleCodec, bondToken, maxCheckpointHistory, proofVerifier, proposerChecker
            )
        );

        TestInbox inbox = TestInbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.initV3, (Alice, bytes32(uint256(1))))
            })
        );

        return inbox;
    }
}
