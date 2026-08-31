// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";
import {
    MessageReceiver_CreatingFreshStorageSlots
} from "test/shared/bridge/helpers/MessageReceiver_CreatingFreshStorageSlots.sol";
import {
    MessageReceiver_RecordingGasBudget
} from "test/shared/bridge/helpers/MessageReceiver_RecordingGasBudget.sol";

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
    /// storage slots in its receive path. Writing 5+1 fresh slots costs ~133k gas under the
    /// current schedule, which clears the 112,920 a wallet that saturated the legacy 35k budget
    /// while writing one slot will need under EIP-8037 — 4+1 slots (~111k) does not.
    function test_bridge2_processMessage__refund_to_storage_creating_wallet()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(5);

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

    /// @dev End-to-end claim of bridged Ether by storage-creating smart wallets with a relayer
    /// fee: the invocation pays the value to `to`, and the unused fee is refunded to destOwner
    /// through the gas-capped Ether send. destOwner is deliberately a *different* contract from
    /// `to` so the capped send carries a first receive (5+1 fresh slots, ~133k gas). Pointing
    /// both at one wallet would make the refund a warm-counter second receive costing ~112k —
    /// just under the 112,920 a legacy one-slot wallet needs after EIP-8037, so it would not
    /// demonstrate the budget this cap exists to provide.
    function test_bridge2_processMessage__storage_creating_wallet_claims_with_fee()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots invocationWallet =
            new MessageReceiver_CreatingFreshStorageSlots(5);
        MessageReceiver_CreatingFreshStorageSlots refundWallet =
            new MessageReceiver_CreatingFreshStorageSlots(5);

        uint256 carolBalance = Carol.balance;
        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        // Derived from the bridge's own minimum so the invocation budget stays at 200,000
        // however GAS_RESERVE is retuned.
        message.gasLimit = eBridge.getMessageMinGasLimit(0) + 200_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = address(refundWallet);
        // With empty message.data the invocation is a plain value-bearing call that hits the
        // wallet's receive() — no onMessageInvocation implementation is required.
        message.to = address(invocationWallet);

        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        // The invocation delivered the value; the capped refund delivered the fee remainder.
        assertEq(invocationWallet.receiveCount(), 1);
        assertEq(refundWallet.receiveCount(), 1);
        assertEq(address(invocationWallet).balance, 2 ether);
        assertTrue(address(refundWallet).balance > 0);
        // The relayer received the rest of the fee, and nothing else moved.
        uint256 relayerFee = Carol.balance - carolBalance;
        assertTrue(relayerFee > 0);
        assertEq(
            address(invocationWallet).balance + address(refundWallet).balance + relayerFee,
            2 ether + 5_000_000
        );
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether - 5_000_000);
    }

    /// @dev The cap still bounds how much gas a recipient can consume: a receive path above the
    /// budget (6+1 fresh slots, ~156k gas) keeps failing the refund. 6 rather than 7 slots
    /// brackets the 135k cap as tightly as the schedule allows — 5+1 is the largest that fits.
    function test_bridge2_processMessage__refund_receiver_exceeding_gas_cap()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlots wallet =
            new MessageReceiver_CreatingFreshStorageSlots(6);

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

    /// @dev Pins the budget the capped Ether send actually forwards. The behavioural tests
    /// bracket the cap between "a receive path this heavy still fits" and "this one does not",
    /// which leaves a wide band of wrong values undetected; this measures it. It also needs no
    /// recalibration at a repricing fork, because the forwarded allowance is independent of
    /// what storage writes cost.
    function test_bridge2_processMessage__capped_send_forwards_expected_gas_budget()
        public
        transactBy(Carol)
    {
        MessageReceiver_RecordingGasBudget wallet = new MessageReceiver_RecordingGasBudget();

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        // Invocation is prohibited for the bridge itself, so the whole value goes through the
        // gas-capped send and the recorded budget is that send's allowance.
        message.to = address(eBridge);

        eBridge.processMessage(message, FAKE_PROOF);

        // _SEND_ETHER_GAS_LIMIT (135,000) + the 2,300 stipend, less frame-entry overhead.
        assertApproxEqAbs(wallet.recordedBudget(), 137_300, 500);
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
