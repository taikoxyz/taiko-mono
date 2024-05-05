// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Bridge2.t.sol";

contract BridgeTest2_retryMessage is BridgeTest2 {
    function test_bridge2_retryMessage()
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

        vm.prank(Carol);
        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        vm.prank(Carol);
        bridge.retryMessage(message, true);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Carol);
        bridge.retryMessage(message, false);

        vm.prank(Alice);
        bridge.retryMessage(message, false);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
    }
}
