// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";
import "test/shared/bridge/helpers/MessageReceiver_CreatingFreshStorageSlots.sol";

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

contract TestBridge2_processMessage is TestBridge2Base {
    function test_bridge2_processMessage_basic() public dealEther(Alice) assertSameTotalBalance {
        vm.startPrank(Alice);

        IBridge.Message memory message;

        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.destChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = ethereumChainId;
        vm.expectRevert(Bridge.B_INVALID_CHAINID.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = taikoChainId + 1;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.srcChainId = taikoChainId;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.gasLimit = 1_000_000;
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);

        eBridge.processMessage(message, FAKE_PROOF);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        vm.prank(deployer);
        resolver.registerAddress(message.srcChainId, "bridge", address(0));

        vm.startPrank(Alice);

        message.id += 1;
        vm.expectRevert(IResolver.RESOLVED_TO_ZERO_ADDRESS.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        vm.stopPrank();
    }

    function test_bridge2_processMessage__special_to_address__0_fee__nonezero_gaslimit()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(eBridge);
        aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(eSignalService);
        aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
    }

    function test_bridge2_processMessage__special_to_address__0_fee__0_gaslimit()
        public
        dealEther(Alice)
        dealEther(Bob)
        assertSameTotalBalance
    {
        vm.startPrank(Alice);

        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        message.destOwner = Alice;
        uint256 aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(eBridge);
        aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        message.to = address(eSignalService);
        aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(Alice.balance, aliceBalance + 2 ether);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.stopPrank();

        message.value = 3 ether;

        vm.prank(Bob);
        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__nonezero_gaslimit()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Bob;

        uint256 bobBalance = Bob.balance;
        uint256 aliceBalance = Alice.balance;

        eBridge.processMessage(message, FAKE_PROOF);

        assertEq(Bob.balance, bobBalance + 2 ether);
        assertEq(Alice.balance, aliceBalance + 5_000_000);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        message.gasLimit = 10_000_000;
        bobBalance = Bob.balance;
        aliceBalance = Alice.balance;

        eBridge.processMessage(message, FAKE_PROOF);
        assertTrue(Bob.balance > bobBalance + 2 ether);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);
    }

    function test_bridge2_processMessage__special_to_address__nonezero_fee__0_gaslimit()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 0;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;

        uint256 aliceBalance = Alice.balance;

        eBridge.processMessage(message, FAKE_PROOF);

        assertEq(Alice.balance, aliceBalance + 2 ether + 5_000_000);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
    }

    function test_bridge2_processMessage__eoa_address__0_fee__nonezero_gaslimit()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(Alice.balance, aliceBalance);
        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__0_fee__0_gaslimit()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 0;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__nonezero_gaslimit()
        public
        transactBy(Carol)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
        assertTrue(Alice.balance > aliceBalance);
        assertTrue(Alice.balance < aliceBalance + 5_000_000);
    }

    function test_bridge2_processMessage__eoa_to_address__nonezero_fee__0_gaslimit()
        public
        transactBy(Alice)
        assertSameTotalBalance
    {
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 davidBalance = David.balance;

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);

        assertEq(David.balance, davidBalance + 2 ether);
    }

    function test_bridge2_processMessage__special_invocation() public transactBy(Carol) {
        Target target = new Target(eBridge);

        uint256 totalBalance = getBalanceForAccounts() + address(target).balance;
        IBridge.Message memory message;

        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;

        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.anotherFunc, (""));

        uint256 aliceBalance = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(Alice.balance, aliceBalance + 2 ether);
        assertEq(target.receivedEther(), 0 ether);

        message.data = "1";
        eBridge.processMessage(message, FAKE_PROOF);
        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 2 ether);

        (bytes32 msgHash, address from, uint64 srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);

        message.to = Bob;
        message.data = "something else";

        uint256 aliceBalanceBefore = Alice.balance;
        eBridge.processMessage(message, FAKE_PROOF);
        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        // With EIP-7702, EOAs can have code, so we no longer allow arbitrary function calls
        // to any address (EOA or contract). Value goes to destOwner when invocation is prohibited.
        assertEq(Bob.balance, 0);
        assertEq(Alice.balance, aliceBalanceBefore + 2 ether);

        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, (""));
        eBridge.processMessage(message, FAKE_PROOF);
        hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(target.receivedEther(), 4 ether);

        (msgHash, from, srcChainId) = target.ctx();
        assertEq(msgHash, hash);
        assertEq(from, message.from);
        assertEq(srcChainId, message.srcChainId);

        uint256 totalBalance2 = getBalanceForAccounts() + address(target).balance;
        assertEq(totalBalance2, totalBalance);
    }

    /// @dev The refund send to destOwner must budget for a smart wallet that creates fresh
    /// storage slots in its receive path. Writing 4+1 fresh slots costs ~112k gas under the
    /// current schedule — above the previous 35k cap and comparable to what a single fresh slot
    /// (97,920 gas) plus wallet overhead will cost under EIP-8037.
    function test_bridge2_processMessage__refund_to_storage_creating_wallet()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(4);

        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        // Invocation is prohibited for the bridge itself, so the full value is refunded to
        // destOwner through the gas-capped Ether send.
        message.to = address(eBridge);

        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(wallet).balance, 2 ether);
        assertEq(wallet.receiveCount(), 1);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether);
    }

    /// @dev End-to-end claim of bridged Ether by a storage-creating smart wallet with a relayer
    /// fee: the invocation pays the value to the wallet, and the unused fee is then refunded to
    /// the same wallet through the gas-capped Ether send.
    function test_bridge2_processMessage__storage_creating_wallet_claims_with_fee()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(4);

        uint256 carolBalance = Carol.balance;
        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        message.to = address(wallet);

        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        // The wallet received the value in the invocation and the fee remainder in the refund.
        assertEq(wallet.receiveCount(), 2);
        assertTrue(address(wallet).balance > 2 ether);
        assertTrue(address(wallet).balance < 2 ether + 5_000_000);
        // The relayer received the rest of the fee.
        uint256 relayerFee = Carol.balance - carolBalance;
        assertTrue(relayerFee > 0);
        assertEq(address(wallet).balance + relayerFee, 2 ether + 5_000_000);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether - 5_000_000);
    }

    /// @dev The cap still bounds how much gas a recipient can consume: a receive path far above
    /// the budget (7+1 fresh slots, ~179k gas) keeps failing the refund.
    function test_bridge2_processMessage__refund_receiver_exceeding_gas_cap()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(7);

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        message.to = address(eBridge);

        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.NEW);
        assertEq(address(wallet).balance, 0);
    }

    function test_bridge2_processMessage__context_transient_lifecycle() public transactBy(Carol) {
        Target target = new Target(eBridge);

        // No context is readable outside a message invocation.
        vm.expectRevert(Bridge.B_INVALID_CONTEXT.selector);
        eBridge.context();

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.value = 1 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, (""));

        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash1 = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash1) == IBridge.Status.DONE);

        (bytes32 msgHash,,) = target.ctx();
        assertEq(msgHash, hash1);

        // The context is cleared as soon as the invocation returns, within the same
        // transaction — the transient slots are reset per invocation, not per transaction.
        vm.expectRevert(Bridge.B_INVALID_CONTEXT.selector);
        eBridge.context();

        // A second invocation in the same transaction observes its own context.
        message.value = 2 ether;
        eBridge.processMessage(message, FAKE_PROOF);
        bytes32 hash2 = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash2) == IBridge.Status.DONE);
        assertTrue(hash2 != hash1);

        (msgHash,,) = target.ctx();
        assertEq(msgHash, hash2);

        vm.expectRevert(Bridge.B_INVALID_CONTEXT.selector);
        eBridge.context();
    }
}
