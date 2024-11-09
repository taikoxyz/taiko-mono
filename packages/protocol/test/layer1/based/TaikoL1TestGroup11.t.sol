// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1Test.sol";

contract TaikoL10TestGroup11 is TaikoL1Test {
    function getConfig() internal view override returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: taikoChainId,
            blockMaxProposals: 20,
            blockRingBufferSize: 25,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18,
            stateRootSyncInternal: 2,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            ontakeForkHeight: 0 // or 1
         });
    }

    // Test summary:
    // 1. Zachary proposes a block with a custom proposer in the block parameters
    // 2. The proposal will revert as Zachary is not registered as the preconf task manager.
    function test_taikoL1_group_11_case_1() external {
        mineOneBlockAndWrap(1000 seconds);
        printBlockAndTrans(0);

        giveEthAndTko(Zachary, 10_000 ether, 1000 ether);

        tierProvider().getTier(minTierId);

        console2.log("====== Zachary proposes a block");

        TaikoData.BlockParamsV2 memory params;
        params.proposer = Alice;
        proposeBlock(Zachary, params, LibProposing.L1_INVALID_CUSTOM_PROPOSER.selector);
    }

    // Test summary:
    // 1. Zachary proposes a block with a Alice as the proposer
    // 2. Alice proves the block
    // 3. Alice verifies the block to get back her bonds.
    function test_taikoL1_group_11_case_2() external {
        vm.startPrank(deployer);
        register("preconf_task_manager", Zachary);
        vm.stopPrank();

        mineOneBlockAndWrap(1000 seconds);
        printBlockAndTrans(0);

        giveEthAndTko(Zachary, 10_000 ether, 1000 ether);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Zachary proposes a block with Alice as the proposer");

        TaikoData.BlockParamsV2 memory params;
        params.proposer = Alice;
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Zachary, params, "");

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);

        console2.log("====== Alice proves the block");
        // Prove the block
        bytes32 blockHash = bytes32(uint256(10_000));
        bytes32 stateRoot = bytes32(uint256(20_000));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, GENESIS_BLOCK_HASH, blockHash, stateRoot, meta.minTier, "");

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);

        printBlockAndTrans(meta.id);

        console2.log("====== Alice's block is verified");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether);
    }
}
