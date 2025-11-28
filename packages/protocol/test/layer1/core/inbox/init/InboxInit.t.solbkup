// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInbox } from "../implementations/TestInbox.sol";
import { AbstractInitTest } from "./AbstractInit.t.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxInit is AbstractInitTest {
    function _deployImplementation() internal override returns (Inbox) {
        return new TestInbox(
            address(codec),
            address(bondToken),
            address(checkpointManager),
            address(proofVerifier),
            address(proposerChecker)
        );
    }
}
