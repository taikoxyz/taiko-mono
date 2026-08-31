// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that creates `numSlots` fresh storage slots every time it receives Ether,
/// mimicking a smart wallet whose receive path performs bookkeeping writes. Under the current
/// gas schedule each fresh slot costs 22,100 gas; under EIP-8037 (Glamsterdam) it costs 97,920
/// of state gas plus the surviving 2,100 cold-access charge. The `receiveCount` slot itself is
/// an extra fresh slot on the first receive and a warm rewrite afterwards, so a first receive
/// creates `numSlots + 1` fresh slots.
/// NOTE: the slot counts used by tests are calibrated to the pre-Glamsterdam schedule. Every
/// test that exercises Bridge._SEND_ETHER_GAS_LIMIT with this fixture drives a *first* receive,
/// so if the test EVM ever adopts EIP-8037 pricing the rule is uniform: pass-side counts become
/// 0 (the counter slot alone is then the one fresh slot) and fail-side counts become 1 (two
/// fresh slots, 200,040 gas, still above the cap). This is not a proportional rescaling of
/// today's counts — the counter slot is why the pass-side goes to 0 rather than 1. The
/// gas-budget pin test in Bridge2_processMessage.t.sol needs no recalibration at all: it
/// measures the forwarded allowance, not the gas a receive path consumes.
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
