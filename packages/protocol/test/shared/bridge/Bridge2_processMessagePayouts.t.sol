// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Bridge, IBridge, LibAddress, TestBridge2Base } from "./TestBridge2Base.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

contract BridgePayoutReceiver {
    Bridge private immutable _bridge;
    bytes32 private _messageHash;
    bool private _rejectEther;
    bytes private _retryCall;

    event PaymentReceived(IBridge.Status status);
    event RetryAttempted(bool succeeded, bytes result);

    constructor(Bridge _bridgeAddress) {
        _bridge = _bridgeAddress;
    }

    function watch(bytes32 _hash, bool _reject) external {
        _messageHash = _hash;
        _rejectEther = _reject;
    }

    function retryOnPayment(IBridge.Message calldata _message) external {
        _retryCall = abi.encodeCall(IBridge.retryMessage, (_message, false));
    }

    receive() external payable {
        if (_rejectEther) revert ETH_REJECTED();
        emit PaymentReceived(_bridge.messageStatus(_messageHash));
        if (_retryCall.length != 0) {
            (bool succeeded, bytes memory result) = address(_bridge).call(_retryCall);
            emit RetryAttempted(succeeded, result);
        }
    }

    error ETH_REJECTED();
}

/// @dev Records the caller's gas at the quota call, which the bridge makes just before it writes
/// the message status.
contract GasRecordingQuotaManager {
    function consumeQuota(address, uint256) external {
        assembly {
            tstore(0, gas())
        }
    }

    function recordedGas() external view returns (uint256 gas_) {
        assembly {
            gas_ := tload(0)
        }
    }
}

/// @dev A relayer that processes a message with an exact gas operand and reports, from the same
/// transaction, a warm fresh-slot write cost and the gas recorded at the quota call.
contract FeeMeasuringRelayer {
    uint256 private _slot;

    function measure(
        Bridge _bridge,
        GasRecordingQuotaManager _quotaManager,
        IBridge.Message calldata _message,
        uint256 _gas
    )
        external
        returns (uint256 slotWriteGas_, uint256 quotaCallGas_)
    {
        // Warm the bridge and its paused flag so their access costs stay out of the result.
        _bridge.paused();

        uint256 value = _slot;
        uint256 gasBefore = gasleft();
        _slot = value + 1;
        slotWriteGas_ = gasBefore - gasleft();

        _bridge.processMessage{ gas: _gas }(_message, "");
        quotaCallGas_ = _quotaManager.recordedGas();
    }

    receive() external payable { }
}

contract TestBridge2_processMessagePayouts is TestBridge2Base {
    /// @dev The relayer fee measures gas up to a reading taken after the status write. The gas
    /// between the quota call and that reading must therefore be about one fresh-slot write.
    /// The bridge runs without a proxy so the gas operand is its exact starting gas.
    /// forge-config: default.isolate = true
    function test_processMessage_feeMeasurementIncludesStatusWrite() public {
        GasRecordingQuotaManager quotaManager = new GasRecordingQuotaManager();
        Bridge bridge = new Bridge(
            address(resolver), address(eSignalService), address(quotaManager), address(0), true
        );
        vm.deal(address(bridge), 10 ether);
        FeeMeasuringRelayer relayer = new FeeMeasuringRelayer();

        // The bridge is the target, so the invocation is skipped. A gas limit of one makes the
        // relayer earn the whole fee.
        IBridge.Message memory message = _l2ToL1Message(Alice, 0);
        message.to = address(bridge);
        message.fee = 1 ether;
        message.gasLimit = 1;

        uint256 processGas = 1_000_000;
        vm.recordLogs();
        (uint256 slotWriteGas, uint256 quotaCallGas) =
            relayer.measure{ gas: 2_000_000 }(bridge, quotaManager, message, processGas);

        Bridge.ProcessingStats memory stats = _processingStats(address(bridge));
        assertTrue(stats.processedByRelayer);
        assertEq(address(relayer).balance, message.fee);

        // Remove the fixed allowances to get the gas measured since processMessage started.
        uint256 calldataCost = bridge.getMessageMinGasLimit(0) - bridge.GAS_RESERVE();
        uint256 measured = stats.gasUsedInFeeCalc - bridge.GAS_OVERHEAD() - calldataCost;
        // The quota manager sees 63/64 of the bridge's gas at the call.
        int256 afterQuotaCall = int256(quotaCallGas * 64 / 63 + measured) - int256(processGas);
        assertApproxEqAbs(afterQuotaCall, int256(slotWriteGas), 5000);
    }

    function _processingStats(address _bridge)
        private
        returns (Bridge.ProcessingStats memory stats_)
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == _bridge && logs[i].topics[0] == Bridge.MessageProcessed.selector)
            {
                (, stats_) = abi.decode(logs[i].data, (IBridge.Message, Bridge.ProcessingStats));
                return stats_;
            }
        }
        revert("MessageProcessed not found");
    }

    function test_processMessage_payoutsObserveDoneStatus() public {
        _assertPayoutSequence(true, IBridge.Status.DONE);
    }

    function test_processMessage_payoutsObserveRetriableStatus() public {
        _assertPayoutSequence(false, IBridge.Status.RETRIABLE);
    }

    function test_processMessage_RevertWhen_refundFailsAfterInvocationAndRelayerPayout() public {
        BridgePayoutReceiver owner = new BridgePayoutReceiver(eBridge);
        BridgePayoutReceiver relayer = new BridgePayoutReceiver(eBridge);
        BridgePayoutReceiver recipient = new BridgePayoutReceiver(eBridge);

        IBridge.Message memory message = _l2ToL1Message(address(owner), 2 ether);
        message.fee = 5_000_000;
        message.to = address(recipient);
        bytes32 hash = eBridge.hashMessage(message);
        uint256 bridgeBalance = address(eBridge).balance;

        owner.watch(hash, true);
        relayer.watch(hash, false);
        recipient.watch(hash, false);

        vm.expectCall(address(recipient), message.value, "");
        vm.expectCall(address(relayer), "");
        vm.expectCall(address(owner), "");
        vm.prank(address(relayer));
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        eBridge.processMessage(message, FAKE_PROOF);

        assertEq(uint256(eBridge.messageStatus(hash)), uint256(IBridge.Status.NEW));
        assertEq(address(recipient).balance, 0);
        assertEq(address(relayer).balance, 0);
        assertEq(address(owner).balance, 0);
        assertEq(address(eBridge).balance, bridgeBalance);

        // The same message can be processed once the refund receiver accepts payment.
        owner.watch(hash, false);
        vm.prank(address(relayer));
        eBridge.processMessage(message, FAKE_PROOF);
        assertEq(uint256(eBridge.messageStatus(hash)), uint256(IBridge.Status.DONE));
        assertEq(address(recipient).balance, message.value);
        assertGt(address(relayer).balance, 0);
        assertGt(address(owner).balance, 0);
        assertEq(address(relayer).balance + address(owner).balance, message.fee);
    }

    function _assertPayoutSequence(
        bool _invocationSucceeds,
        IBridge.Status _expectedStatus
    )
        private
    {
        BridgePayoutReceiver owner = new BridgePayoutReceiver(eBridge);
        BridgePayoutReceiver relayer = new BridgePayoutReceiver(eBridge);
        BridgePayoutReceiver recipient = new BridgePayoutReceiver(eBridge);

        IBridge.Message memory message = _l2ToL1Message(address(owner), 2 ether);
        message.fee = 5_000_000;
        message.to = address(recipient);
        bytes32 hash = eBridge.hashMessage(message);

        owner.watch(hash, false);
        relayer.watch(hash, false);
        recipient.watch(hash, !_invocationSucceeds);
        if (!_invocationSucceeds) owner.retryOnPayment(message);

        if (_invocationSucceeds) {
            vm.expectEmit(address(recipient));
            emit BridgePayoutReceiver.PaymentReceived(IBridge.Status.NEW);
        }
        vm.expectEmit(address(eBridge));
        emit IBridge.MessageStatusChanged(hash, _expectedStatus);
        vm.expectEmit(address(relayer));
        emit BridgePayoutReceiver.PaymentReceived(_expectedStatus);
        vm.expectEmit(address(owner));
        emit BridgePayoutReceiver.PaymentReceived(_expectedStatus);
        if (!_invocationSucceeds) {
            vm.expectEmit(address(owner));
            emit BridgePayoutReceiver.RetryAttempted(
                false, abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector)
            );
        }

        vm.prank(address(relayer));
        (IBridge.Status status,) = eBridge.processMessage(message, FAKE_PROOF);

        assertEq(uint256(status), uint256(_expectedStatus));
        assertEq(address(recipient).balance, _invocationSucceeds ? message.value : 0);
        assertEq(address(relayer).balance + address(owner).balance, message.fee);
    }
}
