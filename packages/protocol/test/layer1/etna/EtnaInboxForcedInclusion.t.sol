// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
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

/// @notice Re-enters `saveForcedInclusion` from the refund of its own call, paying the exact fee
/// so that an unguarded re-entry would succeed without a further refund. It also records the queue
/// tail and the Inbox balance seen from inside the refund.
contract ReentrantForcedInclusionCaller {
    EtnaInbox private immutable _inbox;
    bool private _catchReentry;
    bytes public reentryError;
    uint48 public tailSeenByRefund;
    uint256 public balanceSeenByRefund;

    constructor(EtnaInbox _target) {
        _inbox = _target;
    }

    function save(bool _catch, uint256 _value) external {
        _catchReentry = _catch;
        _inbox.saveForcedInclusion{ value: _value }(hex"c0");
    }

    receive() external payable {
        (, tailSeenByRefund) = _inbox.getForcedInclusionState();
        balanceSeenByRefund = address(_inbox).balance;
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

/// @notice A contract without `receive` or `fallback`: every ETH transfer to it fails. It serves
/// as a forced inclusion sender that cannot take a refund and as a treasury that rejects a sweep.
contract EtherRejectingAccount {
    function save(EtnaInbox _inbox, bytes calldata _tx) external payable {
        _inbox.saveForcedInclusion{ value: msg.value }(_tx);
    }
}

/// @notice A treasury that tries to re-enter the Inbox from the sweep's transfer and records why
/// each re-entry failed.
contract ReentrantTreasury {
    EtnaInbox public inbox;
    bytes public saveError;
    bytes public sweepError;

    function setInbox(EtnaInbox _inbox) external {
        inbox = _inbox;
    }

    receive() external payable {
        uint256 fee = uint256(inbox.getCurrentForcedInclusionFee()) * 1 gwei;
        try inbox.saveForcedInclusion{ value: fee }(hex"c0") { }
        catch (bytes memory reason) {
            saveError = reason;
        }
        try inbox.sweepProtocolFees() { }
        catch (bytes memory reason) {
            sweepError = reason;
        }
    }
}

contract EtnaInboxForcedInclusionTest is EtnaInboxTestBase {
    /// @dev 2^48, the first value a 48-bit field cannot hold.
    uint256 private constant _TWO_POW_48 = 2 ** 48;

    function setUp() public override {
        super.setUp();
        vm.deal(Alice, 1000 ether);
    }

    // ---------------------------------------------------------------
    // saveForcedInclusion
    // ---------------------------------------------------------------

    /// @dev Appendix B: an entry is two words, `keccak256(tx)` then `timestamp | l1Block << 48`
    /// with every bit from 96 zero. No fee is stored.
    function test_saveForcedInclusion_storesHashTimestampAndBlockOnly() external {
        _saveForcedInclusion(hex"c0");
        vm.roll(0x12345678);
        vm.warp(0xabcdef012345);
        bytes memory txBytes = hex"abcdef";
        _saveForcedInclusion(txBytes);

        assertEq(_load(FORCED_INCLUSION_QUEUE_SLOT), 0, "280: mapping slot");
        assertEq(_load(FORCED_INCLUSION_HEAD_TAIL_SLOT), uint256(2) << 48, "281: head 0, tail 2");
        uint256 base = _entrySlot(1);
        assertEq(bytes32(_load(base)), keccak256(txBytes), "word 0: transaction hash");
        uint256 word1 = _load(base + 1);
        assertEq(
            word1,
            uint256(0xabcdef012345) | (uint256(0x12345678) << 48),
            "word 1: timestamp and L1 block"
        );
        assertEq(word1 >> 96, 0, "word 1: bits from 96 are zero");
        assertEq(_load(base + 2), 0, "an entry has two words");

        IEtnaInbox.ForcedInclusion memory entry = _inbox().getForcedInclusion(1);
        assertEq(entry.txHash, keccak256(txBytes), "getter: hash");
        assertEq(entry.timestamp, 0xabcdef012345, "getter: timestamp");
        assertEq(entry.l1Block, 0x12345678, "getter: L1 block");
        entry = _inbox().getForcedInclusion(2);
        assertEq(entry.txHash, 0, "beyond the tail: hash");
        assertEq(entry.timestamp, 0, "beyond the tail: timestamp");
        assertEq(entry.l1Block, 0, "beyond the tail: L1 block");
    }

    /// @dev `feeWei` is the fee actually charged, never the amount sent.
    function test_saveForcedInclusion_emitsIndexBytesAndChargedFee() external {
        uint256 fee0 = _currentFeeWei();
        assertEq(fee0, uint256(FORCED_INCLUSION_FEE_GWEI) * 1 gwei, "empty queue: base fee");
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ForcedInclusionSaved(0, hex"c0", fee0);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee0 + 1 ether }(hex"c0");

        uint256 fee1 = _currentFeeWei();
        assertEq(
            fee1,
            fee0 * (FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD + 1)
                / FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "one pending entry"
        );
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ForcedInclusionSaved(1, hex"c1", fee1);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee1 + 7 }(hex"c1");
    }

    function test_saveForcedInclusion_enqueuesCalldataAndRefundsExcess() external {
        bytes memory txBytes = hex"c0";
        uint256 fee = _currentFeeWei();
        uint256 beforeBalance = Alice.balance;
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee + 1 }(txBytes);

        IEtnaInbox.ForcedInclusion[] memory entries = _inbox().getForcedInclusions(0, 1);
        assertEq(entries.length, 1, "one pending entry");
        assertEq(entries[0].txHash, keccak256(txBytes), "hash");
        assertEq(entries[0].timestamp, block.timestamp, "timestamp");
        assertEq(entries[0].l1Block, block.number, "L1 block");
        assertEq(beforeBalance - Alice.balance, fee, "only the fee is charged");
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(head, 0, "head");
        assertEq(tail, 1, "tail");
        assertEq(inboxProxy.balance, fee, "the fee stays in the Inbox");
    }

    /// @dev Saves the same entries in the Etna store and the Shasta library: every fee and refund
    /// matches, and so does the saturated fee for the same queue length under a base fee of
    /// `type(uint64).max`.
    function test_currentFee_matchesLibForcedInclusion(uint8 _pending) external {
        vm.blobhashes(_blobHashes(1));
        LibForcedInclusionReference shasta = new LibForcedInclusionReference();
        vm.deal(address(this), 1000 ether);
        for (uint256 i; i < _pending; ++i) {
            uint64 fee = _inbox().getCurrentForcedInclusionFee();
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
            _inbox().saveForcedInclusion{ value: value }(hex"c0");
            assertEq(balanceBefore - Alice.balance, value - refund, "refund");
        }
        (, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(tail, _pending, "tail");
        assertEq(
            _inbox().getCurrentForcedInclusionFee(),
            shasta.currentFee(FORCED_INCLUSION_FEE_GWEI, FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD),
            "fee after the entries"
        );

        IEtnaInbox.Config memory config = _defaultConfig();
        config.forcedInclusionFeeInGwei = type(uint64).max;
        EtnaInbox saturated = _newInboxImpl(config);
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

        IEtnaInbox.Config memory config = _defaultConfig();
        config.forcedInclusionFeeInGwei = _baseFeeInGwei;
        config.forcedInclusionFeeDoubleThreshold = _feeDoubleThreshold;
        EtnaInbox inbox = _newInboxImpl(config);
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

    /// @dev Lean `fi_backlog_example_cost`: with no landing, 900 saves at a base fee of 10^7 Gwei
    /// and threshold 50 charge sum_{k < 900} 10^7 * (50 + k) / 50 Gwei = 8991 * 10^16 wei. Each
    /// save overpays by 1 wei, which is refunded and so never counts as charged.
    function test_saveForcedInclusion_backlogExampleCostsExactly() external {
        uint256 aliceBefore = Alice.balance;
        for (uint256 k; k < 900; ++k) {
            uint256 fee = _currentFeeWei();
            vm.prank(Alice);
            _inbox().saveForcedInclusion{ value: fee + 1 }(hex"c0");
        }
        assertEq(aliceBefore - Alice.balance, 8991 * 10 ** 16, "total charged");
        assertEq(inboxProxy.balance, 8991 * 10 ** 16, "all of it stays in the Inbox");
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(head, 0, "head");
        assertEq(tail, 900, "tail");
        assertEq(_inbox().getCurrentForcedInclusionFee(), 190_000_000, "next fee: 10^7 * 950 / 50");
    }

    function test_saveForcedInclusion_accepts8192Bytes() external {
        bytes memory txBytes = new bytes(8192);
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ForcedInclusionSaved(0, txBytes, _currentFeeWei());
        _saveForcedInclusion(txBytes);
        assertEq(_inbox().getForcedInclusions(0, 1)[0].txHash, keccak256(txBytes));
    }

    /// @dev Admission publishes even invalid input; L2 consumption determines its validity.
    function test_saveForcedInclusion_acceptsEmptyInput() external {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ForcedInclusionSaved(0, hex"", _currentFeeWei());
        _saveForcedInclusion(hex"");
        assertEq(_inbox().getForcedInclusions(0, 1)[0].txHash, keccak256(hex""));
    }

    function test_saveForcedInclusion_revertsOn8193Bytes() external {
        bytes memory txBytes = new bytes(8193);
        uint256 fee = _currentFeeWei();
        vm.expectRevert(IEtnaInbox.ForcedTransactionTooLarge.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee }(txBytes);
        _assertQueueAndBalanceUntouched();
    }

    function test_saveForcedInclusion_revertsOnInsufficientFee() external {
        uint256 fee = _currentFeeWei();
        vm.expectRevert(IEtnaInbox.InsufficientFee.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee - 1 }(hex"c0");
        _assertQueueAndBalanceUntouched();

        // With one entry pending, the empty-queue fee no longer covers the next one.
        _saveForcedInclusion(hex"c0");
        vm.expectRevert(IEtnaInbox.InsufficientFee.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee }(hex"c1");
    }

    /// @dev `init` relies on every other Inbox slot being zero, so a save while the proxy runs
    /// `EtnaInbox` but `init` has not run must neither enqueue nor charge.
    function test_saveForcedInclusion_revertsBeforeInitialization() external {
        _deployFreshInbox(false);
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        uint256 fee = _currentFeeWei();

        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee }(hex"c0");
        _assertQueueAndBalanceUntouched();

        // `init` then starts from the empty queue.
        _inbox().init(_defaultInitParams());
        _saveForcedInclusion(hex"c0");
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(head, 0, "head after init");
        assertEq(tail, 1, "tail after init");
    }

    /// @dev Lean `fi_admission_refund_failure_atomic`: a refund that cannot be delivered reverts
    /// the whole save, so nothing is enqueued or charged.
    function test_saveForcedInclusion_revertsWhenRefundFails() external {
        EtherRejectingAccount sender = new EtherRejectingAccount();
        uint256 fee = _currentFeeWei();

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        sender.save{ value: fee + 1 }(_inbox(), hex"c0");
        _assertQueueAndBalanceUntouched();

        // An exact payment needs no refund, so the same sender can enqueue.
        sender.save{ value: fee }(_inbox(), hex"c0");
        (, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(tail, 1, "exact payment enqueues");
        assertEq(inboxProxy.balance, fee, "exact payment charged");
    }

    function test_saveForcedInclusion_revertsWhenTimestampOverflows48Bits() external {
        uint256 fee = _currentFeeWei();
        vm.warp(_TWO_POW_48);
        vm.expectRevert(IEtnaInbox.ValueOverflow.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee }(hex"c0");
        _assertQueueAndBalanceUntouched();

        vm.warp(_TWO_POW_48 - 1);
        _saveForcedInclusion(hex"c0");
        assertEq(_inbox().getForcedInclusion(0).timestamp, _TWO_POW_48 - 1, "largest timestamp");
    }

    function test_saveForcedInclusion_revertsWhenL1BlockOverflows48Bits() external {
        uint256 fee = _currentFeeWei();
        vm.roll(_TWO_POW_48);
        vm.expectRevert(IEtnaInbox.ValueOverflow.selector);
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: fee }(hex"c0");
        _assertQueueAndBalanceUntouched();

        vm.roll(_TWO_POW_48 - 1);
        _saveForcedInclusion(hex"c0");
        assertEq(_inbox().getForcedInclusion(0).l1Block, _TWO_POW_48 - 1, "largest L1 block");
    }

    /// @dev The refund is the last step: from inside it the entry is already enqueued and only the
    /// fee is left in the Inbox, and re-entering the Inbox is rejected.
    function test_saveForcedInclusion_isNonReentrant() external {
        ReentrantForcedInclusionCaller caller = new ReentrantForcedInclusionCaller(_inbox());
        vm.deal(address(caller), 10 ether);
        uint256 fee = _currentFeeWei();
        uint256 value = fee + 1;

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        caller.save(false, value);
        (, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(tail, 0, "nothing saved");

        caller.save(true, value);
        assertEq(
            caller.reentryError(),
            abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector),
            "re-entry rejected"
        );
        (, tail) = _inbox().getForcedInclusionState();
        assertEq(tail, 1, "only the outer entry");
        assertEq(caller.tailSeenByRefund(), 1, "enqueued before the refund");
        assertEq(caller.balanceSeenByRefund(), fee, "only the fee left during the refund");
    }

    // ---------------------------------------------------------------
    // sweepProtocolFees
    // ---------------------------------------------------------------

    /// @dev Lean `sweep_whole_balance`: the sweep sends the whole balance, including ETH forced
    /// into the Inbox without a call.
    function test_sweepProtocolFees_sendsWholeBalanceIncludingForcedEther() external {
        uint256 fees = _saveForcedInclusion(hex"c0");
        fees += _saveForcedInclusion(hex"c1");
        assertEq(inboxProxy.balance, fees, "fees kept");
        vm.deal(inboxProxy, fees + 5);
        uint256 recipientBefore = PROTOCOL_FEE_RECIPIENT.balance;

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ProtocolFeesSwept(fees + 5);
        _inbox().sweepProtocolFees();

        assertEq(PROTOCOL_FEE_RECIPIENT.balance - recipientBefore, fees + 5, "recipient");
        assertEq(inboxProxy.balance, 0, "Inbox emptied");
    }

    function test_sweepProtocolFees_isPermissionlessAndLeavesQueueUntouched() external {
        uint256 fees = _saveForcedInclusion(hex"c0");
        fees += _saveForcedInclusion(hex"c1");
        // A non-zero head, as after a landing.
        vm.store(
            inboxProxy,
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(1) | (uint256(2) << 48))
        );
        uint256[5] memory queueBefore = _queueWords();
        uint64 feeBefore = _inbox().getCurrentForcedInclusionFee();
        uint256 recipientBefore = PROTOCOL_FEE_RECIPIENT.balance;

        vm.prank(Bob);
        _inbox().sweepProtocolFees();
        assertEq(PROTOCOL_FEE_RECIPIENT.balance - recipientBefore, fees, "recipient");
        uint256[5] memory queueAfter = _queueWords();
        for (uint256 i; i < queueBefore.length; ++i) {
            assertEq(queueAfter[i], queueBefore[i], "queue word");
        }
        assertEq(_inbox().getCurrentForcedInclusionFee(), feeBefore, "next fee");

        // An empty balance sweeps nothing and still succeeds.
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.ProtocolFeesSwept(0);
        vm.prank(Carol);
        _inbox().sweepProtocolFees();
        assertEq(PROTOCOL_FEE_RECIPIENT.balance - recipientBefore, fees, "nothing more sent");
    }

    function test_sweepProtocolFees_revertsWhenRecipientRejects() external {
        IEtnaInbox.Config memory config = _defaultConfig();
        config.protocolFeeRecipient = address(new EtherRejectingAccount());
        _deployFreshInbox(config, _defaultInitParams(), true);
        uint256 fees = _saveForcedInclusion(hex"c0");

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        _inbox().sweepProtocolFees();
        assertEq(inboxProxy.balance, fees, "fees kept");

        // A rejecting treasury affects only the sweep.
        _saveForcedInclusion(hex"c1");
        (, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(tail, 2, "submissions continue");
    }

    function test_sweepProtocolFees_isNonReentrant() external {
        ReentrantTreasury recipient = new ReentrantTreasury();
        IEtnaInbox.Config memory config = _defaultConfig();
        config.protocolFeeRecipient = address(recipient);
        _deployFreshInbox(config, _defaultInitParams(), true);
        recipient.setInbox(_inbox());
        vm.deal(address(recipient), 1 ether);
        uint256 fees = _saveForcedInclusion(hex"c0");

        _inbox().sweepProtocolFees();
        bytes memory reentrant = abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector);
        assertEq(recipient.saveError(), reentrant, "save re-entry rejected");
        assertEq(recipient.sweepError(), reentrant, "sweep re-entry rejected");
        assertEq(address(recipient).balance, 1 ether + fees, "recipient got the fees");
        (, uint48 tail) = _inbox().getForcedInclusionState();
        assertEq(tail, 1, "no entry added from the sweep");
    }

    // ---------------------------------------------------------------
    // ETH rejection
    // ---------------------------------------------------------------

    /// @dev Only `saveForcedInclusion` accepts ETH (spec 7.1). `land`, `recover` and
    /// `sweepProtocolFees` are nonpayable, so the dispatcher rejects value with empty revert data
    /// before any modifier or body runs; the implementation has no `receive` or `fallback`.
    /// `upgradeToAndCall` must stay payable as an override, so it checks `msg.value` itself.
    function test_inbox_rejectsEtherOutsideForcedInclusion() external {
        IEtnaInbox.LandInput memory input;
        _assertRejectsEther(abi.encodeCall(IEtnaInbox.land, (input, new bytes32[](0), "")), "land");
        _assertRejectsEther(
            abi.encodeCall(
                IEtnaInbox.recover, (0, 0, new IEtnaInbox.Exclusion[](0), new uint256[](0))
            ),
            "recover"
        );
        _assertRejectsEther(abi.encodeCall(IEtnaInbox.sweepProtocolFees, ()), "sweep");
        _assertRejectsEther("", "plain transfer");
        _assertRejectsEther(hex"deadbeef", "unknown selector");

        EtnaInbox newImpl = _newInboxImpl(_defaultConfig());
        bytes memory call = abi.encodeCall(IEtnaInbox.isInitialized, ());
        vm.expectRevert(IEtnaInbox.EtherNotAccepted.selector);
        EssentialContract(inboxProxy).upgradeToAndCall{ value: 1 }(address(newImpl), call);
        assertEq(EssentialContract(inboxProxy).impl(), address(inboxImpl), "implementation kept");
        assertEq(inboxProxy.balance, 0, "no ETH kept");

        // Without ETH the owner's upgrade still goes through.
        EssentialContract(inboxProxy).upgradeToAndCall(address(newImpl), call);
        assertEq(EssentialContract(inboxProxy).impl(), address(newImpl), "upgraded");
    }

    // ---------------------------------------------------------------
    // getForcedInclusions
    // ---------------------------------------------------------------

    function test_getForcedInclusions_preservesBoundsAndConsumedEntries() external {
        _saveForcedInclusion(hex"c0");
        _saveForcedInclusion(hex"c1");
        assertEq(_inbox().getForcedInclusions(0, type(uint48).max).length, 2);
        assertEq(_inbox().getForcedInclusions(1, 5).length, 1);
        assertEq(_inbox().getForcedInclusions(0, 0).length, 0);
        assertEq(_inbox().getForcedInclusions(2, 1).length, 0);
        assertEq(_inbox().getForcedInclusions(type(uint48).max, 1).length, 0);
        vm.store(
            inboxProxy,
            bytes32(FORCED_INCLUSION_HEAD_TAIL_SLOT),
            bytes32(uint256(1) | (uint256(2) << 48))
        );
        assertEq(_inbox().getForcedInclusions(0, 1).length, 0);
        assertEq(_inbox().getForcedInclusions(1, 2)[0].txHash, keccak256(hex"c1"));
        assertEq(bytes32(_load(_entrySlot(0))), keccak256(hex"c0"), "consumed entry retained");
        assertEq(_inbox().getForcedInclusion(0).txHash, keccak256(hex"c0"), "consumed entry read");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _inbox() private view returns (EtnaInbox) {
        return EtnaInbox(inboxProxy);
    }

    function _currentFeeWei() private view returns (uint256) {
        return uint256(_inbox().getCurrentForcedInclusionFee()) * 1 gwei;
    }

    /// @dev Alice saves `_tx`, paying exactly the current fee.
    function _saveForcedInclusion(bytes memory _tx) private returns (uint256 feeWei_) {
        feeWei_ = _currentFeeWei();
        vm.prank(Alice);
        _inbox().saveForcedInclusion{ value: feeWei_ }(_tx);
    }

    /// @dev Expects a call with 1 wei and `_data` to revert with empty data, the nonpayable check.
    function _assertRejectsEther(bytes memory _data, string memory _entryPoint) private {
        (bool ok, bytes memory reason) = inboxProxy.call{ value: 1 }(_data);
        assertFalse(ok, _entryPoint);
        assertEq(reason.length, 0, string.concat(_entryPoint, ": nonpayable"));
        assertEq(inboxProxy.balance, 0, string.concat(_entryPoint, ": no ETH kept"));
    }

    /// @dev The queue is still empty: slot 281, both words of entry 0 and the Inbox balance are
    /// zero.
    function _assertQueueAndBalanceUntouched() private view {
        assertEq(_load(FORCED_INCLUSION_HEAD_TAIL_SLOT), 0, "281: head and tail");
        assertEq(_load(_entrySlot(0)), 0, "entry 0: word 0");
        assertEq(_load(_entrySlot(0) + 1), 0, "entry 0: word 1");
        assertEq(inboxProxy.balance, 0, "no ETH kept");
    }

    /// @dev Slot 281 and both words of entries 0 and 1.
    function _queueWords() private view returns (uint256[5] memory words_) {
        words_[0] = _load(FORCED_INCLUSION_HEAD_TAIL_SLOT);
        words_[1] = _load(_entrySlot(0));
        words_[2] = _load(_entrySlot(0) + 1);
        words_[3] = _load(_entrySlot(1));
        words_[4] = _load(_entrySlot(1) + 1);
    }

    function _entrySlot(uint256 _index) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(_index, FORCED_INCLUSION_QUEUE_SLOT)));
    }

    function _load(uint256 _slot) private view returns (uint256) {
        return uint256(vm.load(inboxProxy, bytes32(_slot)));
    }

    function _blobHashes(uint256 _count) private pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes_[i] = keccak256(abi.encode("blob", i));
        }
    }

    function _blobReference(uint24 _offset) private pure returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: _offset });
    }
}
