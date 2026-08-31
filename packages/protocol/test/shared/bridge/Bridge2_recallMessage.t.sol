// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";
import {
    MessageReceiver_CreatingFreshStorageSlots
} from "test/shared/bridge/helpers/MessageReceiver_CreatingFreshStorageSlots.sol";

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

contract TestBridge2_recallMessage is TestBridge2Base {
    function test_bridge2_recallMessage_basic() public transactBy(Carol) assertSameTotalBalance {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.to = Zachary;

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.recallMessage(message, FAKE_PROOF);

        message.srcChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_MESSAGE_NOT_SENT.selector);
        eBridge.recallMessage(message, FAKE_PROOF);

        uint256 aliceBalance = Alice.balance;
        uint256 carolBalance = Carol.balance;
        uint256 bridgeBalance = address(eBridge).balance;

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);
        assertEq(Alice.balance, aliceBalance);
        assertEq(Carol.balance, carolBalance - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance + 1 ether);

        eBridge.recallMessage(m, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(m);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);

        assertEq(Alice.balance, aliceBalance + 1 ether);
        assertEq(Carol.balance, carolBalance - 1 ether);
        assertEq(address(eBridge).balance, bridgeBalance);

        // recall the same message again
        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        eBridge.recallMessage(m, FAKE_PROOF);
    }

    /// @dev A recalled message must be able to return its value to a smart-wallet srcOwner that
    /// creates fresh storage slots when receiving Ether (5+1 slots, ~133k gas here, clearing the
    /// 112,920 a one-slot wallet needs under EIP-8037), far above the previous 35k send cap.
    function test_bridge2_recallMessage_storage_creating_wallet_srcOwner()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(5);

        uint256 totalBalance = getBalanceForAccounts() + address(wallet).balance;

        IBridge.Message memory message;
        message.srcOwner = address(wallet);
        message.destOwner = Bob;
        message.srcChainId = ethereumChainId;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.to = Zachary;

        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);

        eBridge.recallMessage(m, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(m);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);

        assertEq(address(wallet).balance, 1 ether);
        assertEq(wallet.receiveCount(), 1);
        assertEq(getBalanceForAccounts() + address(wallet).balance, totalBalance);
    }

    function test_bridge2_recallMessage_callable_sender() public dealEther(Carol) {
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
        (bytes32 mhash, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);

        vm.prank(address(callableSender));
        eBridge.recallMessage(m, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(m);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.RECALLED);

        (bytes32 msgHash, address from, uint64 srcChainId) = callableSender.ctx();
        assertEq(msgHash, mhash);
        assertEq(from, address(eBridge));
        assertEq(srcChainId, ethereumChainId);

        uint256 totalBalance2 = getBalanceForAccounts() + address(callableSender).balance;
        assertEq(totalBalance2, totalBalance);
    }
}
