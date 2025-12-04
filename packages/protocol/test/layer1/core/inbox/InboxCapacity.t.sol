// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ProposeTestBase } from "./InboxPropose.t.sol";
import { InboxTestBase, InboxVariant } from "./InboxTestBase.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

/// @notice Capacity-focused tests with a small ring buffer to exercise bounds.
abstract contract CapacityBase is ProposeTestBase {
    constructor(InboxVariant _variant) ProposeTestBase(_variant) { }

    function test_propose_RevertWhen_CapacityExceeded() public {
        _setBlobHashes(3);
        _nextBlock();
        _proposeAndDecode(_defaultProposeInput());

        _nextBlock();
        _proposeAndDecode(_defaultProposeInput());

        _nextBlock();
        bytes memory encodedInput = codec.encodeProposeInput(_defaultProposeInput());
        vm.expectRevert(Inbox.NotEnoughCapacity.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    function _nextBlock() private {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        IInbox.Config memory cfg = super._buildConfig();
        cfg.ringBufferSize = 3;
        return cfg;
    }
}

contract InboxCapacityTest is CapacityBase {
    constructor() CapacityBase(InboxVariant.Simple) { }
}

contract InboxOptimizedCapacityTest is CapacityBase {
    constructor() CapacityBase(InboxVariant.Optimized) { }
}
