// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Bridge, IBridge, LibAddress, TestBridge2Base } from "./TestBridge2Base.sol";
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

contract TestBridge2_processMessagePayouts is TestBridge2Base {
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
