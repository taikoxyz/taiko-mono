// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

/// @dev `failMessage` is switched off while `Bridge.RECALL_ENABLED` is false. Its guard is the
/// first modifier, so every call reverts with `B_RECALL_DISABLED` whatever the caller and whatever
/// the message's status, and no message can reach `Status.FAILED`.
contract TestBridge2_failMessage is TestBridge2Base {
    function test_bridge2_failMessage_RevertWhen_notByDestOwner()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 1000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = Bob;

        // The disabled guard runs before the `destOwner` check, so Carol no longer gets
        // `B_PERMISSION_DENIED`.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.failMessage(message);
    }

    function test_bridge2_failMessage_RevertWhen_messageRetriable()
        public
        dealEther(Alice)
        dealEther(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;
        // Below the minimum, so the invocation is left no gas and the delivery fails.
        message.gasLimit = eBridge.getMessageMinGasLimit(0) - 1;

        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Alice);
        eBridge.failMessage(message);

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        // Even the destOwner cannot fail a retriable message any more.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Alice);
        eBridge.failMessage(message);

        // The message stays retriable and no failure signal is sent, so the source chain is never
        // handed the proof a recall needs.
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            eSignalService.isSignalSent(address(eBridge), eBridge.signalForFailedMessage(hash))
        );
    }

    function test_bridge2_failMessage_RevertWhen_messageProcessed()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        // The disabled guard runs before the status check, so a processed message reverts with
        // `B_RECALL_DISABLED` rather than `B_INVALID_STATUS`.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.failMessage(message);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
    }
}
