// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./Bridge2.t.sol";

contract BridgeTest2_failMessage is BridgeTest2 {
    function test_bridge2_failMessage_not_by_destOwner()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;
        message.gasLimit = 1_000_000;
        message.fee = 1000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = Bob;

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_retriable()
        public
        dealEther(Alice)
        dealEther(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;
        message.gasLimit = bridge.getMessageMinGasLimit(0) - 1;

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        bridge.failMessage(message);

        vm.prank(Carol);
        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        vm.prank(Alice);
        bridge.failMessage(message);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.FAILED);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(Alice);
        bridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_processed()
        public
        transactedBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        bridge.failMessage(message);
    }
}
