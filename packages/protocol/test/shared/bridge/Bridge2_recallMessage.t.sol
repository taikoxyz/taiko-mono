// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bridge2.t.sol";

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

contract BridgeTest2_recallMessage is BridgeTest2 {
    function test_bridge2_recallMessage_basic() public transactedBy(Carol) assertSameTotalBalance {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.value = 1 ether;

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

    function test_bridge2_recallMessage_missing_local_signal_service()
        public
        dealEther(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;
        message.srcOwner = Alice;
        message.destOwner = Bob;
        message.destChainId = taikoChainId;
        message.value = 1 ether;
        message.srcChainId = ethereumChainId;

        vm.prank(Carol);
        (, IBridge.Message memory m) = eBridge.sendMessage{ value: 1 ether }(message);

        vm.prank(deployer);
        register("signal_service", address(0));

        vm.prank(Carol);
        vm.expectRevert();
        eBridge.recallMessage(m, FAKE_PROOF);
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
