// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that creates `numSlots` fresh storage slots every time it receives Ether,
/// mimicking a smart wallet whose receive path performs bookkeeping writes. Under the current
/// gas schedule each fresh slot costs 22,100 gas; under EIP-8037 (Glamsterdam) a single fresh
/// slot costs 97,920 gas, so 4-5 fresh slots today approximate the gas a one-slot wallet will
/// need after the fork. The `receiveCount` slot itself is an extra fresh slot on the first
/// receive and a warm rewrite afterwards.
contract MessageReceiver_CreatingFreshStorageSlots {
    uint256 public immutable numSlots;
    uint256 public receiveCount;
    mapping(uint256 slot => uint256 value) public ledger;

    constructor(uint256 _numSlots) {
        numSlots = _numSlots;
    }

    receive() external payable {
        unchecked {
            uint256 base = receiveCount * numSlots;
            for (uint256 i; i < numSlots; ++i) {
                ledger[base + i] = msg.value + i + 1;
            }
            receiveCount += 1;
        }
    }
}
