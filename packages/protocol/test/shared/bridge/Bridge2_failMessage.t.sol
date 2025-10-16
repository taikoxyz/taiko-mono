// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract TestBridge2_failMessage is TestBridge2Base {
    function test_bridge2_failMessage_not_by_destOwner()
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

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        eBridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_retriable()
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
        message.gasLimit = eBridge.getMessageMinGasLimit(0) - 1;

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        eBridge.failMessage(message);

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        vm.prank(Alice);
        eBridge.failMessage(message);
        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.FAILED);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        eBridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_processed()
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

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        eBridge.failMessage(message);
    }
}
