// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Bridge, IBridge, TestBridge2Base } from "./TestBridge2Base.sol";
import {
    MessageReceiver_RecordingGasBudget
} from "./helpers/MessageReceiver_RecordingGasBudget.sol";

/// @dev Relays a message with an exact gas operand and always reverts, so every attempt starts
/// from the same state. The revert data carries the outcome.
contract ProcessMessageProbe {
    error Processed(IBridge.Status status, uint256 recordedBudget, uint256 recipientBalance);
    error Failed(bytes reason);

    function probe(
        Bridge _bridge,
        IBridge.Message calldata _message,
        uint256 _gas,
        bool _readBudget
    )
        external
    {
        try _bridge.processMessage{ gas: _gas }(_message, "") returns (
            IBridge.Status status, IBridge.StatusReason
        ) {
            uint256 budget = _readBudget
                ? MessageReceiver_RecordingGasBudget(payable(_message.to)).recordedBudget()
                : 0;
            revert Processed(status, budget, _message.to.balance);
        } catch (bytes memory reason) {
            revert Failed(reason);
        }
    }
}

contract TestBridge2_invocationGas is TestBridge2Base {
    uint32 private constant _INVOCATION_GAS = 200_000;

    function test_processMessage_forwardsValueAndGasToDelegatedRecipient() public {
        MessageReceiver_RecordingGasBudget implementation = new MessageReceiver_RecordingGasBudget();
        address recipient = makeAddr("delegated recipient");
        // Set the EIP-7702 designator directly to exercise CALL's delegation resolution.
        vm.etch(recipient, abi.encodePacked(hex"ef0100", address(implementation)));

        _processValueMessage(recipient, 300_000);

        uint256 recordedBudget =
            MessageReceiver_RecordingGasBudget(payable(recipient)).recordedBudget();
        uint256 expectedBudget = uint256(_INVOCATION_GAS) + 2300;
        assertLe(recordedBudget, expectedBudget);
        // Account for the opcodes executed before GAS in the recipient frame.
        assertGe(recordedBudget, expectedBudget - 100);
    }

    function test_processMessage_forwardsGasWithoutValueToWarmRecipient() public {
        MessageReceiver_RecordingGasBudget recipient = new MessageReceiver_RecordingGasBudget();
        // Read the initial value before processing to explicitly warm the recipient account.
        assertEq(recipient.recordedBudget(), 1);

        IBridge.Message memory message = _l2ToL1Message(Alice, 0);
        message.to = address(recipient);
        message.data = hex"01"; // Nonempty data reaches the recorder's fallback.
        message.gasLimit = eBridge.getMessageMinGasLimit(message.data.length) + _INVOCATION_GAS;

        vm.prank(Carol);
        (IBridge.Status status,) = eBridge.processMessage{ gas: 300_000 }(message, FAKE_PROOF);

        assertTrue(status == IBridge.Status.DONE);
        uint256 recordedBudget = recipient.recordedBudget();
        assertLe(recordedBudget, _INVOCATION_GAS);
        // Zero-value calls get no stipend. Allow for the opcodes before GAS in the callee.
        assertGe(recordedBudget, _INVOCATION_GAS - 100);
    }

    function test_processMessage_forwardsValueToNewAccount() public {
        address recipient = makeAddr("new recipient");
        assertEq(recipient.codehash, bytes32(0));

        // Include the new-account charge and the proof and status writes on Amsterdam.
        _processValueMessage(recipient, 550_000);
    }

    function test_processMessage_forwardsValueToDrainedAccountWithNonce() public {
        address recipient = makeAddr("drained recipient");
        vm.setNonce(recipient, 1);
        assertEq(recipient.balance, 0);
        assertEq(recipient.code.length, 0);

        // Fits the existing-account budget. Adding an unnecessary creation charge would
        // make the 200,000 gas invocation exceed the 300,000 gas supplied to processMessage.
        _processValueMessage(recipient, 300_000);
    }

    /// forge-config: default.isolate = true
    function test_processMessage_invocationGasBoundary_coldRecipientWithoutValue() public {
        MessageReceiver_RecordingGasBudget recipient = new MessageReceiver_RecordingGasBudget();

        IBridge.Message memory message = _l2ToL1Message(Alice, 0);
        message.to = address(recipient);
        message.data = hex"01"; // Nonempty data reaches the recorder's fallback.
        message.gasLimit = eBridge.getMessageMinGasLimit(message.data.length) + _INVOCATION_GAS;

        // Zero-value calls get no stipend.
        _assertInvocationGasBoundary(message, true, _INVOCATION_GAS);
    }

    /// forge-config: default.isolate = true
    function test_processMessage_invocationGasBoundary_valueToNewAccount() public {
        address recipient = makeAddr("new boundary recipient");
        assertEq(recipient.codehash, bytes32(0));

        IBridge.Message memory message = _l2ToL1Message(Alice, 2 ether);
        message.to = recipient;
        message.gasLimit = eBridge.getMessageMinGasLimit(0) + _INVOCATION_GAS;

        // An account without code records nothing; the probe checks the delivered value.
        _assertInvocationGasBoundary(message, false, 0);
    }

    /// forge-config: default.isolate = true
    function test_processMessage_invocationGasBoundary_valueToDelegatedRecipient() public {
        MessageReceiver_RecordingGasBudget implementation = new MessageReceiver_RecordingGasBudget();
        address recipient = makeAddr("delegated boundary recipient");
        vm.etch(recipient, abi.encodePacked(hex"ef0100", address(implementation)));
        // Initialize the recorded slot so the recipient returns most of its budget. Otherwise
        // the gas left after the call, not the forwarding check, limits processMessage.
        vm.store(recipient, bytes32(0), bytes32(uint256(1)));

        IBridge.Message memory message = _l2ToL1Message(Alice, 2 ether);
        message.to = recipient;
        message.gasLimit = eBridge.getMessageMinGasLimit(0) + _INVOCATION_GAS;

        // A value-bearing call adds the 2,300 stipend on top of the gas operand.
        _assertInvocationGasBoundary(message, true, uint256(_INVOCATION_GAS) + 2300);
    }

    /// @dev Finds the smallest processMessage gas that succeeds, then checks that one gas less
    /// fails the forwarding check, and that at the boundary the recipient gets its whole budget.
    function _assertInvocationGasBoundary(
        IBridge.Message memory _message,
        bool _readBudget,
        uint256 _expectedBudget
    )
        private
    {
        ProcessMessageProbe probe = new ProcessMessageProbe();

        uint256 low = 100_000;
        uint256 high = 2_000_000;
        assertFalse(_probeSucceeds(probe, _message, low, _readBudget), "low bound succeeds");
        assertTrue(_probeSucceeds(probe, _message, high, _readBudget), "high bound fails");
        while (high - low > 1) {
            uint256 mid = (low + high) / 2;
            if (_probeSucceeds(probe, _message, mid, _readBudget)) high = mid;
            else low = mid;
        }

        (bool ok, bytes memory result) = _probe(probe, _message, high - 1, _readBudget);
        assertFalse(ok);
        assertEq(result, abi.encodeWithSelector(Bridge.B_INSUFFICIENT_INVOCATION_GAS.selector));

        (ok, result) = _probe(probe, _message, high, _readBudget);
        assertTrue(ok);
        (IBridge.Status status, uint256 budget, uint256 balance) =
            abi.decode(result, (IBridge.Status, uint256, uint256));
        assertTrue(status == IBridge.Status.DONE);
        assertEq(balance, _message.value);
        if (_readBudget) {
            assertLe(budget, _expectedBudget);
            // Allow for the opcodes the recipient runs before GAS.
            assertGe(budget, _expectedBudget - 100);
        }
    }

    function _probeSucceeds(
        ProcessMessageProbe _probeContract,
        IBridge.Message memory _message,
        uint256 _gas,
        bool _readBudget
    )
        private
        returns (bool ok_)
    {
        (ok_,) = _probe(_probeContract, _message, _gas, _readBudget);
    }

    /// @return ok_ Whether processMessage succeeded.
    /// @return result_ The encoded outcome on success, or the processMessage revert data.
    function _probe(
        ProcessMessageProbe _probeContract,
        IBridge.Message memory _message,
        uint256 _gas,
        bool _readBudget
    )
        private
        returns (bool ok_, bytes memory result_)
    {
        try _probeContract.probe{ gas: 10_000_000 }(eBridge, _message, _gas, _readBudget) {
            revert("probe did not revert");
        } catch (bytes memory data) {
            bytes4 selector = bytes4(data);
            bytes memory payload = new bytes(data.length - 4);
            for (uint256 i; i < payload.length; ++i) {
                payload[i] = data[i + 4];
            }
            if (selector == ProcessMessageProbe.Processed.selector) return (true, payload);
            assertEq(selector, ProcessMessageProbe.Failed.selector);
            return (false, abi.decode(payload, (bytes)));
        }
    }

    /// @dev Processes an Ether delivery via a relayer with a bounded processing call.
    function _processValueMessage(address _recipient, uint256 _processGasLimit) private {
        IBridge.Message memory message = _l2ToL1Message(Alice, 2 ether);
        message.to = _recipient;
        message.gasLimit = eBridge.getMessageMinGasLimit(0) + _INVOCATION_GAS;

        vm.prank(Carol);
        (IBridge.Status status,) =
            eBridge.processMessage{ gas: _processGasLimit }(message, FAKE_PROOF);

        assertTrue(status == IBridge.Status.DONE);
        assertEq(_recipient.balance, message.value);
    }
}
