// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/IForcedInclusionInbox.sol";
import "./ForcedInclusionInboxTestBase.sol";

contract ForcedInclusionInboxTest is ForcedInclusionInboxTestBase {
    function getConfig() internal pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 5e18, // 5 Taiko token per block
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
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }
}
