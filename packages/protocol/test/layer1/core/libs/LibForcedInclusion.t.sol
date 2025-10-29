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
    uint16 private _forcedInclusionDelay;

    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference)
        external
        payable
        override
    {
        uint64 feeInGwei = uint64(msg.value / 1 gwei);
        _store.saveForcedInclusion(feeInGwei, _blobReference);
    }

    function getDueForcedInclusions()
        external
        view
        override
        returns (ForcedInclusion[] memory dueInclusions_)
    {
        return _store.getDueForcedInclusions(_forcedInclusionDelay);
    }

    function save(
        uint64 _feeInGwei,
        LibBlobs.BlobReference memory _blobReference
    )
        external
        payable
    {
        _store.saveForcedInclusion(_feeInGwei, _blobReference);
    }

    function setForcedInclusionDelay(uint16 _delay) external {
        _forcedInclusionDelay = _delay;
    }

    function getDue(uint16 _delay)
        external
        view
        returns (ForcedInclusion[] memory dueInclusions_)
    {
        return _store.getDueForcedInclusions(_delay);
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
        uint64 feeInGwei = 25;
        uint256 expectedFee = uint256(feeInGwei) * 1 gwei;

        uint48 beforeCallTimestamp = uint48(block.timestamp);
        vm.expectEmit();
        emit IForcedInclusionStore
            .ForcedInclusionSaved(IForcedInclusionStore.ForcedInclusion({
                feeInGwei: feeInGwei,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: _singleHashArray(hashes[0]),
                    offset: ref.offset,
                    timestamp: beforeCallTimestamp }) }));

        harness.save{ value: expectedFee }(feeInGwei, ref);

        assertEq(harness.head(), 0, "Head should remain zero");
        assertEq(harness.tail(), 1, "Tail should advance by one entry");

        IForcedInclusionStore.ForcedInclusion memory stored = harness.queue(0);
        assertEq(stored.feeInGwei, feeInGwei);
        assertEq(stored.blobSlice.blobHashes.length, 1);
        assertEq(stored.blobSlice.offset, ref.offset);
        assertEq(stored.blobSlice.timestamp, uint48(block.timestamp));
    }

    function test_saveForcedInclusion_RevertWhen_FeeMismatch() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        vm.expectRevert(LibForcedInclusion.IncorrectFee.selector);
        harness.save{ value: 0 }(10, ref);
    }

    // ---------------------------------------------------------------
    // getDueForcedInclusions
    // ---------------------------------------------------------------

    function test_getDueForcedInclusions_ReturnsDueAfterDelay() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);

        harness.save{ value: 1 gwei }(1, ref);

        uint48 inclusionTimestamp = harness.queue(0).blobSlice.timestamp;
        vm.warp(inclusionTimestamp + 15);

        IForcedInclusionStore.ForcedInclusion[] memory due = harness.getDue(10);
        assertEq(due.length, 1, "Inclusion should be due once delay elapsed");
        assertEq(due[0].feeInGwei, 1, "Should return stored inclusion data");
    }

    function test_getDueForcedInclusions_ReturnsEmptyWhenQueueEmpty() external view {
        assertEq(harness.getDue(10).length, 0);
    }

    function test_getDueForcedInclusions_RespectsLastProcessedAt() external {
        _setupBlobHashes(1);
        LibBlobs.BlobReference memory ref = _makeRef(0, 1, 0);
        harness.save{ value: 1 gwei }(1, ref);

        uint48 timestamp = harness.queue(0).blobSlice.timestamp;
        harness.setLastProcessedAt(timestamp + 5);

        vm.warp(timestamp + 14);
        assertEq(harness.getDue(10).length, 0, "Should not be due before lastProcessedAt + delay");

        vm.warp(timestamp + 16);
        assertEq(harness.getDue(10).length, 1, "Should be due after processing delay");
    }

    function test_getDueForcedInclusions_ReturnsAllDueInOrder() external {
        bytes32[] memory hashes = _setupBlobHashes(3);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));

        vm.warp(block.timestamp + 1);
        harness.save{ value: 1 gwei }(1, _makeRef(1, 1, 0));

        vm.warp(block.timestamp + 1);
        harness.save{ value: 1 gwei }(1, _makeRef(2, 1, 0));

        uint48 firstTimestamp = harness.queue(0).blobSlice.timestamp;
        vm.warp(firstTimestamp + 20);

        IForcedInclusionStore.ForcedInclusion[] memory due = harness.getDue(10);
        assertEq(due.length, 3, "All inclusions should be due");
        for (uint256 i; i < due.length; ++i) {
            assertEq(due[i].feeInGwei, 1, "Fee should be preserved");
            assertEq(due[i].blobSlice.blobHashes.length, 1, "Blob slice should be intact");
            assertEq(due[i].blobSlice.blobHashes[0], hashes[i], "Blob hash order should be preserved");
        }
    }

    function test_getDueForcedInclusions_StopsAtFirstNotDue() external {
        _setupBlobHashes(2);

        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        uint48 firstTimestamp = harness.queue(0).blobSlice.timestamp;

        vm.warp(firstTimestamp + 11);
        harness.save{ value: 1 gwei }(1, _makeRef(1, 1, 0));
        uint48 secondTimestamp = harness.queue(1).blobSlice.timestamp;

        vm.warp(firstTimestamp + 15);

        IForcedInclusionStore.ForcedInclusion[] memory due = harness.getDue(10);
        assertEq(due.length, 1, "Only first inclusion should be due");
        assertEq(due[0].blobSlice.timestamp, firstTimestamp, "First timestamp should match");

        vm.warp(secondTimestamp + 15);
        due = harness.getDue(10);
        assertEq(due.length, 2, "Both inclusions should eventually be due");
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
