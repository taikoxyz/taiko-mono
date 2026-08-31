// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that records the gas budget its receive path is handed, so a test can pin
/// Bridge._SEND_ETHER_GAS_LIMIT directly instead of inferring it from how much work a receive
/// path can afford. `recordedBudget` is the CALL gas operand plus the 2,300 stipend a
/// value-bearing CALL always adds, less the few opcodes spent entering the frame. Unlike
/// gas-consumption fixtures this stays valid across gas-schedule changes such as EIP-8037,
/// because the forwarded allowance does not depend on how storage writes are priced.
contract MessageReceiver_RecordingGasBudget {
    uint256 public recordedBudget;

    receive() external payable {
        recordedBudget = gasleft();
    }
}
