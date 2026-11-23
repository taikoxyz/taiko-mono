// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title EtnaTestConstants
/// @notice The deployment parameters shared by the Etna Inbox test base and the conformance suite.
abstract contract EtnaTestConstants {
    uint64 internal constant L2_CHAIN_ID = 167_001;

    /// @dev The L2 `EtnaStaking` proxy the genesis generator assigns to `L2_CHAIN_ID`:
    /// `getConstantAddress(167001, 10003)`.
    address internal constant ETNA_STAKING = 0x1670010000000000000000000000000000010003;

    /// @dev `U`, the maximum number of unsettled L2 blocks: the target deployment's 151,200.
    uint64 internal constant UNSETTLED_LIMIT = 151_200;
}
