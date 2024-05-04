// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Bridge2.t.sol";

contract BridgeTest2_processMessage is BridgeTest2 {
    function test_bridge2_processMessage_basic() public {
        vm.deal(Alice, 100 ether);
        vm.startPrank(Alice);

        IBridge.Message memory message;

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, fakeProof);

        message.destChainId = uint64(block.chainid);
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, fakeProof);

        message.srcChainId = uint64(block.chainid);
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, fakeProof);

        message.srcChainId = remoteChainId + 1;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, fakeProof);

        message.srcChainId = remoteChainId;
        vm.expectRevert(); // RESOLVER_ZERO_ADDR src bridge not registered
        bridge.processMessage(message, fakeProof);

        message.gasLimit = 1_000_000;
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.NEW);

        bridge.processMessage(message, fakeProof);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        vm.prank(owner);
        addressManager.setAddress(message.srcChainId, "bridge", address(0));

        vm.startPrank(Alice);

        message.id += 1;
        vm.expectRevert(); // RESOLVER_ZERO_ADDR src bridge not registered
        bridge.processMessage(message, fakeProof);

        vm.stopPrank();
    }

    function test_bridge2_processMessage_basic2() public transactedBy(Carol) {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 10_000_000;
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.processMessage(message, fakeProof);

        message.destOwner = Alice;
        bridge.processMessage(message, fakeProof);
    }
}
