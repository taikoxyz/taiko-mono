// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library LibPreconfConstants {
    /// @dev The genesis timestamp of the mainnet beacon chain
    uint256 internal constant MAINNET_BEACON_GENESIS = 1_606_824_023;

    /// @dev The number of seconds in a slot
    uint256 internal constant SECONDS_IN_SLOT = 12;

    /// @dev The number of seconds in an epoch
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * 32;

    /// @dev The number of seconds in two epochs
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;

    /// @dev The dispute period in seconds
    uint256 internal constant DISPUTE_PERIOD = 2 * SECONDS_IN_EPOCH;
}
