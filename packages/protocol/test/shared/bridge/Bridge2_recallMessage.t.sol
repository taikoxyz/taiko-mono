// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";

contract TestRecallableSender is IRecallableSender, IERC165 {
    IBridge private bridge;
    IBridge.Context public ctx;

    constructor(IBridge _bridge) {
        bridge = _bridge;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IRecallableSender).interfaceId
            || _interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    function onMessageRecalled(IBridge.Message calldata, bytes32) external payable {
        ctx = bridge.context();
    }
}

/// @dev `recallMessage` is switched off while `Bridge.RECALL_ENABLED` is false, so nothing can be
/// recalled and the Ether a sent message locked stays in the bridge. The dormant recall logic
/// itself is no longer exercised here: pinning it means re-running the shared suite with
/// `RECALL_ENABLED = true` AND this file - together with the other recall, fail and retry tests -
/// restored to its version from before recalls were disabled, i.e. from `main` at that commit.
/// The recall test for a storage-creating smart-wallet srcOwner, which is what pins the Ether
/// send budget such a wallet needs, exists only in that pre-disable version.
contract TestBridge2_recallMessage is TestBridge2Base {
    function test_bridge2_recallMessage_RevertWhen_recallsDisabled()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.to = Zachary;

        // The disabled guard is the first modifier, so it fires before `sameChain` rejects the
        // zero `srcChainId`...
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(message, FAKE_PROOF);

        // ...and before a never-sent message is rejected with `B_MESSAGE_NOT_SENT`.
        message.srcChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(message, FAKE_PROOF);

        uint256 aliceBalance = Alice.balance;
        uint256 carolBalance = Carol.balance;
        uint256 bridgeBalance = address(eBridge).balance;

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);
        assertEq(Alice.balance, aliceBalance);
        assertEq(Carol.balance, carolBalance - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance + 1 ether);

        // A message that really was sent cannot be recalled either.
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        eBridge.recallMessage(m, FAKE_PROOF);

        // The message never leaves NEW and its Ether stays in the bridge: Alice, the srcOwner, is
        // not paid out and Carol, who funded the message, is not refunded.
        bytes32 hash = eBridge.hashMessage(m);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        assertEq(Alice.balance, aliceBalance);
        assertEq(Carol.balance, carolBalance - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance + 1 ether);
    }

    /// @dev A sender implementing `IRecallableSender` is the only caller of `onMessageRecalled`;
    /// with recalls disabled that hook is never reached.
    function test_bridge2_recallMessage_RevertWhen_recallsDisabled_callableSender()
        public
        dealEther(Carol)
    {
        TestRecallableSender callableSender = new TestRecallableSender(eBridge);
        vm.deal(address(callableSender), 100 ether);

        uint256 totalBalance = getBalanceForAccounts() + address(callableSender).balance;

        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.srcChainId = ethereumChainId;
        message.to = Zachary;

        vm.prank(address(callableSender));
        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);

        uint256 senderBalance = address(callableSender).balance;

        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        vm.prank(address(callableSender));
        eBridge.recallMessage(m, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(m);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);

        // `onMessageRecalled` was never invoked, so the sender never recorded a bridge context...
        (bytes32 msgHash, address from, uint64 srcChainId) = callableSender.ctx();
        assertEq(msgHash, bytes32(0));
        assertEq(from, address(0));
        assertEq(srcChainId, 0);

        // ...and the Ether it sent is still held by the bridge.
        assertEq(address(callableSender).balance, senderBalance);
        assertEq(getBalanceForAccounts() + address(callableSender).balance, totalBalance);
    }
}
