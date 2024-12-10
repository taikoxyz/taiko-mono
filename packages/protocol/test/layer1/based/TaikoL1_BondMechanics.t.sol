// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoL1.sol";
import "./TaikoL1TestBase.sol";

contract TaikoL1Test_BondToken is TaikoL1TestBase {

    uint16 constant provingWindow = 1 hours;

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
            provingWindow: provingWindow,
            forkHeights: ITaikoL1.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_bonds_debit_and_credit_on_proposal_and_proof() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 initialBondBalance = 100000 ether;
        uint256 bondAmount = 1000 ether;

        bondToken.transfer(Alice, initialBondBalance);

        vm.prank(Alice);
        bondToken.approve(address(taikoL1), bondAmount);

        vm.prank(Alice);
        taikoL1.depositBond(bondAmount);

        // Propose blocks
        uint256 numBlocksToPropose = 1;
        ITaikoL1.BlockParamsV3[] memory blockParams =
            new ITaikoL1.BlockParamsV3[](numBlocksToPropose);
        vm.prank(Alice);
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams, "txList");
        
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
        assertEq(taikoL1.bondBalanceOf(Alice) < bondAmount, true);

        // Prove blocks
        uint64[] memory blockIds = new uint64[](numBlocksToPropose);
        for (uint256 i; i < blockIds.length; ++i) {
            blockIds[i] = metas[i].blockId;
        }

        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);
        for (uint256 i; i < blockIds.length; ++i) {
            ITaikoL1.BlockMetadataV3 memory meta = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        vm.prank(Alice);
        taikoL1.proveBlocksV3(metas, transitions, "proof");

        // Check if Alice's balance remains unaffected
        assertEq(taikoL1.bondBalanceOf(Alice), bondAmount);
    }

    function test_bonds_debited_on_proposal_not_credited_back_if_proved_after_deadline_1() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 initialBondBalance = 100000 ether;
        uint256 bondAmount = 1000 ether;

        bondToken.transfer(Alice, initialBondBalance);

        vm.prank(Alice);
        bondToken.approve(address(taikoL1), bondAmount);

        vm.prank(Alice);
        taikoL1.depositBond(bondAmount);

        // Propose blocks
        uint256 numBlocksToPropose = 1;
        ITaikoL1.BlockParamsV3[] memory blockParams =
            new ITaikoL1.BlockParamsV3[](numBlocksToPropose);
        vm.prank(Alice);
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams, "txList");
        
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
        uint256 aliceBondBalanceAfterProposal = taikoL1.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProposal < bondAmount, true);

        // Simulate waiting for a number of blocks
        uint256 secondsPerBlock = 12;
        uint256 blocksToWait = provingWindow / secondsPerBlock + 1;
        uint256 targetBlock = block.number + blocksToWait;
        uint256 targetTime = block.timestamp + (blocksToWait * secondsPerBlock);

        vm.roll(targetBlock);
        vm.warp(targetTime);

        // Prove blocks
        uint64[] memory blockIds = new uint64[](numBlocksToPropose);
        for (uint256 i; i < blockIds.length; ++i) {
            blockIds[i] = metas[i].blockId;
        }

        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);
        for (uint256 i; i < blockIds.length; ++i) {
            ITaikoL1.BlockMetadataV3 memory meta = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        vm.prank(Alice);
        taikoL1.proveBlocksV3(metas, transitions, "proof");

        // Check if Alice doesn't get credit back
        uint256 aliceBondBalanceAfterProof = taikoL1.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProof, aliceBondBalanceAfterProposal);
        assertEq(aliceBondBalanceAfterProof < bondAmount, true);
    }

    function test_bonds_debited_on_proposal_not_credited_back_if_proved_after_deadline() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 initialBondBalance = 100000 ether;
        uint256 bondAmount = 1000 ether;

        bondToken.transfer(Alice, initialBondBalance);

        vm.prank(Alice);
        bondToken.approve(address(taikoL1), bondAmount);

        vm.prank(Alice);
        taikoL1.depositBond(bondAmount);

        // Propose blocks
        uint256 numBlocksToPropose = 1;
        ITaikoL1.BlockParamsV3[] memory blockParams =
            new ITaikoL1.BlockParamsV3[](numBlocksToPropose);
        vm.prank(Alice);
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams, "txList");
        
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
        uint256 aliceBondBalanceAfterProposal = taikoL1.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProposal < bondAmount, true);

        // Simulate waiting for a number of blocks
        uint256 secondsPerBlock = 12;
        uint256 blocksToWait = provingWindow / secondsPerBlock;
        uint256 targetBlock = block.number + blocksToWait;
        uint256 targetTime = block.timestamp + (blocksToWait * secondsPerBlock);

        vm.roll(targetBlock);
        vm.warp(targetTime);

        // Prove blocks
        uint64[] memory blockIds = new uint64[](numBlocksToPropose);
        for (uint256 i; i < blockIds.length; ++i) {
            blockIds[i] = metas[i].blockId;
        }

        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);
        for (uint256 i; i < blockIds.length; ++i) {
            ITaikoL1.BlockMetadataV3 memory meta = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        vm.prank(Alice);
        taikoL1.proveBlocksV3(metas, transitions, "proof");

        // Check if Alice's balance remains unaffected
        assertEq(taikoL1.bondBalanceOf(Alice), bondAmount);
    }

}
