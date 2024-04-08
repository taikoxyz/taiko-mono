// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibSignals
/// @custom:security-contact security@taiko.xyz
library LibSignals {
    /// @notice Keccak hash of the string "STATE_ROOT".
    bytes32 internal constant HASH_STR_STATE_ROOT = keccak256("STATE_ROOT");

    /// @notice Keccak hash of the string "SIGNAL_ROOT".
    bytes32 internal constant HASH_STR_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");

    /// @notice Constant string "SIGNAL".
    string internal constant STR_SIGNAL = "SIGNAL";
}
