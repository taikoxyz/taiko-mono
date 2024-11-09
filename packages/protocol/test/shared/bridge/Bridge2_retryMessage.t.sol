// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bridge2.t.sol";

contract Target is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool fail) external {
        toFail = fail;
    }
}

contract BridgeTest2_retryMessage is BridgeTest2 {
    function test_bridge2_retryMessage_1()
        public
        dealEther(Alice)
        dealEther(Carol)
        assertSameTotalBalance
    {
        Target target = new Target();
        target.setToFail(true);

        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId  = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, ("hello"));
        message.gasLimit = 1_000_000;

        vm.prank(Carol);
        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        vm.prank(Carol);
        bridge.retryMessage(message, true);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Carol);
        bridge.retryMessage(message, false);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Alice);
        bridge.retryMessage(message, false);

        vm.prank(Alice);
        bridge.retryMessage(message, true);

        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.FAILED);
    }

    function test_bridge2_retryMessage_2() public dealEther(Alice) dealEther(Carol) {
        Target target = new Target();
        target.setToFail(true);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId  = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, ("hello"));
        message.gasLimit = 1_000_000;

        vm.prank(Carol);
        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        target.setToFail(false);

        vm.prank(Alice);
        bridge.retryMessage(message, false);

        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        uint256 totalBalance2 = getBalanceForAccounts() + address(target).balance;
        assertEq(totalBalance2, totalBalance);
    }
}
