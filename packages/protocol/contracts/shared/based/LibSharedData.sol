// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library LibSharedData {
    /// @dev Struct that represents L2 basefee configurations
    struct BaseFeeConfig {
        // This is the base fee change denominator per 12 second window.
        uint8 adjustmentQuotient;
        uint8 sharingPctg;
        uint32 gasIssuancePerSecond;
        uint64 minGasExcess;
        uint32 maxGasIssuancePerBlock;
    }
}
