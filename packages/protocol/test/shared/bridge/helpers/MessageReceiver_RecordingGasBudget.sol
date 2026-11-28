// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Records the gas available at the start of a payout or invocation. `recordedBudget` is
/// the forwarded gas minus entry opcodes, plus the 2,300 stipend for a value-bearing CALL.
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

    fallback() external {
        recordedBudget = gasleft();
    }
}
