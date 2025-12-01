// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ProposeTestBase } from "./InboxPropose.t.sol";
import { InboxOptimizedBase, InboxSimpleBase, InboxTestBase } from "../common/InboxTestBase.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import { MockCheckpointStore, MockERC20, MockProofVerifier } from "../mocks/MockContracts.sol";
import { MockProposerChecker } from "../mocks/MockProposerChecker.sol";

/// @notice Capacity-focused tests with a small ring buffer to exercise bounds.
abstract contract CapacityBase is ProposeTestBase {
    function setUp() public virtual override(InboxTestBase) {
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);

        token = new MockERC20();
        verifier = new MockProofVerifier();
        checkpointStore = new MockCheckpointStore();
        proposerChecker = new MockProposerChecker();

        config = IInbox.Config({
            bondToken: address(token),
            codec: address(new CodecOptimized()),
            checkpointStore: address(checkpointStore),
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            ringBufferSize: 3,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 0,
            permissionlessInclusionMultiplier: 5
        });

        inbox = _deployInbox();
        inbox.activate(bytes32(uint256(1)));

        vm.roll(100);
        vm.warp(1_000);
    }

    function test_propose_RevertWhen_CapacityExceeded() public {
        _setBlobHashes(3);
        _nextBlock();
        _proposeAndDecode(_defaultProposeInput());

        _nextBlock();
        _proposeAndDecode(_defaultProposeInput());

        _nextBlock();
        vm.prank(proposer);
        vm.expectRevert(Inbox.NotEnoughCapacity.selector);
        inbox.propose(bytes(""), _encodeProposeInput(_defaultProposeInput()));
    }

    function _nextBlock() private {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }
}

contract InboxCapacityTest is CapacityBase, InboxSimpleBase {
    function setUp() public override(CapacityBase, InboxTestBase) {
        CapacityBase.setUp();
    }
}

contract InboxOptimizedCapacityTest is CapacityBase, InboxOptimizedBase {
    function setUp() public override(CapacityBase, InboxTestBase) {
        CapacityBase.setUp();
    }

    function _isOptimized() internal view override(InboxOptimizedBase, InboxTestBase) returns (bool) {
        return true;
    }
}
