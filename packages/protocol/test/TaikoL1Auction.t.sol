// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibEthDepositing } from "../contracts/L1/libs/LibEthDepositing.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { TaikoErrors } from "../contracts/L1/TaikoErrors.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.t.sol";

contract TaikoL1_Auction is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.maxNumProposedBlocks = 10;
        config.blockRingBufferSize = 12;
        config.proofCooldownPeriod = 0;
        config.auctionBatchSize = 100;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Test is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1_Auction();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();

        registerAddress(L1.getVerifierName(100), address(new Verifier()));
    }

    /// @dev Test base functionality if everything within boundaries
    function test_bidForBatch_successfully() external {
        depositTaikoToken(Alice, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e8 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e8 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        TaikoData.Bid memory bid;

        uint64 batchId = 1;
        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // Submit an auction and wait till won
            bid.proofWindow = 10 minutes;
            bid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            bid.feePerGas = 9;
            // Make a valid bid
            if (
                blockId == 1
                    || blockId % conf.auctionBatchSize == (conf.auctionWindow)
            ) {
                bidForBatchAndRollTime(Bob, batchId, bid);
                batchId++;
            }

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Carol, 1);
            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test auctioning for multiple batches
    function test_bidForBatch_multiple_batches() external {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        TaikoData.Bid memory bid;

        uint64 batchId = 1;

        for (
            uint256 blockId = 1; blockId <= conf.auctionBatchSize * 2; blockId++
        ) {
            printVariables("");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Submit an auction and wait till won
            bid.proofWindow = 10 minutes;
            bid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            bid.feePerGas = 9;
            TaikoData.Auction[] memory auctions;

            // Make valid batch bids - 3 in a row
            if (blockId == 1) {
                for (uint256 index = 0; index < 3; index++) {
                    // Batch for 3 batches
                    bidForBatch(Bob, batchId, bid);
                    // Roll one time ahead in future and bid another one
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 12);
                    batchId++;
                }

                // Then roll into the future to be proveable
                (, auctions) = L1.getAuctions(1, 3);
                vm.warp(
                    block.timestamp + auctions[0].startedAt + conf.auctionWindow
                        + 1
                );
                vm.roll(block.number + 100);
            }

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Alice, 2);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test auctioning for multiple bids and bids
    function test_bidForBatch_multiple_bids() external {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether); // Not the best bid
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether); // She will be the
            // winner

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        TaikoData.Bid memory bid;
        TaikoData.Bid memory winningBid;

        uint64 batchId = 1;

        for (uint256 blockId = 1; blockId <= conf.auctionBatchSize; blockId++) {
            printVariables("");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Submit an auction and wait till won
            bid.proofWindow = 10 minutes;
            bid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            bid.feePerGas = 9;

            // Winning bid parameters
            winningBid.proofWindow = 7 minutes;
            winningBid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            winningBid.feePerGas = 9;

            TaikoData.Auction[] memory auctions;

            if (blockId == 1) {
                // Batch bid
                bidForBatch(Bob, batchId, bid);
                // Roll one time ahead in future and bid another one
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 12);

                // Revert batch bid
                vm.expectRevert(TaikoErrors.L1_NOT_BETTER_BID.selector);
                bidForBatch(Alice, batchId, bid);
                // Roll one time ahead in future and bid another one
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 12);

                // Winning batch bid
                bidForBatch(Carol, batchId, winningBid);
                // Roll one time ahead in future and bid another one
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 12);

                batchId++;

                // Then roll into the future to be proveable
                (, auctions) = L1.getAuctions(1, 3);
                vm.warp(
                    block.timestamp + auctions[0].startedAt + conf.auctionWindow
                        + 1
                );
                vm.roll(block.number + 100);
            }

            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Alice, 2);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test auctioning for multiple bids and bids
    function test_bidForBatch_but_non_winning_prover_cannot_prove_within_window(
    )
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether); // Not the best bid
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether); // She will be the
            // winner

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        TaikoData.Bid memory bid;

        uint64 batchId = 1;

        for (uint256 blockId = 1; blockId <= conf.auctionBatchSize; blockId++) {
            printVariables("");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Submit an auction and wait till won
            bid.proofWindow = 10 minutes;
            bid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            bid.feePerGas = 9;

            TaikoData.Auction[] memory auctions;

            if (blockId == 1) {
                // Batch bid
                bidForBatch(Bob, batchId, bid);
                // Roll one time ahead in future and bid another one
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 12);

                batchId++;

                // Then roll into the future to be proveable
                (, auctions) = L1.getAuctions(1, 3);
                vm.warp(
                    block.timestamp + auctions[0].startedAt + conf.auctionWindow
                        + 1
                );
                vm.roll(block.number + 100);
            }

            vm.expectRevert(TaikoErrors.L1_NOT_PROVEABLE.selector);
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Alice, 2);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test auctioning for multiple bids and bids
    function test_bidForBatch_but_non_winning_prover_can_prove_outside_window()
        external
    {
        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether); // Not the best bid
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether); // She will be the
            // winner

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;
        TaikoData.Bid memory bid;

        uint64 batchId = 1;

        for (uint256 blockId = 1; blockId <= conf.auctionBatchSize; blockId++) {
            printVariables("");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Submit an auction and wait till won
            bid.proofWindow = 10 minutes;
            bid.deposit = L1.getBlockFee(uint32(conf.blockMaxGasLimit))
                * conf.auctionDepositMultipler;
            bid.feePerGas = 9;

            TaikoData.Auction[] memory auctions;

            if (blockId == 1) {
                // Batch bid
                bidForBatch(Bob, batchId, bid);
                // Roll one time ahead in future and bid another one
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 12);

                batchId++;

                // Then roll into the future to be proveable
                (, auctions) = L1.getAuctions(1, 3);
                vm.warp(
                    block.timestamp + auctions[0].startedAt + conf.auctionWindow
                        + auctions[0].bid.proofWindow
                );
                vm.roll(block.number + 100);
            }

            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            verifyBlock(Alice, 2);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }
}
