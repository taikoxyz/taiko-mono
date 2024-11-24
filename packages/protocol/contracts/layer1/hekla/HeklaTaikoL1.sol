// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoL1.sol";

/// @title HeklaTaikoL1
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract HeklaTaikoL1 is TaikoL1V3 {
    /// @inheritdoc ITaikoL1
    function getConfigV3() public pure override returns (TaikoData.ConfigV3 memory) {
        return TaikoData.ConfigV3({
            chainId: LibNetwork.TAIKO_HEKLA,
            // Never change this value as ring buffer is being reused!!!
            blockMaxProposals: 324_000,
            // Never change this value as ring buffer is being reused!!!
            blockRingBufferSize: 324_512,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000 // two minutes
             }),
            pacayaForkHeight: 840_512,
            provingWindow: 2 hours
        });
    }
}
