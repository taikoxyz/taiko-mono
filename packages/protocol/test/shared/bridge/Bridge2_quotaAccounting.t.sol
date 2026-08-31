// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/CountingQuotaManager.sol";
import "./TestBridge2Base.sol";

contract QuotaTarget is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool _fail) external {
        toFail = _fail;
    }
}

/// @dev Verifies that the Bridge debits the Ether quota exactly for the Ether that actually leaves
/// the bridge ("debit only on actual release"), across the process/retry/recall lifecycle.
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

    // A recall releases value back to the source owner, so the value is debited.
    function test_quota_recall_debits_value() public transactBy(Carol) {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.value = 1 ether;
        message.to = Zachary;

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);
        assertEq(_ethConsumed(), 0); // sending does not consume withdrawal quota

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(_ethConsumed(), message.value);
    }

    // Releasing zero Ether (here: a zero-value recall) skips the quota manager call entirely.
    function test_quota_zero_value_skips_external_call() public transactBy(Carol) {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.srcChainId = ethereumChainId;
        message.value = 0;
        message.to = Zachary;

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 0 }(message);

        eBridge.recallMessage(m, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(m)) == IBridge.Status.RECALLED);
        assertEq(qm.calls(), 0);
    }
}
