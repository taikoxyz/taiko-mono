// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInbox } from "../implementations/TestInbox.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxBase
/// @notice Base contract providing deployment logic for basic Inbox implementation
abstract contract InboxBase is CommonTest {

    function getTestContractName() internal pure virtual returns (string memory) {
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
        virtual
        returns (Inbox)
    {
        address impl = address(
            new TestInbox(
                bondToken, syncedBlockManager, proofVerifier, proposerChecker, forcedInclusionStore
            )
        );
        
        return Inbox(
            deploy({
                name: "",
                impl: impl,
                data: abi.encodeCall(Inbox.init, (Alice, bytes32(uint256(1))))
            })
        );
    }
}