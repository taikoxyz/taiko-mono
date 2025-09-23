// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "./IInboxDeployer.sol";
import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { InboxOptimized2Helper } from "src/layer1/shasta/impl/InboxOptimized2Helper.sol";
import { IInboxCodec } from "src/layer1/shasta/iface/IInboxCodec.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";

/// @title InboxOptimized2Deployer
/// @notice Deployer for the InboxOptimized2 implementation
contract InboxOptimized2Deployer is InboxTestHelper, IInboxDeployer {
    /// @inheritdoc IInboxDeployer
    function getTestContractName() external pure returns (string memory) {
        return "InboxOptimized2";
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
            new TestInboxOptimized2(bondToken, maxCheckpointHistory, proofVerifier, proposerChecker)
        );

        TestInboxOptimized2 inbox = TestInboxOptimized2(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.initV3, (Alice, bytes32(uint256(1))))
            })
        );

        return inbox;
    }

    /// @inheritdoc IInboxDeployer
    function deployCodec() external returns (IInboxCodec) {
        // InboxOptimized2 uses optimized encoding/hashing
        return new InboxOptimized2Helper();
    }
}
