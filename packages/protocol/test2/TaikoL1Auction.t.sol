// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.sol";
import {LibAuction} from "../contracts/L1/libs/LibAuction.sol";

contract TaikoL1WithConfig is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.enableTokenomics = true;
        config.bootstrapDiscountHalvingPeriod = 0;
        config.constantFeeRewardBlocks = 0;
        config.txListCacheExpiry = 5 minutes;
        config.proposerDepositPctg = 0;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        // this value must be changed if `maxNumProposedBlocks` is changed.
        config.slotSmoothingFactor = 4160;

        config.proposingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            dampingFactorBips: 5000
        });

        config.provingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            dampingFactorBips: 5000
        });

        config.auctionBlockBatchSize = 10;
        config.auctionBlockGap = 1000;
        config.auctionLengthInSeconds = 5 seconds;
        config.maxFeePerGasForAuctionBid = 1e18;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1AuctionTest is TaikoL1TestBase {
    struct BatchTest {
        uint256 batchId;
        uint256 expectedStartingBlockId;
        uint256 expectedEndingBlockId;
    }

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithConfig();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        vm.warp(conf.auctionLengthInSeconds * 10);
    }

    function test_start_and_end_block_ids_for_batch() external {
        BatchTest[7] memory tests = [
            BatchTest(1, 1, 10),
            BatchTest(2, 11, 20),
            BatchTest(3, 21, 30),
            BatchTest(9, 81, 90),
            BatchTest(10, 91, 100),
            BatchTest(11, 101, 110),
            BatchTest(21, 201, 210)
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            (uint256 start, uint256 end) = L1.startAndEndBlockIdsForBatch(
                tests[i].batchId
            );
            print(
                start,
                end,
                tests[i].expectedStartingBlockId,
                tests[i].expectedEndingBlockId
            );
            assertEq(start, tests[i].expectedStartingBlockId);
            assertEq(end, tests[i].expectedEndingBlockId);
        }
    }

    function test_is_auction_open_returns_true_if_no_bids() external {
        assertEq(L1.isAuctionOpen(1), true);
    }

    function test_is_auction_open_returns_true_if_bid_but_auction_length_hasnt_passed()
        external
    {
        uint256 batchId = 1;
        uint256 minFeePerGas = 1;
        bidForBatch(Alice, minFeePerGas, batchId);
        vm.warp(block.timestamp - conf.auctionLengthInSeconds + 1);
        assertEq(L1.isAuctionOpen(batchId), true);
    }

    function test_is_auction_open_returns_false_if_bid_but_auction_length_has_passed()
        external
    {
        uint256 batchId = 1;
        uint256 minFeePerGas = 1;
        bidForBatch(Alice, minFeePerGas, batchId);
        vm.warp(block.timestamp + conf.auctionLengthInSeconds + 1);
        assertEq(L1.isAuctionOpen(batchId), false);
    }

    function test_get_current_winning_bid_for_batch_no_bids() external {
        TaikoData.Bid memory bid = L1.getCurrentWinningBidForBatch(1);
        assertEq(bid.account, address(0));
        assertEq(bid.feePerGas, uint256(0));
        assertEq(bid.deposit, uint256(0));
        assertEq(bid.weight, uint256(0));
        assertEq(bid.auctionStartedAt, uint256(0));
        assertEq(bid.batchId, uint256(0));
    }

    function test_get_current_winning_bid_for_batch_existing_bid() external {
        uint256 batchId = 1;
        vm.warp(1234);
        bidForBatch(Alice, 1, batchId);
        TaikoData.Bid memory bid = L1.getCurrentWinningBidForBatch(batchId);
        assertEq(bid.account, Alice);
        assertEq(bid.feePerGas, uint256(1));
        assertEq(bid.deposit, uint256(0));
        assertEq(bid.weight, uint256(100000000000000));
        assertEq(bid.auctionStartedAt, uint256(1234));
        assertEq(bid.batchId, uint256(1));
    }

    function test_bid_for_batch_second_higher_bid_wins() external {
        uint256 batchId = 1;
        bidForBatch(Alice, 1, batchId);
        bidForBatch(Bob, 2, batchId);
        TaikoData.Bid memory bid = L1.getCurrentWinningBidForBatch(batchId);
        assertEq(bid.account, Bob);
        assertEq(bid.feePerGas, uint256(2));
    }

    function test_bid_for_batch_revert_max_fee_per_gas_exceeded() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibAuction.L1_MAX_FEE_PER_GAS_EXCEEDED.selector,
                conf.maxFeePerGasForAuctionBid
            )
        );
        bidForBatch(Alice, conf.maxFeePerGasForAuctionBid + 1, 1);
    }

    function test_bid_for_batch_auction_closed() external {
        bidForBatch(Alice, 1, 1);

        vm.warp(block.timestamp + conf.auctionLengthInSeconds + 10000000);
        vm.expectRevert(LibAuction.L1_AUCTION_CLOSED_FOR_BATCH.selector);
        bidForBatch(Bob, 2, 1);
    }

    function print(
        uint256 startBlockId,
        uint256 endBlockId,
        uint256 expectedStartBlockId,
        uint256 expectedEndBlockId
    ) internal {
        string memory str = string.concat(
            Strings.toString(logCount++),
            " startBlockId:",
            Strings.toString(startBlockId),
            " expectedStartBlockId:",
            Strings.toString(expectedStartBlockId),
            " endBlockId:",
            Strings.toString(endBlockId),
            " expectedWantBlockId:",
            Strings.toString(expectedEndBlockId)
        );
        console2.log(str);
    }
}
