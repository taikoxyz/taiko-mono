// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoInbox.sol";

/// @title DevnetInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract DevnetInbox is TaikoInbox {
    constructor(address _resolver) TaikoInbox(_resolver) { }

    /// @inheritdoc ITaikoInbox
    function pacayaConfig() public pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: 167_010,
            maxUnverifiedBatches: 324_000,
            batchRingBufferSize: 360_000,
            maxBatchesToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 5e18, // 5 Taiko token per block
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
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }
}
