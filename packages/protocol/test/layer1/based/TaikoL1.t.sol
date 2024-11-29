// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";

contract TaikoL1Test is Layer1Test {
    mapping(uint256 => ITaikoL1.BlockMetadataV3) internal blockMetadatas;
    ITaikoL1 internal taikoL1;
    TaikoToken internal bondToken;
    SignalService internal signalService;

    ITaikoL1.ConfigV3 internal config = ITaikoL1.ConfigV3({
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

    modifier transactBy(address transactor) override {
        vm.deal(transactor, 100 ether);
        bondToken.transfer(transactor, 10_000 ether);
        vm.startPrank(transactor);
        bondToken.approve(address(taikoL1), type(uint256).max);

        _;
        vm.stopPrank();
    }

    function setUpOnEthereum() internal override {
        taikoL1 = deployTaikoL1(_correctBlockhash(0), config);
        bondToken = deployBondToken();
        signalService = deploySignalService(address(new SignalService()));
        signalService.authorize(address(taikoL1), true);

        mineOneBlockAndWrap(12 seconds);
    }

    modifier WhenMultipleBlocksAreProposedWithDefaultParameters(uint256 numBlocksToPropose) {
        _proposeBlocksWithDefaultParameters(numBlocksToPropose);
        _;
    }

    function test_case_1()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
    {
        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 10);
        assertEq(stats2.lastVerifiedBlockId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        vm.expectRevert(ITaikoL1.TooManyBlocks.selector);
        _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
    }

    // internal helper functions -------------------------------------------------------------------

    function _proposeBlocksWithDefaultParameters(uint256 numBlocksToPropose) internal {
        ITaikoL1.BlockParamsV3[] memory blockParams =
            new ITaikoL1.BlockParamsV3[](numBlocksToPropose);

        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams);
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
    }

    function _correctBlockhash(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(100_000 + blockId);
    }

    function mintEther(address to, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        console2.log("Ether balance:", to, to.balance);
    }

    function mintTaikoToken(address to, uint256 amountTko) internal {
        bondToken.transfer(to, amountTko);

        vm.prank(to);
        bondToken.approve(address(taikoL1), amountTko);

        console2.log("Bond balance :", to, bondToken.balanceOf(to));
    }
}
