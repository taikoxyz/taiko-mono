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

/// @dev A message sender that implements `IRecallableSender`, so a recall hands it the Ether back
/// through `onMessageRecalled` instead of a plain `sendEtherAndVerify` to `srcOwner`.
contract QuotaRecallableSender is IRecallableSender, IERC165 {
    uint256 public recalledValue;

    receive() external payable { }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IRecallableSender).interfaceId
            || _interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    function onMessageRecalled(IBridge.Message calldata, bytes32) external payable {
        recalledValue += msg.value;
    }
}

/// @dev Verifies that the Bridge debits the Ether quota exactly for the Ether that actually leaves
/// the bridge ("debit only on actual release"), across the process/retry/recall lifecycle.
/// @dev The two paths debit different keys. A withdrawal (`processMessage`, `retryMessage`) pays
/// out Ether that entered from the destination chain, and debits the Ether withdrawal quota keyed
/// by `address(0)`. A recall returns Ether the same message locked here, so it is not a net
/// outflow and must not be able to exhaust the withdrawal quota; it debits the dedicated
/// `ETHER_RECALL_QUOTA_KEY` instead, which is unconfigured (and therefore unlimited) unless the
/// quota manager's owner arms it.
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

    // A recall releases value back to the source owner and debits it -- but under the dedicated
    // recall key, never under the Ether withdrawal quota that processMessage/retryMessage debit.
    function test_quota_recall_debits_recall_key_not_ether_quota() public transactBy(Carol) {
        IBridge.Message memory message = _l1ToL2Message(Alice, 1 ether);

        uint256 aliceBefore = Alice.balance;
        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);
        assertEq(qm.calls(), 0); // sending consumes no quota at all

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(Alice.balance - aliceBefore, 1 ether);

        assertEq(qm.consumed(eBridge.ETHER_RECALL_QUOTA_KEY()), 1 ether);
        assertEq(_ethConsumed(), 0);
        assertEq(qm.calls(), 1);
    }

    // The recall key is debited on the IRecallableSender branch too, where the Ether goes back to
    // `message.from` via `onMessageRecalled` rather than to `srcOwner`.
    function test_quota_recall_to_recallable_sender_debits_recall_key() public {
        QuotaRecallableSender sender = new QuotaRecallableSender();
        vm.deal(address(sender), 100 ether);

        IBridge.Message memory message = _l1ToL2Message(Alice, 1 ether);

        vm.prank(address(sender));
        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);
        assertEq(address(sender).balance, 99 ether);

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);

        // The sender, not `srcOwner`, got the Ether back.
        assertEq(sender.recalledValue(), 1 ether);
        assertEq(address(sender).balance, 100 ether);
        assertEq(Alice.balance, 0);

        assertEq(qm.consumed(eBridge.ETHER_RECALL_QUOTA_KEY()), 1 ether);
        assertEq(_ethConsumed(), 0);
    }

    // The recall key is a derived, non-zero address, so it can never alias the Ether key.
    function test_quota_recall_key_is_distinct_from_ether_key() public view {
        address recallKey = eBridge.ETHER_RECALL_QUOTA_KEY();
        assertTrue(recallKey != address(0));
        assertEq(recallKey, address(uint160(uint256(keccak256("ETHER_RECALL_QUOTA")))));
    }

    // Releasing zero Ether (here: a zero-value recall) skips the quota manager call entirely, so
    // the recall key is not even consulted.
    function test_quota_zero_value_skips_external_call() public transactBy(Carol) {
        IBridge.Message memory message = _l1ToL2Message(Alice, 0);

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 0 }(message);

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(qm.calls(), 0);
    }

    // The capped Ether send to a storage-creating destOwner, with a real QuotaManager wired.
    // Every other test of that send inherits getQuotaManager() == address(0), which makes
    // _consumeQuota a no-op and leaves its external call out of the post-invocation tail.
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
