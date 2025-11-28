// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized1 } from "../implementations/TestInboxOptimized1.sol";
import { AbstractInitTest } from "./AbstractInit.t.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxOptimized1Init is AbstractInitTest {
    function _deployImplementation() internal override returns (Inbox) {
        return new TestInboxOptimized1(
            address(codec),
            address(bondToken),
            address(checkpointManager),
            address(proofVerifier),
            address(proposerChecker)
        );
    }
}
