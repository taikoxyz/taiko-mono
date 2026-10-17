// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
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
    LibEtnaForcedInclusion.Storage private _queue;

    function entry(uint256 _index) external view returns (IEtnaInbox.ForcedInclusion memory) {
        return _queue.queue[_index];
    }

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
        _inbox.saveForcedInclusion{ value: _value }(hex"c0");
    }

    receive() external payable {
        uint256 fee = uint256(_inbox.getCurrentForcedInclusionFee()) * 1 gwei;
        if (!_catchReentry) {
            _inbox.saveForcedInclusion{ value: fee }(hex"c0");
            return;
        }
        try _inbox.saveForcedInclusion{ value: fee }(hex"c0") { }
        catch (bytes memory reason) {
            reentryError = reason;
        }
    }
}

contract EtnaInboxForcedInclusionTest is EtnaInboxTestBase {
    function setUp() public override {
        super.setUp();
        vm.deal(Alice, 1000 ether);
    }

    function test_saveForcedInclusion_enqueuesCalldataAndRefundsExcess() external {
        bytes memory txBytes = hex"c0";
        uint64 fee = etnaInbox.getCurrentForcedInclusionFee();
        uint256 beforeBalance = Alice.balance;
        vm.expectEmit();
        emit IEtnaInbox.ForcedInclusionSaved(0, txBytes);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: uint256(fee) * 1 gwei + 1 }(txBytes);
        IEtnaInbox.ForcedInclusion[] memory entries = etnaInbox.getForcedInclusions(0, 1);
        assertEq(entries.length, 1);
        assertEq(entries[0].txHash, keccak256(txBytes));
        assertEq(entries[0].timestamp, block.timestamp);
        assertEq(entries[0].l1Block, block.number);
        assertEq(entries[0].feeInGwei, fee);
        assertEq(beforeBalance - Alice.balance, uint256(fee) * 1 gwei);
        (uint48 head, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(head, 0);
        assertEq(tail, 1);
        assertEq(address(etnaInbox).balance, uint256(fee) * 1 gwei);
    }

    function test_saveForcedInclusion_accepts8192Bytes() external {
        bytes memory txBytes = new bytes(8192);
        vm.expectEmit();
        emit IEtnaInbox.ForcedInclusionSaved(0, txBytes);
        _saveForcedInclusion(txBytes);
        assertEq(etnaInbox.getForcedInclusions(0, 1)[0].txHash, keccak256(txBytes));
    }

    /// @dev Admission publishes even invalid input; L2 consumption determines its validity.
    function test_saveForcedInclusion_acceptsEmptyInput() external {
        vm.expectEmit();
        emit IEtnaInbox.ForcedInclusionSaved(0, hex"");
        _saveForcedInclusion(hex"");
        assertEq(etnaInbox.getForcedInclusions(0, 1)[0].txHash, keccak256(hex""));
    }

    function test_saveForcedInclusion_revertsOn8193Bytes() external {
        bytes memory txBytes = new bytes(8193);
        uint256 fee = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei;
        vm.expectRevert(EtnaInbox.ForcedTransactionTooLarge.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: fee }(txBytes);
        (, uint48 tail) = etnaInbox.getForcedInclusionState();
        assertEq(tail, 0);
        assertEq(address(etnaInbox).balance, 0);
    }

    function test_saveForcedInclusion_revertsBeforeActivation() external {
        _deployFreshInbox(false);
        vm.expectRevert(EtnaInbox.EtnaNotActive.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: 1 ether }(hex"c0");
    }

    function test_saveForcedInclusion_revertsOnInsufficientFee() external {
        uint256 fee = uint256(etnaInbox.getCurrentForcedInclusionFee()) * 1 gwei;
        vm.expectRevert(EtnaInbox.InsufficientFee.selector);
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: fee - 1 }(hex"c0");
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
            etnaInbox.saveForcedInclusion{ value: value }(hex"c0");
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
        _saveForcedInclusion(hex"c0");
        _advanceBlock();
        bytes memory txBytes = hex"abcdef";
        uint64 secondFee = _saveForcedInclusion(txBytes);
        assertEq(_loadSlot(FORCED_INCLUSION_QUEUE_SLOT), 0, "280: mapping slot");
        assertEq(_loadSlot(FORCED_INCLUSION_HEAD_TAIL_SLOT), uint256(2) << 48, "281: head and tail");
        uint256 base = uint256(keccak256(abi.encode(uint256(1), FORCED_INCLUSION_QUEUE_SLOT)));
        assertEq(bytes32(_loadSlot(base)), keccak256(txBytes), "base: transaction hash");
        assertEq(
            _loadSlot(base + 1),
            uint256(block.timestamp) | (uint256(block.number) << 48) | (uint256(secondFee) << 112),
            "base + 1: timestamp, L1 block and fee"
        );
        assertEq(_loadSlot(base + 2), 0, "entry occupies only two slots");
    }

    function test_getForcedInclusions_preservesBoundsAndConsumedEntries() external {
        _saveForcedInclusion(hex"c0");
        _saveForcedInclusion(hex"c1");
        assertEq(etnaInbox.getForcedInclusions(0, type(uint48).max).length, 2);
        assertEq(etnaInbox.getForcedInclusions(1, 5).length, 1);
        assertEq(etnaInbox.getForcedInclusions(0, 0).length, 0);
        assertEq(etnaInbox.getForcedInclusions(2, 1).length, 0);
        assertEq(etnaInbox.getForcedInclusions(type(uint48).max, 1).length, 0);
        vm.store(
            address(etnaInbox),
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(1) | (uint256(2) << 48))
        );
        assertEq(etnaInbox.getForcedInclusions(0, 1).length, 0);
        assertEq(etnaInbox.getForcedInclusions(1, 2)[0].txHash, keccak256(hex"c1"));
        uint256 base = uint256(keccak256(abi.encode(uint256(0), FORCED_INCLUSION_QUEUE_SLOT)));
        assertEq(bytes32(_loadSlot(base)), keccak256(hex"c0"), "consumed entry retained");
    }

    function test_saveForcedInclusion_isNonReentrant() external {
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
        assertEq(queue.entry(1).feeInGwei, 3, "consumed entry 1 retained");
        assertEq(queue.entry(2).feeInGwei, 5, "consumed entry 2 retained");
        (uint48 head, uint48 tail) = queue.state();
        assertEq(head, 3, "head advanced");
        assertEq(tail, 4, "tail unchanged");

        assertEq(queue.consume(3), 0, "no entries");
        assertEq(queue.consume(4), 7, "fee of entry 3");
        (head,) = queue.state();
        assertEq(head, 4, "head at tail");
    }

    function _saveForcedInclusion(bytes memory _tx) private returns (uint64 fee_) {
        fee_ = etnaInbox.getCurrentForcedInclusionFee();
        vm.prank(Alice);
        etnaInbox.saveForcedInclusion{ value: uint256(fee_) * 1 gwei }(_tx);
    }

    function _blobReference(uint24 _offset) private pure returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: _offset });
    }
}
