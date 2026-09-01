// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that records the gas budget its receive path is handed, so a test can pin
/// Bridge._SEND_ETHER_GAS_LIMIT directly instead of inferring it from how much work a receive
/// path can afford. `recordedBudget` is the CALL gas operand plus the 2,300 stipend a
/// value-bearing CALL always adds, less the few opcodes spent entering the frame. Unlike
/// gas-consumption fixtures this stays valid across gas-schedule changes such as EIP-8037,
/// because the forwarded allowance does not depend on how storage writes are priced.
/// `recordedBudget` is pre-initialised so the receive path updates an existing slot rather than
/// creating one. The constructor runs in the same transaction as the call under test, so by the
/// time the send arrives the slot is warm with `original = 0, current = 1`; writing it again is
/// a dirty-slot update billed at WARM_ACCESS (100) under both the current schedule and EIP-8038,
/// rather than a fresh-slot creation (22,100 today, 110,020 after Glamsterdam) charged inside
/// the gas-capped frame. Without it a cap too low to cover a slot creation would fail this test
/// with ETH_TRANSFER_FAILED instead of an assertion mismatch, reporting the wrong cause.
contract MessageReceiver_RecordingGasBudget {
    uint256 public recordedBudget = 1;

    receive() external payable {
        recordedBudget = gasleft();
    }
}
