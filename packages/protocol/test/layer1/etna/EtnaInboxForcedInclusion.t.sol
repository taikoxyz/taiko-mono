// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { LibEtnaForcedInclusion } from "src/layer1/etna/libs/LibEtnaForcedInclusion.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @notice Runs the Shasta library, linked by forge, on its own queue as the reference that the
/// Etna store must reproduce.
contract LibForcedInclusionReference {
    LibForcedInclusion.Storage private _queue;

    function save(
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold,
        LibBlobs.BlobReference memory _blobReference
    )
        external
        payable
        returns (uint256 refund_)
    {
        return LibForcedInclusion.saveForcedInclusion(
            _queue, _baseFeeInGwei, _feeDoubleThreshold, _blobReference
        );
    }

    function setState(uint48 _head, uint48 _tail) external {
        (_queue.head, _queue.tail) = (_head, _tail);
    }

    function currentFee(
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold
    )
        external
        view
        returns (uint64)
    {
        return LibForcedInclusion.getCurrentForcedInclusionFee(
            _queue, _baseFeeInGwei, _feeDoubleThreshold
        );
    }
}

/// @notice Exposes `LibEtnaForcedInclusion.consume` over a queue whose fees the test sets.
contract LibEtnaForcedInclusionHarness {
    LibForcedInclusion.Storage private _queue;

    function setEntryFee(uint256 _index, uint64 _feeInGwei) external {
        _queue.queue[_index].feeInGwei = _feeInGwei;
    }

    function setState(uint48 _head, uint48 _tail) external {
        (_queue.head, _queue.tail) = (_head, _tail);
    }

    function consume(uint48 _newHead) external returns (uint256) {
        return LibEtnaForcedInclusion.consume(_queue, _newHead);
    }

    function state() external view returns (uint48 head_, uint48 tail_) {
        return (_queue.head, _queue.tail);
    }
}

/// @notice Re-enters `saveForcedInclusion` from the refund of its own call, paying the exact fee
/// so that an unguarded re-entry would succeed without a further refund.
contract ReentrantForcedInclusionCaller {
    EtnaInbox private immutable _inbox;
    bool private _catchReentry;
    bytes public reentryError;

    constructor(EtnaInbox _target) {
        _inbox = _target;
    }

    function save(bool _catch, uint256 _value) external {
        _catchReentry = _catch;
        _inbox.saveForcedInclusion{ value: _value }(_blobReference());
    }

    receive() external payable {
        uint256 fee = uint256(_inbox.getCurrentForcedInclusionFee()) * 1 gwei;
        if (!_catchReentry) {
            _inbox.saveForcedInclusion{ value: fee }(_blobReference());
            return;
        }
        try _inbox.saveForcedInclusion{ value: fee }(_blobReference()) { }
        catch (bytes memory reason) {
            reentryError = reason;
        }
    }

    function _blobReference() private pure returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });
    }
}

contract EtnaInboxForcedInclusionTest is EtnaInboxTestBase {
    function setUp() public override {
        super.setUp();
        vm.deal(Alice, 1000 ether);
    }

    function test_saveForcedInclusion_enqueuesAtTailAndRefundsExcess() external {
        vm.blobhashes(_getBlobHashes(1));
        uint64 fee = etnaInbox.getCurrentForcedInclusionFee();
        assertEq(fee, FORCED_INCLUSION_FEE_GWEI, "base fee with an empty queue");
        IForcedInclusionStore.ForcedInclusion memory expected = IForcedInclusionStore.ForcedInclusion({
            feeInGwei: fee,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashes(1), offset: 7, timestamp: uint48(block.timestamp)
            })
        });
        uint256 balanceBefore = Alice.balance;

        vm.expectEmit(address(etnaInbox));
        emit IForcedInclusionStore.ForcedInclusionSaved(expected);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: uint256(fee) * 1 gwei + 1 }(_blobReference(7));

        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(head, 0, "head");
        assertEq(tail, 1, "tail");
        IForcedInclusionStore.ForcedInclusion[] memory entries =
            etnaInbox.getForcedInclusions(0, 10);
        assertEq(entries.length, 1, "one entry");
        assertEq(entries[0].feeInGwei, fee, "fee");
        assertEq(entries[0].blobSlice.blobHashes.length, 1, "one blob");
        assertEq(entries[0].blobSlice.blobHashes[0], blobhash(0), "blob hash");
        assertEq(entries[0].blobSlice.offset, 7, "offset");
        assertEq(entries[0].blobSlice.timestamp, block.timestamp, "timestamp");
        assertEq(balanceBefore - Alice.balance, uint256(fee) * 1 gwei, "1 wei refunded");
        assertEq(address(etnaInbox).balance, uint256(fee) * 1 gwei, "fee held by the Inbox");
    }

    function test_saveForcedInclusion_revertsBeforeActivation() external {
        _deployFreshInbox(false);
        vm.blobhashes(_getBlobHashes(1));
        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: 1 ether }(_blobReference(0));
    }

    function test_saveForcedInclusion_revertsOnInsufficientFee() external {
        vm.blobhashes(_getBlobHashes(1));
        uint256 fee = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei;
        vm.expectRevert(LibForcedInclusion.InsufficientFee.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: fee - 1 }(_blobReference(0));
    }

    function test_saveForcedInclusion_revertsOnTwoBlobs() external {
        vm.blobhashes(_getBlobHashes(2));
        uint256 fee = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei;
        vm.expectRevert(LibForcedInclusion.OnlySingleBlobAllowed.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: fee }(
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 2, offset: 0 })
        );
    }

    /// @dev Saves the same entries in the Etna store and the Shasta library: every fee and refund
    /// matches, and so does the saturated fee for the same queue length under a base fee of
    /// `type(uint64).max`.
    function test_currentFee_matchesLibForcedInclusion(uint8 _pending) external {
        vm.blobhashes(_getBlobHashes(1));
        LibForcedInclusionReference shasta = new LibForcedInclusionReference();
        vm.deal(address(this), 1000 ether);
        for (uint256 i; i < _pending; ++i) {
            uint64 fee = etnaInbox.getCurrentForcedInclusionFee();
            assertEq(
                fee,
                shasta.currentFee(FORCED_INCLUSION_FEE_GWEI, FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD),
                "fee before the entry"
            );
            uint256 value = uint256(fee) * 1 gwei + i;
            uint256 refund = shasta.save{ value: value }(
                FORCED_INCLUSION_FEE_GWEI, FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD, _blobReference(0)
            );
            uint256 balanceBefore = Alice.balance;
            vm.prank(Alice);
            etnaInbox.saveForcedInclusion{ value: value }(_blobReference(0));
            assertEq(balanceBefore - Alice.balance, value - refund, "refund");
        }
        (, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(tail, _pending, "tail");
        assertEq(
            etnaInbox.getCurrentForcedInclusionFee(),
            shasta.currentFee(FORCED_INCLUSION_FEE_GWEI, FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD),
            "fee after the entries"
        );

        IEtnaInbox.Config memory config = etnaConfig;
        config.forcedInclusionFeeInGwei = type(uint64).max;
        EtnaInbox saturated = new EtnaInbox(config);
        vm.store(
            address(saturated),
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(_pending) << 48)
        );
        assertEq(
            saturated.getCurrentForcedInclusionFee(),
            shasta.currentFee(type(uint64).max, FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD),
            "saturated fee"
        );
        assertEq(saturated.getCurrentForcedInclusionFee(), type(uint64).max, "uint64 cap");
    }

    /// @dev The fee formula over the whole parameter and queue space, set through slot 281.
    function test_currentFee_matchesLibForcedInclusionForAnyQueue(
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold,
        uint48 _head,
        uint48 _tail
    )
        external
    {
        _baseFeeInGwei = uint64(bound(_baseFeeInGwei, 1, type(uint64).max));
        _feeDoubleThreshold = uint64(bound(_feeDoubleThreshold, 1, type(uint64).max));
        if (_head > _tail) (_head, _tail) = (_tail, _head);

        IEtnaInbox.Config memory config = etnaConfig;
        config.forcedInclusionFeeInGwei = _baseFeeInGwei;
        config.forcedInclusionFeeDoubleThreshold = _feeDoubleThreshold;
        EtnaInbox inbox = new EtnaInbox(config);
        vm.store(
            address(inbox),
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(_head) | (uint256(_tail) << 48))
        );
        LibForcedInclusionReference shasta = new LibForcedInclusionReference();
        shasta.setState(_head, _tail);

        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, _head, "head");
        assertEq(tail, _tail, "tail");
        assertEq(
            inbox.getCurrentForcedInclusionFee(),
            shasta.currentFee(_baseFeeInGwei, _feeDoubleThreshold),
            "fee"
        );
    }

    function test_storage_queueAt280HeadTailAt281() external {
        vm.blobhashes(_getBlobHashes(1));
        _saveForcedInclusion(0);
        _advanceBlock();
        bytes32 secondBlobHash = keccak256("second forced inclusion blob");
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = secondBlobHash;
        vm.blobhashes(blobHashes);
        uint24 offset = 0x0abcde;
        uint64 secondFee = _saveForcedInclusion(offset);

        assertEq(_loadSlot(FORCED_INCLUSION_QUEUE_SLOT), 0, "280: mapping slot");
        assertEq(
            _loadSlot(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            (uint256(2) << 48) | 0,
            "281: head 0 (bits 0-47), tail 2 (bits 48-95)"
        );
        uint256 base = uint256(keccak256(abi.encode(uint256(1), FORCED_INCLUSION_QUEUE_SLOT)));
        assertEq(_loadSlot(base), secondFee, "base: feeInGwei");
        assertEq(_loadSlot(base + 1), 1, "base + 1: blobHashes length");
        assertEq(
            _loadSlot(base + 2),
            uint256(offset) | (uint256(block.timestamp) << 24),
            "base + 2: offset (bits 0-23), timestamp (bits 24-71)"
        );
        assertEq(
            bytes32(_loadSlot(uint256(keccak256(abi.encode(base + 1))))),
            secondBlobHash,
            "blobHashes[0]"
        );
    }

    function test_saveForcedInclusion_isNonReentrant() external {
        vm.blobhashes(_getBlobHashes(1));
        ReentrantForcedInclusionCaller caller = new ReentrantForcedInclusionCaller(etnaInbox);
        vm.deal(address(caller), 10 ether);
        uint256 value = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei + 1;

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        caller.save(false, value);
        (, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(tail, 0, "nothing saved");

        caller.save(true, value);
        assertEq(
            caller.reentryError(),
            abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector),
            "re-entry rejected"
        );
        (, tail) = etnaInbox.getForcedInclusionState();
        assertEq(tail, 1, "only the outer entry");
    }

    function test_consume_sumsFeesAndAdvancesHead() external {
        LibEtnaForcedInclusionHarness queue = new LibEtnaForcedInclusionHarness();
        queue.setEntryFee(0, 2);
        queue.setEntryFee(1, 3);
        queue.setEntryFee(2, 5);
        queue.setEntryFee(3, 7);
        queue.setState(1, 4);

        assertEq(queue.consume(3), 3 + 5, "fees of entries 1 and 2");
        (uint48 head, uint48 tail) = queue.state();
        assertEq(head, 3, "head advanced");
        assertEq(tail, 4, "tail unchanged");

        assertEq(queue.consume(3), 0, "no entries");
        assertEq(queue.consume(4), 7, "fee of entry 3");
        (head,) = queue.state();
        assertEq(head, 4, "head at tail");
    }

    function _saveForcedInclusion(uint24 _offset) private returns (uint64 fee_) {
        fee_ = etnaInbox.getCurrentForcedInclusionFee();
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: uint256(fee_) * 1 gwei }(_blobReference(_offset));
    }

    function _blobReference(uint24 _offset) private pure returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: _offset });
    }
}
