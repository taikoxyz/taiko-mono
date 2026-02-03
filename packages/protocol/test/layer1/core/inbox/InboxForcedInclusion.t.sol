// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";

/// @notice Tests for forced inclusion functionality
contract InboxForcedInclusionTest is InboxTestBase {
    LibForcedInclusion.Storage private feeStore;

    function test_saveForcedInclusion_refundsExcessPayment() public {
        // First propose to enable forced inclusions
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });

        uint256 requiredFee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        uint256 excessPayment = 1 ether;
        uint256 totalPayment = requiredFee + excessPayment;

        uint256 balanceBefore = proposer.balance;

        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: totalPayment }(forcedRef);

        uint256 balanceAfter = proposer.balance;

        // Should have been refunded the excess
        assertEq(balanceBefore - balanceAfter, requiredFee, "only required fee deducted");
    }

    function test_saveForcedInclusion_RevertWhen_InsufficientFee() public {
        // First propose to enable forced inclusions
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });

        uint256 requiredFee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        uint256 insufficientFee = requiredFee - 1;

        vm.expectRevert(LibForcedInclusion.InsufficientFee.selector);
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: insufficientFee }(forcedRef);
    }

    function test_saveForcedInclusion_RevertWhen_MultipleBlobsProvided() public {
        // First propose to enable forced inclusions
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Try to save forced inclusion with 2 blobs (not allowed)
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 0 });

        uint256 requiredFee = inbox.getCurrentForcedInclusionFee() * 1 gwei;

        vm.expectRevert(LibForcedInclusion.OnlySingleBlobAllowed.selector);
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: requiredFee }(forcedRef);
    }

    function test_getForcedInclusions_returnsEmptyWhen_StartBelowHead() public {
        // First propose to enable forced inclusions
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Save one forced inclusion
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(forcedRef);

        // Process the forced inclusion
        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        _proposeAndDecode(input);

        // Now head = 1, tail = 1, so start = 0 is below head
        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(0, 10);
        assertEq(inclusions.length, 0, "should return empty array");
    }

    function test_getForcedInclusions_returnsEmptyWhen_StartAtOrAboveTail() public {
        // First propose to enable forced inclusions
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Save one forced inclusion
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(forcedRef);

        // Now head = 0, tail = 1, so start = 1 is at tail (invalid)
        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(1, 10);
        assertEq(inclusions.length, 0, "should return empty array");

        // Also test start > tail
        inclusions = inbox.getForcedInclusions(5, 10);
        assertEq(inclusions.length, 0, "should return empty array for start > tail");
    }

    function test_getForcedInclusions_returnsEmptyWhen_MaxCountZero() public {
        // First propose to enable forced inclusions
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Save one forced inclusion
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(forcedRef);

        // Request with maxCount = 0
        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(0, 0);
        assertEq(inclusions.length, 0, "should return empty array");
    }

    function test_getForcedInclusions_returnsCorrectSubset() public {
        // First propose to enable forced inclusions
        _setBlobHashes(4);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Save multiple forced inclusions
        for (uint256 i = 1; i <= 3; i++) {
            LibBlobs.BlobReference memory forcedRef =
                LibBlobs.BlobReference({ blobStartIndex: uint16(i), numBlobs: 1, offset: 0 });
            uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
            vm.prank(proposer);
            inbox.saveForcedInclusion{ value: fee }(forcedRef);
        }

        // Get all 3
        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(0, 10);
        assertEq(inclusions.length, 3, "should return all 3 inclusions");
        assertEq(inclusions[0].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 1)), "idx0");
        assertEq(inclusions[1].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 2)), "idx1");
        assertEq(inclusions[2].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 3)), "idx2");

        // Get only 2
        inclusions = inbox.getForcedInclusions(0, 2);
        assertEq(inclusions.length, 2, "should return 2 inclusions");
        assertEq(inclusions[1].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 2)), "idx1");

        // Get from index 1
        inclusions = inbox.getForcedInclusions(1, 10);
        assertEq(inclusions.length, 2, "should return 2 inclusions starting from index 1");
        assertEq(inclusions[0].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 2)), "start1");
        assertEq(
            inclusions[1].blobSlice.blobHashes[0], keccak256(abi.encode("blob", 3)), "start1-next"
        );
    }

    function test_getCurrentForcedInclusionFee_scalesWithQueueDepth() public {
        // First propose to enable forced inclusions
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        uint64 baseFee = config.forcedInclusionFeeInGwei;
        uint64 threshold = config.forcedInclusionFeeDoubleThreshold;

        assertEq(inbox.getCurrentForcedInclusionFee(), baseFee, "base fee when empty");

        // Enqueue two inclusions and verify the fee scales with queue depth
        for (uint256 i; i < 2; ++i) {
            LibBlobs.BlobReference memory forcedRef =
                LibBlobs.BlobReference({ blobStartIndex: uint16(i + 1), numBlobs: 1, offset: 0 });
            uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
            vm.prank(proposer);
            inbox.saveForcedInclusion{ value: fee }(forcedRef);
        }

        uint64 expectedFee = uint64((uint256(baseFee) * (threshold + 2)) / threshold);
        assertEq(inbox.getCurrentForcedInclusionFee(), expectedFee, "fee scales linearly");
    }

    function test_getCurrentForcedInclusionFee_matchesFormulaAndIsMonotonic() public {
        // First propose to enable forced inclusions
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        _setBlobHashes(2);

        uint64 baseFee = config.forcedInclusionFeeInGwei;
        uint64 threshold = config.forcedInclusionFeeDoubleThreshold;

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });

        uint64 prevFee;
        for (uint256 numPending; numPending < 10; ++numPending) {
            uint64 actualFee = inbox.getCurrentForcedInclusionFee();

            uint256 multipliedFee = uint256(baseFee) * (uint256(threshold) + numPending);
            uint256 expected256 = multipliedFee / uint256(threshold);
            if (expected256 > type(uint64).max) expected256 = type(uint64).max;

            assertEq(actualFee, uint64(expected256), "fee formula mismatch");
            if (numPending > 0) assertGe(actualFee, prevFee, "fee must be non-decreasing");
            prevFee = actualFee;

            uint256 requiredFee = uint256(actualFee) * 1 gwei;
            vm.prank(proposer);
            inbox.saveForcedInclusion{ value: requiredFee }(forcedRef);
        }
    }

    function test_getCurrentForcedInclusionFee_saturatesAtUint64Max() public {
        feeStore.head = 0;
        feeStore.tail = type(uint48).max;

        uint64 actual =
            LibForcedInclusion.getCurrentForcedInclusionFee(feeStore, type(uint64).max, 1);
        assertEq(actual, type(uint64).max, "fee should saturate at max uint64");
    }

    function test_getForcedInclusionState_tracksQueueProgress() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Enqueue two inclusions with different timestamps so only the first becomes due.
        uint48 firstInclusionTimestamp = uint48(block.timestamp);

        LibBlobs.BlobReference memory forcedRef1 =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(forcedRef1);

        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);

        LibBlobs.BlobReference memory forcedRef2 =
            LibBlobs.BlobReference({ blobStartIndex: 2, numBlobs: 1, offset: 0 });
        fee = inbox.getCurrentForcedInclusionFee() * 1 gwei;
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: fee }(forcedRef2);

        (uint48 headBefore, uint48 tailBefore) = inbox.getForcedInclusionState();
        assertEq(headBefore, 0, "head before processing");
        assertEq(tailBefore, 2, "tail after enqueues");

        vm.warp(uint256(firstInclusionTimestamp) + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        _setBlobHashes(1);
        _proposeAndDecode(input);

        (uint48 headAfter, uint48 tailAfter) = inbox.getForcedInclusionState();
        assertEq(headAfter, 1, "head after consuming one");
        assertEq(tailAfter, 2, "tail unchanged after consume");

        IForcedInclusionStore.ForcedInclusion[] memory remaining = inbox.getForcedInclusions(1, 1);
        assertEq(remaining.length, 1, "one inclusion remains");
        assertEq(
            remaining[0].blobSlice.blobHashes[0],
            keccak256(abi.encode("blob", 2)),
            "second inclusion preserved"
        );
    }
}

/// @notice Tests for LibBlobs error cases
contract LibBlobsTest is InboxTestBase {
    function test_propose_RevertWhen_NoBlobsProvided() public {
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.blobReference.numBlobs = 0;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(LibBlobs.NoBlobs.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    function test_propose_RevertWhen_BlobNotFound() public {
        // Set only 1 blob hash but reference blob index 5
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.blobReference.blobStartIndex = 5; // Invalid index

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(LibBlobs.BlobNotFound.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }
}
