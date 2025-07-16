// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ITaikoInbox } from "src/layer1/based/ITaikoInbox.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { LibSharedData } from "src/shared/based/LibSharedData.sol";

/// @title InboxTestConfigUtils
/// @notice Shared utility library for TaikoInbox test configurations
library InboxTestConfigUtils {
    /// @notice Returns the default V4 configuration for TaikoInbox testing
    /// @return config The default inbox test configuration
    function getV4Config() internal pure returns (ITaikoInbox.Config memory config) {
        ITaikoInbox.ForkHeights memory forkHeights;

        config = ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token per batch
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }
}
