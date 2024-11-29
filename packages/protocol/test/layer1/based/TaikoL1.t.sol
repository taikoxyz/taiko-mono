// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";

contract TaikoL1Test is Layer1Test {
    ITaikoL1 internal taikoL1;
    mapping(uint256 => ITaikoL1.BlockMetadataV3) internal blockMetadatas;

    ITaikoL1.ConfigV3 internal config =   ITaikoL1.ConfigV3({
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
            pacayaForkHeight: 1,
            provingWindow: 1 hours
        });


    function setUpOnEthereum() internal override {
        taikoL1 = deployTaikoL1(_correctBlockhash(0), config);
        deployBondToken();
    }

    modifier WhenMultipleBlocksAreProposedWithDefaultParameters(uint256 count) {
        _proposeBlocksWithDefaultParameters(count);
        _;
    }


    function test_case_1() external WhenMultipleBlocksAreProposedWithDefaultParameters(9) {
        vm.expectRevert(ITaikoL1.TooManyBlocks.selector);
        _proposeBlocksWithDefaultParameters(1);
    }

    // internal helper functions -------------------------------------------------------------------

    function _proposeBlocksWithDefaultParameters(uint256 count) internal {
        ITaikoL1.BlockParamsV3[] memory blockParams = new ITaikoL1.BlockParamsV3[](count);

        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams);
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
    }

    function _correctBlockhash(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(100000 + blockId);
    }
}
