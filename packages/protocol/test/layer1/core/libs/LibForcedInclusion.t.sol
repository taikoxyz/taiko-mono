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

    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference)
        external
        payable
        override
    {
        uint64 feeInGwei = uint64(msg.value / 1 gwei);
        _store.saveForcedInclusion(feeInGwei, _blobReference);
    }

    function getForcedInclusions(uint48 _start, uint48 _maxCount)
        external
        view
        override
        returns (ForcedInclusion[] memory inclusions_)
    {
        return _store.getForcedInclusions(_start, _maxCount);
    }

    function getForcedInclusionState()
        external
        view
        override
        returns (uint48 head_, uint48 tail_, uint48 lastProcessedAt_)
    {
        return _store.getForcedInclusionState();
    }

    function save(uint64 _feeInGwei, LibBlobs.BlobReference memory _blobReference)
        external
        payable
    {
        _store.saveForcedInclusion(_feeInGwei, _blobReference);
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

    function setHead(uint48 _newHead) external {
        _store.head = _newHead;
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
    // getForcedInclusions / getForcedInclusionState
    // ---------------------------------------------------------------
    function test_getForcedInclusions_MaxCountZeroReturnsEmpty() external {
        _setupBlobHashes(1);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(0, 0);
        assertEq(inclusions.length, 0, "Zero max count should return empty array");
    }

    function test_getForcedInclusions_ReturnsRangeFromStart() external {
        bytes32[] memory hashes = _setupBlobHashes(3);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        harness.save{ value: 2 gwei }(2, _makeRef(1, 1, 0));
        harness.save{ value: 3 gwei }(3, _makeRef(2, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(0, 2);
        assertEq(inclusions.length, 2, "Should return requested count");

        for (uint256 i; i < inclusions.length; ++i) {
            assertEq(inclusions[i].feeInGwei, uint64(i + 1), "Fees should increment");
            assertEq(inclusions[i].blobSlice.blobHashes[0], hashes[i], "Hash should match index");
        }
    }

    function test_getForcedInclusions_SingleEntryWhenMaxCountOne() external {
        bytes32[] memory hashes = _setupBlobHashes(2);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        harness.save{ value: 2 gwei }(2, _makeRef(1, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(1, 1);
        assertEq(inclusions.length, 1, "Should return exactly one entry");
        assertEq(inclusions[0].feeInGwei, 2, "Returned inclusion should match requested index");
        assertEq(inclusions[0].blobSlice.blobHashes[0], hashes[1], "Hash should match queue entry");
    }

    function test_getForcedInclusions_ReturnsDefaultForUnavailableSlots() external {
        bytes32[] memory hashes = _setupBlobHashes(2);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        harness.save{ value: 2 gwei }(2, _makeRef(1, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(1, 5);
        assertEq(inclusions.length, 5, "Should return the requested number of entries");
        assertEq(inclusions[0].feeInGwei, 2, "First returned entry should match index 1");
        assertEq(inclusions[0].blobSlice.blobHashes[0], hashes[1], "Expected blob hash for stored entry");
        for (uint256 i = 1; i < inclusions.length; ++i) {
            assertEq(inclusions[i].feeInGwei, 0, "Out-of-range slots should return default fee");
            assertEq(inclusions[i].blobSlice.timestamp, 0, "Out-of-range slots should return default slice");
        }
    }

    function test_getForcedInclusions_DefaultsWhenStartEqualsTail() external {
        _setupBlobHashes(1);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(1, 2);
        assertEq(inclusions.length, 2, "Should return the requested number of default entries");
        assertEq(inclusions[0].feeInGwei, 0, "First default entry should have zero fee");
        assertEq(inclusions[1].blobSlice.timestamp, 0, "Second default entry should have zero timestamp");
    }

    function test_getForcedInclusions_ReturnsDataForIndexBeforeHead() external {
        _setupBlobHashes(1);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        harness.setHead(1);

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(0, 1);
        assertEq(inclusions.length, 1, "Should return requested number of entries");
        assertEq(inclusions[0].feeInGwei, 1, "Should still return stored entry for older index");
    }

    function test_getForcedInclusions_DefaultWhenStartAfterTail() external {
        _setupBlobHashes(1);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));

        IForcedInclusionStore.ForcedInclusion[] memory inclusions =
            harness.getForcedInclusions(2, 2);
        assertEq(inclusions.length, 2, "Should return requested number of entries");
        assertEq(inclusions[0].feeInGwei, 0, "Should fallback to default for non-existent entries");
        assertEq(inclusions[1].blobSlice.timestamp, 0, "Should fallback to default blob slice");
    }

    function test_getForcedInclusionState_ReturnsPointers() external {
        _setupBlobHashes(2);
        harness.save{ value: 1 gwei }(1, _makeRef(0, 1, 0));
        harness.save{ value: 2 gwei }(2, _makeRef(1, 1, 0));

        harness.setHead(1);
        harness.setLastProcessedAt(42);

        (uint48 head_, uint48 tail_, uint48 lastProcessed_) = harness.getForcedInclusionState();
        assertEq(head_, 1, "Head should reflect processed entries");
        assertEq(tail_, 2, "Tail should reflect total entries");
        assertEq(lastProcessed_, 42, "Last processed timestamp should match");
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
