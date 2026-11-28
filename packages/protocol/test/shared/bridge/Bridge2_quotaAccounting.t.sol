// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/CountingQuotaManager.sol";
import "./TestBridge2Base.sol";
import {
    MessageReceiver_CreatingFreshStorageSlots
} from "test/shared/bridge/helpers/MessageReceiver_CreatingFreshStorageSlots.sol";

contract QuotaTarget is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool _fail) external {
        toFail = _fail;
    }
}

/// @dev A recallable sender that simply takes its Ether back, the way the vaults receive a
/// recalled message.
contract QuotaRecallableSender is IRecallableSender, IERC165 {
    uint256 public recalledValue;

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IRecallableSender).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }

    function onMessageRecalled(IBridge.Message calldata, bytes32) external payable {
        recalledValue += msg.value;
    }
}

/// @dev Verifies that the Bridge debits the Ether quota exactly for the Ether that actually leaves
/// the bridge ("debit only on actual release") across the process/retry lifecycle, and that a
/// recall, which only returns the Ether its message locked in sendMessage, debits nothing.
contract TestBridge2_quotaAccounting is TestBridge2Base {
    CountingQuotaManager internal qm;

    function getQuotaManager() internal override returns (address) {
        qm = new CountingQuotaManager();
        return address(qm);
    }

    function _ethConsumed() internal view returns (uint256) {
        return qm.consumed(address(0));
    }

    // A successful processMessage releases both value and fee, so both are debited.
    function test_quota_processMessage_success_debits_value_and_fee()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David; // EOA -> invocation prohibited -> DONE

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(_ethConsumed(), message.value + message.fee);
        assertEq(qm.totalConsumed(), message.value + message.fee);
    }

    // A failed processMessage keeps value in the bridge (RETRIABLE); only the released fee is
    // debited.
    function test_quota_processMessage_failure_debits_fee_only()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        QuotaTarget target = new QuotaTarget();
        target.setToFail(true);

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(QuotaTarget.onMessageInvocation, ("hello"));

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertEq(_ethConsumed(), message.fee);
    }

    // A message that fails and is then retried successfully debits its value exactly once.
    function test_quota_failed_then_retry_success_debits_value_once()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        QuotaTarget target = new QuotaTarget();
        target.setToFail(true);

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(QuotaTarget.onMessageInvocation, ("hello"));

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertEq(_ethConsumed(), 0); // value not released yet, fee is zero

        target.setToFail(false);

        vm.prank(Alice);
        eBridge.retryMessage(message, false);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(_ethConsumed(), message.value); // value debited exactly once
    }

    // A retry that exhausts the last attempt without releasing funds debits no value.
    function test_quota_retry_lastAttempt_failure_debits_nothing()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        QuotaTarget target = new QuotaTarget();
        target.setToFail(true);

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(QuotaTarget.onMessageInvocation, ("hello"));

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        // Last attempt still fails -> FAILED, value stays in the bridge.
        vm.prank(Alice);
        eBridge.retryMessage(message, true);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.FAILED);
        assertEq(_ethConsumed(), 0);
    }

    // A recall only returns the Ether the message itself locked in sendMessage, so it is exempt
    // from the quota: nothing is debited and the quota manager is not even called.
    function test_quota_recall_debits_nothing() public transactBy(Carol) {
        (, IBridge.Message memory m) =
            eBridge.sendMessage{ value: 1 ether }(_l1ToL2Message(Alice, 1 ether));
        assertEq(qm.calls(), 0); // sending does not consume withdrawal quota

        uint256 aliceBalance = Alice.balance;
        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(Alice.balance, aliceBalance + 1 ether);
        assertEq(_ethConsumed(), 0);
        assertEq(qm.calls(), 0);
    }

    // The IRecallableSender path (how the vaults get their recalled Ether back) is exempt too.
    function test_quota_recall_to_recallable_sender_debits_nothing() public {
        QuotaRecallableSender sender = new QuotaRecallableSender();
        vm.deal(address(sender), 100 ether);

        vm.prank(address(sender));
        (, IBridge.Message memory m) =
            eBridge.sendMessage{ value: 1 ether }(_l1ToL2Message(Alice, 1 ether));
        assertEq(address(sender).balance, 99 ether);

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(sender.recalledValue(), 1 ether);
        assertEq(address(sender).balance, 100 ether);
        assertEq(_ethConsumed(), 0);
        assertEq(qm.calls(), 0);
    }

    // A recall returns the value only; the fee stays in the bridge. Neither part touches the quota.
    function test_quota_recall_with_fee_refunds_value_only_and_debits_nothing()
        public
        transactBy(Carol)
    {
        IBridge.Message memory message = _l1ToL2Message(Carol, 1 ether);
        message.gasLimit = 1_000_000; // a fee requires a gas limit
        message.fee = 0.1 ether;

        uint256 carolBalance = Carol.balance;
        uint256 bridgeBalance = address(eBridge).balance;
        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1.1 ether }(message);
        assertEq(Carol.balance, carolBalance - 1.1 ether);

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(Carol.balance, carolBalance - 0.1 ether);
        assertEq(address(eBridge).balance, bridgeBalance + 0.1 ether);
        assertEq(_ethConsumed(), 0);
        assertEq(qm.calls(), 0);
    }

    // Releasing zero Ether (here: a zero-value, zero-fee delivery) skips the quota manager call
    // entirely.
    function test_quota_zero_value_skips_external_call() public dealEther(Carol) {
        IBridge.Message memory message = _l2ToL1Message(Alice, 0);

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        assertTrue(eBridge.messageStatus(eBridge.hashMessage(message)) == IBridge.Status.DONE);
        assertEq(qm.calls(), 0);
    }

    // The capped Ether send to a storage-creating destOwner, with a real QuotaManager wired.
    // Every other test of that send inherits getQuotaManager() == address(0), which makes
    // _consumeEtherQuota a no-op and leaves its external call out of the post-invocation tail.
    function test_quota_processMessage_storage_creating_destOwner_debits_and_refunds()
        public
        dealEther(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(5);

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        message.to = address(eBridge); // invocation prohibited -> full value refunded

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(wallet).balance, 2 ether);
        assertEq(wallet.receiveCount(), 1);
        assertEq(_ethConsumed(), message.value);
    }
}
