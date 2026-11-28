// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Models a wallet that initializes its receive counter and performs additional execution
/// work. The first receive creates exactly one slot. With 20,000 gas of work, it exceeds the
/// legacy 35,000 gas operand plus stipend on Osaka and fits the current cap even when Amsterdam
/// charges the full 110,020 gas for the slot from the recipient frame.
contract MessageReceiver_CreatingFreshStorageSlot {
    uint256 private immutable _executionGas;
    uint256 public receiveCount;

    event ReceiveStorageGas(uint256 gasUsed);

    constructor(uint256 _gasForWork) {
        _executionGas = _gasForWork;
    }

    receive() external payable {
        uint256 gasBeforeWrite = gasleft();
        ++receiveCount;
        emit ReceiveStorageGas(gasBeforeWrite - gasleft());

        // Use execution gas for this work so its cost is independent of state-gas accounting.
        uint256 gasStart = gasleft();
        while (gasStart - gasleft() < _executionGas) { }
    }
}
