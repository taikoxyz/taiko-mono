// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library LibSharedData {
    /// @dev Struct that represents L2 basefee configurations
    struct BaseFeeConfig {
        uint8 adjustmentQuotient;
        uint8 sharingPctg;
        uint32 gasIssuancePerSecond;
        uint64 minGasExcess;
        // Surge: switch from uint32 to uint64
        uint64 maxGasIssuancePerBlock;
    }
}
