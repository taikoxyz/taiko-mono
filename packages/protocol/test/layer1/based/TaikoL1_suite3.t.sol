// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1Test_Suite3 is TaikoL1TestBase {
    function getConfig() internal pure override returns (ITaikoL1.ConfigV3 memory) {
        return ITaikoL1.ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 10,
            blockRingBufferSize: 15,
            minBlocksToVerify: 3,
            maxBlocksToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            pacayaForkHeight: 0,
            provingWindow: 1 hours
        });
    }

    function test_taikol1_min_blocks_to_verify_not1()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
    {
        _proveBlocksWithCorrectTransitions(range(1, 3));
        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.lastVerifiedBlockId, 0);

        _proveBlocksWithCorrectTransitions(range(3, 4));
        stats2 = taikoL1.getStats2();
        assertEq(stats2.lastVerifiedBlockId, 3);

        _proveBlocksWithCorrectTransitions(range(4, 8));
        stats2 = taikoL1.getStats2();
        assertEq(stats2.lastVerifiedBlockId, 7);

        _logAllBlocksAndTransitions();
    }
}
