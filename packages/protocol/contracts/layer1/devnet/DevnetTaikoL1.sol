// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoL1.sol";

/// @title DevnetTaikoL1
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract DevnetTaikoL1 is TaikoL1 {
    /// @inheritdoc ITaikoL1
    function getConfigV3() public pure override returns (ITaikoL1.ConfigV3 memory) {
        return ITaikoL1.ConfigV3({
            chainId: 167_001,
            blockMaxProposals: 324_000,
            blockRingBufferSize: 360_000,
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
                maxGasIssuancePerBlock: 600_000_000
            }),
            provingWindow: 2 hours,
            emitTxListInCalldata: true,
            forkHeights: ITaikoL1.ForkHeights({
                ontake: 0,
                pacaya: 0 // TODO
             })
        });
    }
}
