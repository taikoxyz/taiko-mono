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

    function test_bridge2_processMessage__special_to_address__0_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.processMessage(message, fakeProof);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(bridge);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(signalService);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
    }

    function test_bridge2_processMessage__special_to_address__0_fee__0_gaslimit() public {
        vm.deal(Alice, 100 ether);
        vm.startPrank(Alice);

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, fakeProof);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(bridge);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(signalService);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        message.value = 3 ether;
        vm.deal(Bob, 100 ether);

        vm.prank(Bob);
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, fakeProof);

        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__nonezero_gaslimit()
        public
    {
        vm.deal(Alice, 100 ether);
        vm.startPrank(Alice);

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Bob;

        uint256 bobBalance = Bob.balance;
        uint256 aliceBalance = Alice.balance;

        bridge.processMessage(message, fakeProof);

        assertEq(Bob.balance, bobBalance + 2 ether);
        assertEq(Alice.balance, aliceBalance + 5_000_000);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        message.gasLimit = 10_000_000;
        bobBalance = Bob.balance;
        aliceBalance = Alice.balance;

        bridge.processMessage(message, fakeProof);
        assertTrue(Bob.balance > bobBalance + 2 ether);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);

        vm.stopPrank();
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__0_gaslimit() public {
        vm.deal(Alice, 100 ether);
        vm.startPrank(Alice);

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;

        uint256 aliceBalance = Alice.balance;

        bridge.processMessage(message, fakeProof);

        assertEq(Alice.balance, aliceBalance + 2 ether + 5_000_000);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        vm.stopPrank();
    }

    function test_bridge2_processMessage__eoa_address__0_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(Alice.balance, aliceBalance);
        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__0_fee__0_gaslimit()
        public
        transactedBy(Alice)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
        assertTrue(Alice.balance > aliceBalance);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__0_gaslimit()
        public
        transactedBy(Alice)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
        // assertEq(Alice.balance, aliceBalance +  1000000);
    }

    function test_bridge2_processMessage__special_invocation() public transactedBy(Carol) {
        TestToContract target = new TestToContract(bridge);

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(TestToContract.anotherFunc, (""));

        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(Alice.balance, aliceBalance + 2 ether);
        assertEq(target.receivedEther(), 0 ether);

        message.data = "1";
        bridge.processMessage(message, fakeProof);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 2 ether);

        (bytes32 msgHash, address from, uint64 srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);

        message.to = Bob;
        message.data = "something else";

        bridge.processMessage(message, fakeProof);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(Bob.balance, 2 ether);

        message.to = address(target);
        message.data = abi.encodeCall(TestToContract.onMessageInvocation, (""));
        bridge.processMessage(message, fakeProof);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 4 ether);

        (msgHash, from, srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);
    }
}
