// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBridge, TestBridge2Base } from "./TestBridge2Base.sol";
import {
    MessageReceiver_RecordingGasBudget
} from "./helpers/MessageReceiver_RecordingGasBudget.sol";

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
