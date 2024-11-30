// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1Test_Suite2 is TaikoL1TestBase {
    function getConfig() internal pure override returns (ITaikoL1.ConfigV3 memory) {
        return ITaikoL1.ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 10,
            blockRingBufferSize: 15,
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

    function test_taikol1_measure_gas_used()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBlocksAndTransitions
    {
        uint64 count = 1;

        vm.startSnapshotGas("proposeBlocksV3");
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), new ITaikoL1.BlockParamsV3[](count));
        uint256 gasProposeBlocksV3 = vm.stopSnapshotGas("proposeBlocksV3");
        console2.log("Gas per block - proposing:", gasProposeBlocksV3 / count);

        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](count);
        for (uint256 i; i < metas.length; ++i) {
            transitions[i].parentHash = correctBlockhash(metas[i].blockId - 1);
            transitions[i].blockHash = correctBlockhash(metas[i].blockId);
            transitions[i].stateRoot = correctStateRoot(metas[i].blockId);
        }

        vm.startSnapshotGas("proveBlocksV3");
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        uint256 gasProveBlocksV3 = vm.stopSnapshotGas("proveBlocksV3");
        console2.log("Gas per block - proving:", gasProveBlocksV3 / count);
        console2.log("Gas per block - total:", (gasProposeBlocksV3 + gasProveBlocksV3) / count);

        _logAllBlocksAndTransitions();
    }
}
