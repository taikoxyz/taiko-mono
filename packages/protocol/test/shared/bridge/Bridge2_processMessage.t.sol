// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";
import {
    MessageReceiver_CreatingFreshStorageSlot
} from "test/shared/bridge/helpers/MessageReceiver_CreatingFreshStorageSlot.sol";
import {
    MessageReceiver_RecordingGasBudget
} from "test/shared/bridge/helpers/MessageReceiver_RecordingGasBudget.sol";

interface IEvmVersionCheatcode {
    function getEvmVersion() external pure returns (string memory);
}

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
    /// @dev Mirrors Bridge._SEND_ETHER_GAS_LIMIT (135,000, `private`) plus the 2,300 stipend a
    /// value-bearing CALL always adds. Retuning the bridge constant must move this one too.
    /// Written as a literal rather than `135_000 + 2_300` because forge fmt's handling of
    /// underscores inside a constant expression differs between versions.
    uint256 private constant _EXPECTED_SEND_BUDGET = 137_300;

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

        message.fee = 0;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.anotherFunc, (""));
        // The first allowed invocation persists the context and received amount in fresh slots.
        message.gasLimit = eBridge.getMessageMinGasLimit(message.data.length) + 400_000;

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

    /// @dev The capped refund funds a wallet that creates a fresh storage slot on first receipt.
    /// forge-config: default.isolate = true
    function test_bridge2_processMessage__refund_to_storage_creating_wallet()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlot wallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);

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

        // Bound the isolated processing transaction and verify the gas charged to the wallet.
        uint64 nonceBefore = vm.getNonce(Carol);
        vm.recordLogs();
        eBridge.processMessage{ gas: 500_000 }(message, FAKE_PROOF);
        assertEq(vm.getNonce(Carol), nonceBefore + 1, "isolated processing transaction");

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(address(wallet).balance, 2 ether);
        assertEq(wallet.receiveCount(), 1);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 storageGas;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(wallet) && logs[i].topics.length == 1
                    && logs[i].topics[0]
                        == MessageReceiver_CreatingFreshStorageSlot.ReceiveStorageGas.selector
            ) {
                storageGas = abi.decode(logs[i].data, (uint256));
                break;
            }
        }
        // Check the active runtime and allow for the instructions in the measured interval.
        string memory runtime = IEvmVersionCheatcode(address(vm)).getEvmVersion();
        uint256 slotCost = keccak256(bytes(runtime)) == keccak256("amsterdam") ? 110_020 : 22_100;
        assertGe(storageGas, slotCost, "fresh slot charged to the wallet's gas budget");
        assertLe(storageGas, slotCost + 300, "slot measurement opcode overhead");
    }

    /// @dev End-to-end claim of bridged Ether by storage-creating smart wallets with a relayer
    /// fee: the invocation pays the value to `to`, and the unused fee is refunded to destOwner
    /// through the gas-capped Ether send. Separate wallets make both paths create a fresh slot.
    function test_bridge2_processMessage__storage_creating_wallet_claims_with_fee()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlot invocationWallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);
        MessageReceiver_CreatingFreshStorageSlot refundWallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);

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

    /// @dev The recipient needs the whole forwarding budget in execution work after updating
    /// storage. It runs out of gas under either schedule and the failed refund rolls back.
    function test_bridge2_processMessage_RevertWhen_refund_receiver_exceeds_gas_cap()
        public
        transactBy(Carol)
    {
        MessageReceiver_CreatingFreshStorageSlot wallet =
            new MessageReceiver_CreatingFreshStorageSlot(_EXPECTED_SEND_BUDGET);

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
        assertEq(wallet.receiveCount(), 0);
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

        // The allowance can never exceed the cap plus the stipend, and frame entry costs a
        // handful of opcodes below it (57 gas as measured). A tolerance wide enough to absorb
        // real variation but far tighter than one slot-creation charge is what keeps this test,
        // rather than the behavioural brackets, the binding constraint on the constant.
        assertLe(wallet.recordedBudget(), _EXPECTED_SEND_BUDGET);
        assertGe(wallet.recordedBudget(), _EXPECTED_SEND_BUDGET - 100);
    }

    /// @dev Self-claim path with invocation prohibited: msg.sender == destOwner, so the relayer
    /// payout is skipped entirely and the value plus the whole fee arrive in a single capped
    /// send. Every other test of that send runs the relayer path, where a fee cut is deducted.
    function test_bridge2_processMessage__self_claim_by_storage_creating_wallet() public {
        MessageReceiver_CreatingFreshStorageSlot wallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);

        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = address(wallet);
        message.to = address(eBridge);

        vm.prank(address(wallet));
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        // No relayer cut on this path: the value and the entire fee arrive in one send.
        assertEq(wallet.receiveCount(), 1);
        assertEq(address(wallet).balance, 2 ether + 5_000_000);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether - 5_000_000);
    }

    /// @dev The self-claim path's other half: with an invocable `to`, processMessage forwards
    /// raw `gasleft()` to the invocation. The relayer path would forward just one gas plus the
    /// stipend from this message budget, too little for the wallet under either schedule.
    /// The separate refund wallet also creates a fresh slot on its first receive.
    function test_bridge2_processMessage__self_claim_with_invocation() public {
        MessageReceiver_CreatingFreshStorageSlot invocationWallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);
        MessageReceiver_CreatingFreshStorageSlot refundWallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);

        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = eBridge.getMessageMinGasLimit(0) + 1;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = address(refundWallet);
        // Empty data and a plain contract `to`: invocation is permitted, so the gasleft() arm
        // of the invocation-budget ternary is taken.
        message.to = address(invocationWallet);

        vm.prank(address(refundWallet));
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        assertEq(invocationWallet.receiveCount(), 1);
        assertEq(refundWallet.receiveCount(), 1);
        assertEq(address(invocationWallet).balance, 2 ether);
        // Self-claim takes no relayer cut, so the entire fee is refunded.
        assertEq(address(refundWallet).balance, 5_000_000);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether - 5_000_000);
    }

    /// @dev The relayer fee payout is a *separate* capped send from the destOwner refund, and a
    /// relayer may itself be a contract. Every other test here pays the fee to an EOA, where the
    /// 2,300 stipend alone suffices and the cap is therefore unconstrained: setting that send's
    /// gas operand to zero leaves the whole suite green. Keeping `destOwner` an EOA makes the
    /// relayer payout the only leg that needs the budget, so this test pins it specifically.
    function test_bridge2_processMessage__fee_payout_to_storage_creating_relayer() public {
        MessageReceiver_CreatingFreshStorageSlot relayerWallet =
            new MessageReceiver_CreatingFreshStorageSlot(_STORAGE_WALLET_WORK_GAS);

        uint256 aliceBalance = Alice.balance;
        uint256 bridgeBalance = address(eBridge).balance;

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(eBridge); // invocation prohibited -> the value is refunded to Alice

        vm.prank(address(relayerWallet));
        eBridge.processMessage(message, FAKE_PROOF);

        bytes32 hash = eBridge.hashMessage(message);
        assertTrue(eBridge.messageStatus(hash) == IBridge.Status.DONE);
        // The relayer's cut arrived through the capped send, as a first receive.
        assertEq(relayerWallet.receiveCount(), 1);
        uint256 relayerFee = address(relayerWallet).balance;
        assertTrue(relayerFee > 0);
        // Alice got the value plus the fee the relayer left behind, and nothing leaked.
        assertEq(Alice.balance, aliceBalance + 2 ether + 5_000_000 - relayerFee);
        assertEq(address(eBridge).balance, bridgeBalance - 2 ether - 5_000_000);
    }

    function test_bridge2_processMessage__context_transient_lifecycle() public transactBy(Carol) {
        Target target = new Target(eBridge);

        // No context is readable outside a message invocation.
        vm.expectRevert(Bridge.B_INVALID_CONTEXT.selector);
        eBridge.context();

        IBridge.Message memory message;
        message.destChainId = ethereumChainId;
        message.srcChainId = taikoChainId;
        message.value = 1 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(Target.onMessageInvocation, (""));
        // Give the recipient enough gas to store the context under either schedule.
        message.gasLimit = eBridge.getMessageMinGasLimit(message.data.length) + 400_000;

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
