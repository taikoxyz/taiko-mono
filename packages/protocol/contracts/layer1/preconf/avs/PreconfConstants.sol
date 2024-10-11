// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library PreconfConstants {
    uint256 internal constant MAINNET_BEACON_GENESIS = 1_606_824_023;
    uint256 internal constant SECONDS_IN_SLOT = 12;
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * 32;
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;
    uint256 internal constant DISPUTE_PERIOD = 2 * SECONDS_IN_EPOCH;
}
