// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev A recipient that creates `numSlots` fresh storage slots every time it receives Ether,
/// mimicking a smart wallet whose receive path performs bookkeeping writes. Under the current
/// gas schedule each fresh slot costs 22,100 gas; after Glamsterdam it costs 110,020 — the
/// 2,100 cold-access charge, EIP-8038's 10,000 STORAGE_WRITE, and EIP-8037's 97,920 of state
/// gas. The `receiveCount` slot itself is an extra fresh slot on the first receive and a warm
/// rewrite afterwards, so a first receive creates `numSlots + 1` fresh slots.
/// NOTE: the slot counts used by tests are calibrated to the pre-Glamsterdam schedule. Every
/// test that exercises Bridge._SEND_ETHER_GAS_LIMIT with this fixture drives a *first* receive,
/// so if the test EVM ever adopts Glamsterdam pricing the count rule would be uniform: pass-side
/// counts become 0 (the counter slot alone is then the one fresh slot) and fail-side counts
/// become 1 (two fresh slots, 220,140 gas, above the cap). Changing the counts is NOT sufficient
/// on its own. EIP-8037 splits transaction gas above the 16.7M execution cap into a state-gas
/// reservoir, and state charges draw from that reservoir before they reach the callee frame;
/// foundry.toml sets gas_limit to u64::MAX, so the 97,920 would be absorbed there and never
/// bite the budget under test. Recalibrating therefore also needs a profile whose transaction
/// gas limit leaves the reservoir empty. The gas-budget pin test in Bridge2_processMessage.t.sol
/// sidesteps all of this: it measures the forwarded allowance, not the gas a receive path
/// consumes.
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
