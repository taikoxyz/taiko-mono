// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/src/Vm.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { DelegateController } from "src/layer2/governance/DelegateController.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { Layer2Test } from "test/layer2/Layer2Test.sol";

contract L2FeeVaultTest is Layer2Test {
    uint64 private constant MIN_RELAY_FEE = 0.001 ether;

    // Contracts on Ethereum
    address private daoController = randAddress();
    address private eBridge = randAddress();
    address private rewardPool = randAddress();

    // Contracts on Taiko
    Bridge private tBridge;
    DelegateController private tDelegateController;
    L2FeeVault private vault;

    function setUpOnEthereum() internal override {
        // Enables Ethereum as the destination chain of the Taiko bridge.
        register("bridge", eBridge);
    }

    function setUpOnTaiko() internal override {
        SignalService signalService = deploySignalServiceWithoutProof(
            address(this),
            address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_LAYER2")))),
            deployer
        );
        tBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(signalService), address(0), address(0), false)
            )
        );
        tDelegateController =
            deployDelegateController(ethereumChainId, address(tBridge), daoController);
        vault = L2FeeVault(
            deploy({
                name: "",
                impl: address(
                    new L2FeeVault(address(tBridge), ethereumChainId, rewardPool, MIN_RELAY_FEE)
                ),
                data: abi.encodeCall(L2FeeVault.init, (address(tDelegateController)))
            })
        );
    }

    // ---------------------------------------------------------------
    // constructor & init
    // ---------------------------------------------------------------

    function test_constructor_SetsTheSweepDestination() external view {
        assertEq(vault.l2Bridge(), address(tBridge));
        assertEq(vault.l1ChainId(), ethereumChainId);
        assertEq(vault.rewardPool(), rewardPool);
        assertEq(vault.minRelayFee(), MIN_RELAY_FEE);
        assertEq(vault.SWEEP_GAS_LIMIT(), 1_000_000);
    }

    function test_constructor_RevertWhen_AnyArgumentIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new L2FeeVault(address(0), ethereumChainId, rewardPool, MIN_RELAY_FEE);

        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new L2FeeVault(address(tBridge), 0, rewardPool, MIN_RELAY_FEE);

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new L2FeeVault(address(tBridge), ethereumChainId, address(0), MIN_RELAY_FEE);

        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new L2FeeVault(address(tBridge), ethereumChainId, rewardPool, 0);
    }

    function test_init_SetsOwner() external view {
        assertEq(vault.owner(), address(tDelegateController));
        assertFalse(vault.paused());
        assertEq(vault.sweptTotal(), 0);
        assertEq(vault.sweepNonce(), 0);
    }

    function test_init_RevertWhen_CalledTwice() external {
        vm.expectRevert("Initializable: contract is already initialized");
        vault.init(Alice);
    }

    // ---------------------------------------------------------------
    // Direct transfers
    // ---------------------------------------------------------------

    function test_directTransfer_Reverts() external onTaiko {
        vm.deal(Bob, 1 ether);

        vm.prank(Bob);
        (bool success,) = address(vault).call{ value: 1 ether }("");

        assertFalse(success);
        assertEq(address(vault).balance, 0);
        assertEq(Bob.balance, 1 ether);
    }

    // ---------------------------------------------------------------
    // sweep
    // ---------------------------------------------------------------

    function test_sweep_SendsWholeBalanceToTheRewardPool() external onTaiko {
        // Block fees reach the coinbase without a call, like vm.deal.
        vm.deal(address(vault), 2 ether);
        vm.deal(Carol, 1 ether);
        uint64 messageId = tBridge.nextMessageId();

        vm.recordLogs();
        vm.prank(Carol);
        bytes32 msgHash = vault.sweep{ value: 0.01 ether }();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (bytes32 sentHash, IBridge.Message memory message) = _messageSent(logs);
        assertEq(sentHash, msgHash);
        assertEq(message.id, messageId);
        assertEq(message.fee, 0.01 ether);
        assertEq(message.gasLimit, vault.SWEEP_GAS_LIMIT());
        assertEq(message.from, address(vault));
        assertEq(message.srcChainId, taikoChainId);
        assertEq(message.srcOwner, address(vault));
        assertEq(message.destChainId, ethereumChainId);
        assertEq(message.destOwner, rewardPool);
        assertEq(message.to, rewardPool);
        assertEq(message.value, 2 ether);
        assertEq(
            message.data,
            abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(uint64(0))))
        );
        assertEq(tBridge.hashMessage(message), msgHash);
        assertTrue(tBridge.isMessageSent(message));

        (uint64 nonce, uint256 amount, uint256 relayFee, bytes32 sweptHash) = _feesSwept(logs);
        assertEq(nonce, 0);
        assertEq(amount, 2 ether);
        assertEq(relayFee, 0.01 ether);
        assertEq(sweptHash, msgHash);

        assertEq(address(vault).balance, 0);
        assertEq(address(tBridge).balance, 2.01 ether);
        assertEq(Carol.balance, 0.99 ether);
        assertEq(vault.sweptTotal(), 2 ether);
        assertEq(vault.sweepNonce(), 1);
    }

    function test_sweep_IncrementsTheNonceEachSweep() external onTaiko {
        vm.deal(address(vault), 1 ether);
        vm.deal(Carol, 1 ether);
        vm.deal(David, 1 ether);
        vm.recordLogs();
        vm.prank(Carol);
        bytes32 firstHash = vault.sweep{ value: MIN_RELAY_FEE }();
        (, IBridge.Message memory first) = _messageSent(vm.getRecordedLogs());

        vm.deal(address(vault), 0.5 ether);
        vm.recordLogs();
        vm.prank(David);
        bytes32 secondHash = vault.sweep{ value: MIN_RELAY_FEE }();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (, IBridge.Message memory second) = _messageSent(logs);
        (uint64 nonce,,,) = _feesSwept(logs);

        assertEq(
            first.data,
            abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(uint64(0))))
        );
        assertEq(
            second.data,
            abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(uint64(1))))
        );
        assertEq(nonce, 1);
        assertEq(first.value, 1 ether);
        assertEq(second.value, 0.5 ether);
        assertEq(first.gasLimit, vault.SWEEP_GAS_LIMIT());
        assertEq(second.gasLimit, vault.SWEEP_GAS_LIMIT());
        assertTrue(firstHash != secondHash);
        assertTrue(tBridge.isMessageSent(first));
        assertTrue(tBridge.isMessageSent(second));
        assertEq(vault.sweptTotal(), 1.5 ether);
        assertEq(vault.sweepNonce(), 2);
    }

    function test_sweep_EmptyVaultIsANoOp() external onTaiko {
        uint64 messageId = tBridge.nextMessageId();

        vm.recordLogs();
        vm.prank(Carol);
        bytes32 msgHash = vault.sweep();

        assertEq(msgHash, 0);
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(tBridge.nextMessageId(), messageId);
        assertEq(vault.sweptTotal(), 0);
        assertEq(vault.sweepNonce(), 0);
    }

    function test_sweep_RevertWhen_EmptyVaultWithFee() external onTaiko {
        vm.deal(Carol, 1 ether);

        vm.expectRevert(L2FeeVault.EmptyVaultWithFee.selector);
        vm.prank(Carol);
        vault.sweep{ value: 1 }();
    }

    function test_sweep_RevertWhen_RelayFeeIsBelowTheMinimum() external onTaiko {
        vm.deal(address(vault), 1 ether);
        vm.deal(Carol, 1 ether);
        uint64 messageId = tBridge.nextMessageId();

        vm.expectRevert(L2FeeVault.RelayFeeTooLow.selector);
        vm.prank(Carol);
        vault.sweep();

        vm.expectRevert(L2FeeVault.RelayFeeTooLow.selector);
        vm.prank(Carol);
        vault.sweep{ value: MIN_RELAY_FEE - 1 }();

        assertEq(address(vault).balance, 1 ether);
        assertEq(tBridge.nextMessageId(), messageId);
        assertEq(vault.sweepNonce(), 0);
    }

    function test_sweep_AcceptsTheMinimumRelayFee() external onTaiko {
        vm.deal(address(vault), 1 ether);
        vm.deal(Carol, 1 ether);

        vm.recordLogs();
        vm.prank(Carol);
        bytes32 msgHash = vault.sweep{ value: MIN_RELAY_FEE }();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (bytes32 sentHash, IBridge.Message memory message) = _messageSent(logs);
        (,, uint256 relayFee,) = _feesSwept(logs);
        assertEq(sentHash, msgHash);
        assertEq(message.fee, MIN_RELAY_FEE);
        assertEq(message.gasLimit, vault.SWEEP_GAS_LIMIT());
        assertEq(message.value, 1 ether);
        assertEq(relayFee, MIN_RELAY_FEE);
        assertTrue(tBridge.isMessageSent(message));
        assertEq(address(vault).balance, 0);
        assertEq(Carol.balance, 1 ether - MIN_RELAY_FEE);
    }

    function test_sweep_AboveTheMinimumTheWholeValueIsTheRelayFee() external onTaiko {
        vm.deal(address(vault), 1 ether);
        uint256 relayFee = uint256(MIN_RELAY_FEE) * 7 + 3;
        vm.deal(Carol, relayFee);

        vm.recordLogs();
        vm.prank(Carol);
        vault.sweep{ value: relayFee }();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (, IBridge.Message memory message) = _messageSent(logs);
        (, uint256 amount, uint256 emittedFee,) = _feesSwept(logs);
        assertEq(message.fee, relayFee);
        assertEq(message.gasLimit, vault.SWEEP_GAS_LIMIT());
        assertEq(message.value, 1 ether);
        assertEq(amount, 1 ether);
        assertEq(emittedFee, relayFee);
        assertEq(address(tBridge).balance, 1 ether + relayFee);
        assertEq(Carol.balance, 0);
        assertEq(vault.sweptTotal(), 1 ether);
    }

    function test_sweep_GasLimitClearsTheBridgeMinimum() external view {
        bytes memory data =
            abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(type(uint64).max)));
        assertGt(vault.SWEEP_GAS_LIMIT(), tBridge.getMessageMinGasLimit(data.length));
    }

    function test_sweep_RevertWhen_RelayFeeExceedsUint64() external onTaiko {
        vm.deal(address(vault), 1 ether);
        uint256 relayFee = uint256(type(uint64).max) + 1;
        vm.deal(Carol, relayFee);

        vm.expectRevert(L2FeeVault.RelayFeeTooLarge.selector);
        vm.prank(Carol);
        vault.sweep{ value: relayFee }();
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Returns the only `MessageSent` the Taiko bridge emitted in `_logs`.
    function _messageSent(Vm.Log[] memory _logs)
        private
        view
        returns (bytes32 msgHash_, IBridge.Message memory message_)
    {
        uint256 found;
        for (uint256 i; i < _logs.length; ++i) {
            if (
                _logs[i].emitter != address(tBridge)
                    || _logs[i].topics[0] != IBridge.MessageSent.selector
            ) continue;
            msgHash_ = _logs[i].topics[1];
            message_ = abi.decode(_logs[i].data, (IBridge.Message));
            ++found;
        }
        assertEq(found, 1, "MessageSent count");
    }

    /// @dev Returns the fields of the only `FeesSwept` the vault emitted in `_logs`.
    function _feesSwept(Vm.Log[] memory _logs)
        private
        view
        returns (uint64 nonce_, uint256 amount_, uint256 relayFee_, bytes32 msgHash_)
    {
        uint256 found;
        for (uint256 i; i < _logs.length; ++i) {
            if (
                _logs[i].emitter != address(vault)
                    || _logs[i].topics[0] != L2FeeVault.FeesSwept.selector
            ) continue;
            nonce_ = uint64(uint256(_logs[i].topics[1]));
            (amount_, relayFee_, msgHash_) = abi.decode(_logs[i].data, (uint256, uint256, bytes32));
            ++found;
        }
        assertEq(found, 1, "FeesSwept count");
    }
}
