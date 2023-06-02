// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibAuction {
    event Bid(uint64 indexed batchId, uint64 startedAt, TaikoData.Bid bid);

    error L1_AUCTION_ENDED();
    error L1_BID_NOT_GOOD_ENOUGH();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_BATCHID();
    error L1_INVALID_BID();

    function bidForBatch(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 batchId,
        TaikoData.Bid memory bid
    )
        internal
    {
        // check the bid is valid
        if (
            bid.prover != address(0) // auto fill
                || bid.blockMaxGasLimit != 0 // auto fill
                // the proof window cannot be too large
                || bid.proofWindow
                    > state.avgProofWindow * config.auctionProofWindowMultiplier
            // the feePerGas asked cannot be too large
            || bid.feePerGas
                > state.feePerGas * config.auctionMaxFeePerGasMultipler
            // the deposit cannot be too small
            || bid.deposit
                < state.feePerGas
                    * (config.blockFeeBaseGas + config.blockMaxGasLimit)
                    * config.auctionDepositMultipler
        ) {
            revert L1_INVALID_BID();
        }

        uint64 totalDeposit = bid.deposit * config.auctionBatchSize;
        if (state.taikoTokenBalances[msg.sender] < totalDeposit) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        bid.prover = msg.sender;
        bid.blockMaxGasLimit = config.blockMaxGasLimit;

        // Check the batch id is in the correct range
        uint256 batchForNextBlockToVerify =
            LibUtils.batchForBlock(config, state.lastVerifiedBlockId + 1);

        // TODO(daniel & dani): check >= vs >  AND <= vs <
        if (
            // the batch of lastVerifiedBlockId is never auctionable as it has
            // to be ended before the last verifeid block can be verified.
            batchId < batchForNextBlockToVerify
            // We cannot start a new auction if the previous one has not started
            || batchId > state.numAuctions + 1
            // We cannot start a new auction if we have to keep all the auctions
            // info in order to prove/verify blocks
            || batchId
                >= batchForNextBlockToVerify + config.auctionRingBufferSize
            // we do not want to auction more batches ahead of the last proposed
            // block's corresponding batch
            || batchId
                >= LibUtils.batchForBlock(config, state.numBlocks)
                    + config.auctonMaxAheadOfProposals
        ) {
            revert L1_INVALID_BATCHID();
        }

        // Check batch is auctionable
        TaikoData.Auction storage auction =
            state.auctions[batchId % config.auctionBatchSize];

        if (auction.batchId == batchId) {
            // this must be an existing auction
            if (block.timestamp > auction.startedAt + config.auctionWindow) {
                revert L1_AUCTION_ENDED();
            }

            if (!isBidBetter(config, bid, auction.bid)) {
                revert L1_BID_NOT_GOOD_ENOUGH();
            }

            state.taikoTokenBalances[auction.bid.prover] +=
                auction.bid.deposit * config.auctionBatchSize;
            state.taikoTokenBalances[bid.prover] -= totalDeposit;
        } else {
            // this is a new auction
            auction.batchId = uint64(batchId);
            auction.startedAt = uint64(block.timestamp);
            unchecked {
                state.numAuctions += 1;
            }

            state.taikoTokenBalances[bid.prover] -= totalDeposit;
        }

        auction.bid = bid;

        emit Bid(auction.batchId, auction.startedAt, bid);
    }

    function isBidBetter(
        TaikoData.Config memory config,
        TaikoData.Bid memory newBid,
        TaikoData.Bid memory oldBid
    )
        internal
        view
        returns (bool)
    {
        // TODO: implement this function by comparing
        // bid.deposit, bid.feePerGas, and bid.proofWindow
    }
}
