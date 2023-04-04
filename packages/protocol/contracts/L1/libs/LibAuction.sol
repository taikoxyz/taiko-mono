// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibL1Tokenomics} from "./LibL1Tokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibAuction {
    // EVENTS
    event AuctionBid(
        uint256 batchId,
        address bidder,
        uint256 bidAt,
        uint256 deposit,
        uint256 minFeePerGas,
        uint256 weight,
        uint256 auctionStartedAt
    );

    // ERRORS

    error L1_AUCTION_BLOCKS_NOT_AVAILABLE();
    error L1_AUCTION_CLOSED_FOR_BATCH();
    error L1_INSUFFICIENT_WEIGHT(uint256 bidWeight, uint256 existingBidWeight);
    error L1_MAX_FEE_PER_GAS_EXCEEDED(uint256 maxFeePerGasAllowed);

    // bidForBatch allows a user to claim a batch of blocks for
    // exclusive proving rights. User's bid the "mininimum amount they will accept as a proving fee per gas",
    // and the lowest ones win.
    // blocks are bidded for in `N` batches, where `N` is the `auctionBlockBatchSize` in the config.
    // blocks are available for bidding before they are proposed, but only up to
    // state.lastVerifiedBlockId + auctionBlockGap.

    // TODO: add a way to cancel a bid?
    // TODO: if the state.lastVerifiedId is within a range of the blocks in this batch,
    // we should immediately close the auction and accept the first bid.
    // TODO: keep track of avgMinFeePerGas upon block being proven or verified?
    function bidForBatch(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 minFeePerGas,
        uint256 batchId
    ) internal {
        // can only auction for a certain number of blocks past
        // the last verifiedID.
        if (
            state.lastClaimedBlockId + config.auctionBlockBatchSize >
            state.lastVerifiedBlockId + config.auctionBlockGap
        ) {
            revert L1_AUCTION_BLOCKS_NOT_AVAILABLE();
        }

        if (minFeePerGas > config.maxFeePerGasForAuctionBid) {
            revert L1_MAX_FEE_PER_GAS_EXCEEDED(
                config.maxFeePerGasForAuctionBid
            );
        }

        // deposit is the auction bidders "how sure they are they will be able to prove the block"
        // a higher deposit ensures they are quite confident.

        if (!isAuctionOpen(config, state, batchId)) {
            revert L1_AUCTION_CLOSED_FOR_BATCH();
        }

        uint256 deposit = msg.value;
        uint256 weight = calculateBidWeight(deposit, minFeePerGas);
        uint256 existingBidWeight = state.blockAuctionBids[batchId].weight;

        if (weight < existingBidWeight) {
            revert L1_INSUFFICIENT_WEIGHT({
                bidWeight: weight,
                existingBidWeight: existingBidWeight
            });
        }

        TaikoData.Bid memory bid = state.blockAuctionBids[batchId];

        uint256 auctionStartedAt = bid.auctionStartedAt > 0
            ? bid.auctionStartedAt
            : block.timestamp;

        state.blockAuctionBids[batchId] = TaikoData.Bid({
            account: msg.sender,
            feePerGas: minFeePerGas,
            deposit: msg.value,
            weight: weight,
            auctionStartedAt: auctionStartedAt,
            batchId: batchId
        });

        emit AuctionBid({
            batchId: batchId,
            bidder: msg.sender,
            bidAt: block.timestamp,
            minFeePerGas: minFeePerGas,
            deposit: deposit,
            weight: weight,
            auctionStartedAt: auctionStartedAt
        });
    }

    // TODO: this is just placeholder weighting rn
    function calculateBidWeight(
        uint256 deposit,
        uint256 minFeePerGas
    ) internal pure returns (uint256) {
        uint256 depositWeight = 1e2;
        uint256 minFeePerGasWeight = 1e18;
        return
            (deposit * depositWeight) +
            (minFeePerGas * minFeePerGasWeight) /
            10000;
    }

    function isAuctionOpen(
        TaikoData.Config memory config,
        TaikoData.State storage state,
        uint256 batchId
    ) internal view returns (bool) {
        // auction is always open if there is no winner.
        if (state.blockAuctionBids[batchId].account == address(0)) return true;

        // if auctionLengthInSeconds hasnt passed, the auction is still open
        if (
            state.blockAuctionBids[batchId].auctionStartedAt +
                config.auctionLengthInSeconds >
            block.timestamp
        ) {
            return true;
        }
        // otherwise we have a winner!
        return false;
    }

    function isBlockIdInBatch(
        uint256 auctionBlockBatchSize,
        uint256 blockId,
        uint256 batchId
    ) internal pure returns (bool) {
        (
            uint256 startBlockId,
            uint256 endBlockId
        ) = startAndEndBlockIdsForBatch(auctionBlockBatchSize, batchId);
        return blockId >= startBlockId && blockId < endBlockId;
    }

    // inclusive of startBlock and endBlock
    function startAndEndBlockIdsForBatch(
        uint256 auctionBlockBatchSize,
        uint256 batchId
    ) internal pure returns (uint256 startBlockId, uint256 endBlockId) {
        return (
            batchId * auctionBlockBatchSize - auctionBlockBatchSize + 1,
            (batchId * auctionBlockBatchSize)
        );
    }

    function isAddressBlockAuctionWinner(
        TaikoData.State storage state,
        uint256 batchId,
        address addr
    ) internal view returns (bool) {
        return state.blockAuctionBids[batchId].account == addr;
    }
}
