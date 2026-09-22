// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract Target is IMessageInvocable {
    bool public toFail;

    function onMessageInvocation(bytes calldata) external payable {
        if (toFail) revert("failed");
    }

    function setToFail(bool fail) external {
        toFail = fail;
    }
}

contract TestBridge2_retryMessage is TestBridge2Base {
    /// @dev Marking a message FAILED is the first step of a recall, so while recalls are disabled
    /// a last attempt that fails reverts instead: the message stays RETRIABLE and can still be
    /// delivered by a later retry.
    function test_bridge2_retryMessage_lastAttemptFailure_RevertWhen_recallsDisabled()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        Target target = new Target();
        target.setToFail(true);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;

        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, ("hello"));
        message.gasLimit = 1_000_000;

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        vm.prank(Carol);
        eBridge.retryMessage(message, true);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Carol);
        eBridge.retryMessage(message, false);

        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        vm.prank(Alice);
        eBridge.retryMessage(message, false);

        // The last attempt fails too. Instead of marking the message FAILED, the whole
        // transaction reverts.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(Alice);
        eBridge.retryMessage(message, true);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);
        assertFalse(
            eSignalService.isSignalSent(address(eBridge), eBridge.signalForFailedMessage(hash))
        );

        // Because the message is still retriable, a later retry against a healthy target still
        // delivers it.
        target.setToFail(false);
        vm.prank(Alice);
        eBridge.retryMessage(message, false);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, message.value);
        assertEq(getBalanceForAccounts() + address(target).balance, totalBalance);
    }

    /// @dev A last attempt that succeeds never reaches the disabled branch, so it still marks the
    /// message DONE.
    function test_bridge2_retryMessage_lastAttemptSuccess_marksDone()
        public
        dealEther(Alice)
        dealEther(Carol)
    {
        Target target = new Target();
        target.setToFail(true);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;

        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, ("hello"));
        message.gasLimit = 1_000_000;

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        target.setToFail(false);

        vm.prank(Alice);
        eBridge.retryMessage(message, true);

        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(target).balance, message.value);
        assertEq(getBalanceForAccounts() + address(target).balance, totalBalance);
    }

    function test_bridge2_retryMessage_2() public dealEther(Alice) dealEther(Carol) {
        Target target = new Target();
        target.setToFail(true);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, ("hello"));
        message.gasLimit = 1_000_000;

        vm.prank(Carol);
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        target.setToFail(false);

        vm.prank(Alice);
        eBridge.retryMessage(message, false);

        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        uint256 totalBalance2 = getBalanceForAccounts() + address(target).balance;
        assertEq(totalBalance2, totalBalance);
    }
}
