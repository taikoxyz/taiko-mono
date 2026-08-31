// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that records the gas budget its receive path is handed, so a test can pin
/// Bridge._SEND_ETHER_GAS_LIMIT directly instead of inferring it from how much work a receive
/// path can afford. `recordedBudget` is the CALL gas operand plus the 2,300 stipend a
/// value-bearing CALL always adds, less the few opcodes spent entering the frame. Unlike
/// gas-consumption fixtures this stays valid across gas-schedule changes such as EIP-8037,
/// because the forwarded allowance does not depend on how storage writes are priced.
/// `recordedBudget` is pre-initialised so its write is an existing-slot update rather than a
/// slot creation. That keeps the recorded value identical today while ensuring that after
/// Glamsterdam the write costs 12,100 rather than 110,020 — otherwise a future cap below
/// ~112,000 would fail this test with ETH_TRANSFER_FAILED instead of an assertion mismatch,
/// reporting the wrong cause.
contract MessageReceiver_RecordingGasBudget {
    uint256 public recordedBudget = 1;

    receive() external payable {
        recordedBudget = gasleft();
    }
}
