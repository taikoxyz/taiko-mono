// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";

/// @dev Provides a concrete store so tests can call the library
//  functions that depend on contract state.
contract LibForcedInclusionHarness is IForcedInclusionStore {
    using LibForcedInclusion for LibForcedInclusion.Storage;

    LibForcedInclusion.Storage private _store;
    uint64 private _baseFeeInGwei;
    uint64 private _feeDoubleThreshold;

    constructor() {
        _baseFeeInGwei = 10_000_000;
        _feeDoubleThreshold = 100;
    }

    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference)
        external
        payable
        override
    {
        uint256 refund = _store.saveForcedInclusion(_baseFeeInGwei, _feeDoubleThreshold, _blobReference);
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function isOldestForcedInclusionDue() external view override returns (bool) {
        return _store.isOldestForcedInclusionDue(0);
    }

    function getCurrentForcedInclusionFee() external view override returns (uint64 feeInGwei_) {
        return _store.getCurrentForcedInclusionFee(_baseFeeInGwei, _feeDoubleThreshold);
    }

    function save(
        uint64 baseFeeInGwei,
        uint64 feeDoubleThreshold,
        LibBlobs.BlobReference memory _blobReference
    )
        external
        payable
        returns (uint256 refund_)
    {
        refund_ = _store.saveForcedInclusion(baseFeeInGwei, feeDoubleThreshold, _blobReference);
        if (refund_ > 0) {
            payable(msg.sender).transfer(refund_);
        }
    }

    function isDue(uint16 _delay) external view returns (bool) {
        return _store.isOldestForcedInclusionDue(_delay);
    }

    function getCurrentForcedInclusionFee(uint64 baseFeeInGwei, uint64 feeDoubleThreshold)
        external
        view
        returns (uint64)
    {
        return _store.getCurrentForcedInclusionFee(baseFeeInGwei, feeDoubleThreshold);
    }

    function setConfig(uint64 baseFeeInGwei, uint64 feeDoubleThreshold) external {
        _baseFeeInGwei = baseFeeInGwei;
        _feeDoubleThreshold = feeDoubleThreshold;
    }

    function queue(uint48 _idx) external view returns (ForcedInclusion memory) {
        return _store.queue[_idx];
    }

    function head() external view returns (uint48) {
        return _store.head;
    }

    function tail() external view returns (uint48) {
        return _store.tail;
    }

    function setLastProcessedAt(uint48 _timestamp) external {
        _store.lastProcessedAt = _timestamp;
    }
}

contract LibForcedInclusionTest is Test {
    LibForcedInclusionHarness internal harness;

    function setUp() external {
        harness = new LibForcedInclusionHarness();
    }

    // ---------------------------------------------------------------
    // saveForcedInclusion
    // ---------------------------------------------------------------

    function test_saveForcedInclusion_PushesToQueue() external {
        bytes32[] memory hashes = _setupBlobHashes(2);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);
        uint64 baseFeeInGwei = 25;
        uint64 thresholdInGwei = 100;
        uint256 expectedFee = uint256(baseFeeInGwei) * 1 gwei;

        uint48 beforeCallTimestamp = uint48(block.timestamp);
        vm.expectEmit();
        emit IForcedInclusionStore
            .ForcedInclusionSaved(IForcedInclusionStore.ForcedInclusion({
                feeInGwei: baseFeeInGwei,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: _singleHashArray(hashes[0]),
                    offset: ref.offset,
                    timestamp: beforeCallTimestamp }) }));

        harness.save{ value: expectedFee }(baseFeeInGwei, thresholdInGwei, ref);

        assertEq(harness.head(), 0, "Head should remain zero");
        assertEq(harness.tail(), 1, "Tail should advance by one entry");

        IForcedInclusionStore.ForcedInclusion memory stored = harness.queue(0);
        assertEq(stored.feeInGwei, baseFeeInGwei);
        assertEq(stored.blobSlice.blobHashes.length, 1);
        assertEq(stored.blobSlice.offset, ref.offset);
        assertEq(stored.blobSlice.timestamp, uint48(block.timestamp));
    }

    function test_saveForcedInclusion_RevertWhen_InsufficientFee() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        vm.expectRevert(LibForcedInclusion.InsufficientFee.selector);
        harness.save{ value: 5 gwei }(10, 100, ref);
    }

    function test_saveForcedInclusion_RefundsExcessPayment() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        address user = address(0x1234);
        vm.deal(user, 1000 gwei);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        harness.save{ value: 300 gwei }(100, 100, ref); // Pay 300 gwei for 100 gwei fee

        uint256 balanceAfter = user.balance;

        // User should have paid exactly the required fee (100 gwei)
        assertEq(balanceBefore - balanceAfter, 100 gwei, "User should only pay required fee");

        // Verify inclusion was saved
        assertEq(harness.tail(), 1, "Tail should advance by one");
        assertEq(harness.queue(0).feeInGwei, 100, "Fee should be stored correctly");
    }

    function test_saveForcedInclusion_AcceptsExactFee() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        address user = address(0x1234);
        vm.deal(user, 1000 gwei);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        harness.save{ value: 100 gwei }(100, 100, ref);

        uint256 balanceAfter = user.balance;

        // User should have paid exactly the required fee
        assertEq(balanceBefore - balanceAfter, 100 gwei, "User should pay exact fee");

        // Verify inclusion was saved
        assertEq(harness.tail(), 1, "Tail should advance by one");
        assertEq(harness.queue(0).feeInGwei, 100, "Fee should be stored correctly");
    }

    // ---------------------------------------------------------------
    // Dynamic Fee Tests
    // ---------------------------------------------------------------

    function test_getCurrentForcedInclusionFee_BaseFeeWhenEmpty() external {
        // Queue is empty (0 pending), should return base fee
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 100, "Empty queue should use base fee");

        // Add 50 items - fee should be 1.5x base (150)
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);
        for (uint256 i = 0; i < 50; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 100, ref);
        }

        // At 50 pending: fee = 100 * (1 + 50/100) = 100 * 1.5 = 150
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 150, "At 50 pending, fee should be 1.5x base");
    }

    function test_getCurrentForcedInclusionFee_DoubleAtThreshold() external {
        // Add 100 items - fee should double at exactly 100 pending
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        for (uint256 i = 0; i < 100; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 100, ref);
        }

        // At 100 pending: fee = 100 * (1 + 100/100) = 100 * 2 = 200
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 200, "At 100 pending, fee should be 2x base");
    }

    function test_getCurrentForcedInclusionFee_TripleAtDoubleThreshold() external {
        

        // Add 200 items - fee should triple at 200 pending (2x threshold)
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        for (uint256 i = 0; i < 200; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 100, ref);
        }

        // At 200 pending: fee = 100 * (1 + 200/100) = 100 * 3 = 300
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 300, "At 200 pending, fee should be 3x base");
    }

    function test_getCurrentForcedInclusionFee_LinearScaling() external {
        

        // Add 150 items (1.5x threshold)
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        for (uint256 i = 0; i < 150; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 100, ref);
        }

        // At 150 pending: fee = 100 * (1 + 150/100) = 100 * 2.5 = 250
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 250, "At 150 pending, fee should be 2.5x base");
    }

    function test_getCurrentForcedInclusionFee_ThresholdBoundary() external {
        

        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        // Add 99 items - should NOT double yet
        for (uint256 i = 0; i < 99; i++) {
            uint64 fee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(fee) * 1 gwei }(100, 100, ref);
        }

        // At 99 pending: fee = 100 * (1 + 99/100) = 100 * 1.99 = 199
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 199, "At 99 pending, fee should be 1.99x base");

        // Add 1 more to reach exactly 100
        uint64 fee100 = harness.getCurrentForcedInclusionFee(100, 100);
        harness.save{ value: uint256(fee100) * 1 gwei }(100, 100, ref);

        // At 100 pending: fee = 100 * (1 + 100/100) = 100 * 2 = 200
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 200, "At 100 pending, fee should be exactly 2x base");

        // Add 1 more to go past threshold
        uint64 fee101 = harness.getCurrentForcedInclusionFee(100, 100);
        harness.save{ value: uint256(fee101) * 1 gwei }(100, 100, ref);

        // At 101 pending: fee = 100 * (1 + 101/100) = 100 * 2.01 = 201
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 201, "At 101 pending, fee should be 2.01x base");
    }

    function test_getCurrentForcedInclusionFee_FormulaAccuracy() external {
        uint64 baseFeeInGwei = 10_000_000; // 0.01 ETH
        uint64 feeDoubleThreshold = 100;

        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        // Test at various queue sizes to verify formula accuracy
        uint256[10] memory testSizes = [uint256(0), 1, 25, 50, 75, 99, 100, 150, 200, 300];
        uint256[10] memory expectedFees = [
            uint256(10_000_000), // 0: 1.00x
            10_100_000,          // 1: 1.01x
            12_500_000,          // 25: 1.25x
            15_000_000,          // 50: 1.50x
            17_500_000,          // 75: 1.75x
            19_900_000,          // 99: 1.99x
            20_000_000,          // 100: 2.00x (DOUBLED)
            25_000_000,          // 150: 2.50x
            30_000_000,          // 200: 3.00x (TRIPLED)
            40_000_000           // 300: 4.00x
        ];

        for (uint256 i = 0; i < testSizes.length; i++) {
            // Fill queue to target size
            while (harness.tail() - harness.head() < testSizes[i]) {
                uint64 currentFee = harness.getCurrentForcedInclusionFee(baseFeeInGwei, feeDoubleThreshold);
                harness.save{ value: uint256(currentFee) * 1 gwei }(baseFeeInGwei, feeDoubleThreshold, ref);
            }

            uint64 actualFee = harness.getCurrentForcedInclusionFee(baseFeeInGwei, feeDoubleThreshold);
            assertEq(
                actualFee,
                expectedFees[i],
                string.concat("Fee incorrect at ", vm.toString(testSizes[i]), " pending")
            );
        }
    }

    function test_getCurrentForcedInclusionFee_DifferentThresholds() external {
        // Test with threshold = 50
        

        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        // At 0 pending with threshold=50
        assertEq(harness.getCurrentForcedInclusionFee(100, 50), 100, "Empty queue should be 1x base");

        // Fill to 50 pending
        for (uint256 i = 0; i < 50; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 50);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 50, ref);
        }

        // At 50 pending: fee = 100 * (1 + 50/50) = 200 (should double at threshold)
        assertEq(harness.getCurrentForcedInclusionFee(100, 50), 200, "At threshold=50, fee should double");

        // Test with threshold = 200
        

        // Clear queue by setting new harness
        harness = new LibForcedInclusionHarness();

        // At 100 pending with threshold=200: fee = 100 * (1 + 100/200) = 150 (1.5x, not doubled)
        _setupBlobHashes(1);
        for (uint256 i = 0; i < 100; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 200);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 200, ref);
        }
        assertEq(harness.getCurrentForcedInclusionFee(100, 200), 150, "At 100 pending with threshold=200, fee should be 1.5x");
    }

    function test_getCurrentForcedInclusionFee_HighQueueSize() external {


        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        // Fill to 500 pending (5x threshold)
        for (uint256 i = 0; i < 500; i++) {
            uint64 currentFee = harness.getCurrentForcedInclusionFee(100, 100);
            harness.save{ value: uint256(currentFee) * 1 gwei }(100, 100, ref);
        }

        // At 500 pending: fee = 100 * (1 + 500/100) = 100 * 6 = 600 (6x base)
        assertEq(harness.getCurrentForcedInclusionFee(100, 100), 600, "At 500 pending, fee should be 6x base");
    }

    function test_getCurrentForcedInclusionFee_RevertWhen_ZeroThreshold() external {
        // Should revert when _feeDoubleThreshold is 0 (division by zero protection)
        vm.expectRevert(LibForcedInclusion.InvalidFeeDoubleThreshold.selector);
        harness.getCurrentForcedInclusionFee(100, 0);
    }

    function test_saveForcedInclusion_RevertWhen_ZeroThreshold() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        // Should revert when trying to save with zero threshold
        vm.expectRevert(LibForcedInclusion.InvalidFeeDoubleThreshold.selector);
        harness.save{ value: 100 gwei }(100, 0, ref);
    }

    // ---------------------------------------------------------------
    // isOldestForcedInclusionDue
    // ---------------------------------------------------------------

    function test_isOldestForcedInclusionDue_ReturnsTrueAfterDelay() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        

        harness.save{ value: 1 gwei }(1, 100, ref);

        uint48 inclusionTimestamp = harness.queue(0).blobSlice.timestamp;
        vm.warp(inclusionTimestamp + 15);

        assertTrue(harness.isDue(10), "Inclusion should be due once delay elapsed");
    }

    function test_isOldestForcedInclusionDue_ReturnsFalseWhenQueueEmpty() external view {
        assertFalse(harness.isDue(10));
    }

    function test_isOldestForcedInclusionDue_RespectsLastProcessedAt() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        

        harness.save{ value: 1 gwei }(1, 100, ref);

        uint48 timestamp = harness.queue(0).blobSlice.timestamp;
        harness.setLastProcessedAt(timestamp + 5);

        vm.warp(timestamp + 14);
        assertFalse(harness.isDue(10), "Should not be due before lastProcessedAt + delay");

        vm.warp(timestamp + 16);
        assertTrue(harness.isDue(10), "Should be due after processing delay");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _setupBlobHashes(uint256 _count) internal returns (bytes32[] memory hashes) {
        hashes = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        vm.blobhashes(hashes);
        return hashes;
    }

    function _makeRef(
        uint16 _start,
        uint16 _num,
        uint24 _offset
    )
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({ blobStartIndex: _start, numBlobs: _num, offset: _offset });
    }

    function _singleHashArray(bytes32 _value) internal pure returns (bytes32[] memory hashes) {
        hashes = new bytes32[](1);
        hashes[0] = _value;
    }
}
