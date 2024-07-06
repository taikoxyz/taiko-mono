// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibL2Config
library LibL2Config {
    struct Config {
        uint32 gasTargetPerL1Block;
        uint8 basefeeAdjustmentQuotient;
        uint64 ontakeForkHeight;
        uint16 l1BaseFeeContibution;
        uint16 l1BlobBaseFeeContibution;
    }

    /// @notice Returns EIP1559 related configurations.
    /// @return config_ struct containing configuration parameters.
    function get() internal pure returns (Config memory config_) {
        // Assuming we sell 3x more blockspace than Ethereum: 15_000_000 * 4
        // Note that Brecht's concern is that this value may be too large.
        // We need to monitor L2 state growth and lower this value when necessary.
        config_.gasTargetPerL1Block = 60_000_000;
        config_.basefeeAdjustmentQuotient = 8;
        config_.ontakeForkHeight = 500_000;
        config_.l1BaseFeeContibution = 200;
        config_.l1BlobBaseFeeContibution = 200;
    }
}
