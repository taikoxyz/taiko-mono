// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../based/TaikoL1.sol";

/// @title PreconfsTaikoL1
/// @custom:security-contact security@taiko.xyz
contract PreconfsTaikoL1 is TaikoL1 {
    /// @inheritdoc ITaikoL1
    function getConfig() public pure override returns (TaikoData.Config memory _config_) {
        return TaikoData.Config({
            chainId: 167_010,
            blockMaxProposals: 324_000,
            blockRingBufferSize: 360_000,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 TAIKO token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 0,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000
            }),
            ontakeForkHeight: 0
        });
    }
}
