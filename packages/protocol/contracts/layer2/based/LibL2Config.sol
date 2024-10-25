// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev DEPRECATED but used by node/client for syncing old blocks
/// @title LibL2Config
library LibL2Config {
    struct Config {
        /// @dev Target gas per L1 block
        uint32 gasTargetPerL1Block;
        /// @dev Base fee adjustment quotient
        uint8 basefeeAdjustmentQuotient;
    }

    /// @dev Returns EIP1559 related configurations.
    /// @return config_ struct containing configuration parameters.
    function get() internal pure returns (Config memory config_) {
        // Assuming we sell 3x more blockspace than Ethereum: 15_000_000 * 4
        // Note that Brecht's concern is that this value may be too large.
        // We need to monitor L2 state growth and lower this value when necessary.
        config_.gasTargetPerL1Block = 60_000_000;
        config_.basefeeAdjustmentQuotient = 8;
    }
}
