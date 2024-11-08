// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bridge2.t.sol";

contract Target is IMessageInvocable {
    uint256 public receivedEther;
    IBridge private bridge;
    IBridge.Context public ctx;

    constructor(IBridge _bridge) {
        bridge = _bridge;
    }

    function onMessageInvocation(bytes calldata) external payable {
        ctx = bridge.context();
        receivedEther += msg.value;
    }

    function anotherFunc(bytes calldata) external payable {
        receivedEther += msg.value;
    }

    fallback() external payable {
        ctx = bridge.context();
        receivedEther += msg.value;
    }

    receive() external payable { }
}

contract OutOfQuotaManager is IQuotaManager {
    function consumeQuota(address, uint256) external pure {
        revert("out of quota");
    }
}

contract AlwaysAvailableQuotaManager is IQuotaManager {
    function consumeQuota(address, uint256) external pure { }
}

contract BridgeTest2_processMessage is BridgeTest2 {
    function test_bridge2_processMessage_basic() public dealEther(Alice) assertSameTotalBalance {
        vm.startPrank(Alice);

        IBridge.Message memory message;

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.destChainId = uint64(block.chainid);
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = uint64(block.chainid);
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = destChainId + 1;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = destChainId;
        vm.expectRevert(); // RESOLVER_ZERO_ADDR src bridge not registered
        bridge.processMessage(message, FAKE_PROOF);

        message.gasLimit = 1_000_000;
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.NEW);

        bridge.processMessage(message, FAKE_PROOF);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        vm.prank(deployer);
        resolver.setAddress(message.srcChainId, "bridge", address(0));

        vm.startPrank(Alice);

        message.id += 1;
        vm.expectRevert(); // RESOLVER_ZERO_ADDR src bridge not registered
        bridge.processMessage(message, FAKE_PROOF);

        vm.stopPrank();
    }

    function test_bridge2_processMessage__special_to_address__0_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(bridge);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(signalService);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
    }

    function test_bridge2_processMessage__special_to_address__0_fee__0_gaslimit()
        public
        dealEther(Alice)
        dealEther(Bob)
        assertSameTotalBalance
    {
        vm.startPrank(Alice);

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, FAKE_PROOF);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(bridge);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(signalService);
        aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        message.value = 3 ether;

        vm.prank(Bob);
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.processMessage(message, FAKE_PROOF);

        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__nonezero_gaslimit()
        public
        transactedBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Bob;

        uint256 bobBalance = Bob.balance;
        uint256 aliceBalance = Alice.balance;

        bridge.processMessage(message, FAKE_PROOF);

        assertEq(Bob.balance, bobBalance + 2 ether);
        assertEq(Alice.balance, aliceBalance + 5_000_000);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        message.gasLimit = 10_000_000;
        bobBalance = Bob.balance;
        aliceBalance = Alice.balance;

        bridge.processMessage(message, FAKE_PROOF);
        assertTrue(Bob.balance > bobBalance + 2 ether);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__0_gaslimit()
        public
        transactedBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 0;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;

        uint256 aliceBalance = Alice.balance;

        bridge.processMessage(message, FAKE_PROOF);

        assertEq(Alice.balance, aliceBalance + 2 ether + 5_000_000);

        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
    }

    function test_bridge2_processMessage__eoa_address__0_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(Alice.balance, aliceBalance);
        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__0_fee__0_gaslimit()
        public
        transactedBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__nonezero_gaslimit()
        public
        transactedBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
        assertTrue(Alice.balance > aliceBalance);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__0_gaslimit()
        public
        transactedBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__special_invocation() public transactedBy(Carol) {
        Target target = new Target(bridge);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.anotherFunc, (""));

        uint256 aliceBalance = Alice.balance;
        bridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(Alice.balance, aliceBalance + 2 ether);
        assertEq(target.receivedEther(), 0 ether);

        message.data = "1";
        bridge.processMessage(message, FAKE_PROOF);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 2 ether);

        (bytes32 msgHash, address from, uint64 srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);

        message.to = Bob;
        message.data = "something else";

        bridge.processMessage(message, FAKE_PROOF);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(Bob.balance, 2 ether);

        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, (""));
        bridge.processMessage(message, FAKE_PROOF);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 4 ether);

        (msgHash, from, srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);

        uint256 totalBalance2 = getBalanceForAccounts() + address(target).balance;
        assertEq(totalBalance2, totalBalance);
    }

    function test_bridge2_processMessage__no_ether_quota()
        public
        dealEther(Bob)
        dealEther(Alice)
        assertSameTotalBalance
    {
        vm.startPrank(deployer);
        resolver.setAddress(
            uint64(block.chainid), "quota_manager", address(new OutOfQuotaManager())
        );
        vm.stopPrank();

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        vm.prank(Bob);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        bridge.processMessage(message, FAKE_PROOF);

        vm.prank(Alice);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        bridge.processMessage(message, FAKE_PROOF);
    }

    function test_bridge2_processMessage_and_retryMessage_malicious_way()
        public
        dealEther(Bob)
        dealEther(Alice)
        assertSameTotalBalance
    {
        vm.startPrank(deployer);
        resolver.setAddress(
            uint64(block.chainid), "quota_manager", address(new OutOfQuotaManager())
        );
        vm.stopPrank();

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = destChainId;

        bytes32 hashOfMaliciousMessage =
            0x3c6e0b8a9c15224b7f0a1e5f4c8f7683d5a0a4e32a34c6c7c7e1f4d9a9d9f6b4;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(bridge);
        message.data = abi.encodeWithSignature("sendSignal(bytes32)", hashOfMaliciousMessage);

        vm.prank(Alice);
        vm.expectRevert(Bridge.B_OUT_OF_ETH_QUOTA.selector);
        bridge.processMessage(message, FAKE_PROOF);
    }
}
