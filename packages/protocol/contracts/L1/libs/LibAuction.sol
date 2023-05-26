// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibAuction {
    // EVENTS
    event Bid(
        uint256 batchId,
        address bidder,
        uint256 deposit,
        uint256 feePerGasInWei,
        uint256 auctionStartedAt
    );

    // ERRORS

    error L1_AUCTION_BLOCKS_NOT_AVAILABLE();
    error L1_AUCTION_CLOSED_FOR_BATCH();
    error L1_MAX_FEE_PER_GAS_EXCEEDED(uint256 maxFeePerGasAllowed);
    error L1_TRANSFER_FROM_FAILED();
    error L1_INVALID_BID();

    // bidForBatch allows a user to claim a batch of blocks for
    // exclusive proving rights. User's bid the "mininimum amount they will accept as a proving fee per gas",
    // and the lowest ones win.
    // blocks are bidded for in `N` batches, where `N` is the `auctionBlockBatchSize` in the config.
    // blocks are available for bidding before they are proposed, but only up to
    // state.lastVerifiedBlockId + auctionBlockGap.
    function bidForBatch(
        AddressResolver resolver,
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 feePerGasInWei,
        uint256 batchId
    ) internal {
        // can only auction for a certain number of blocks past
        // the last verifiedID.
        uint256 firstBatch = (state.lastVerifiedBlockId << 8) + 1;
        uint256 lastBatch = firstBatch + config.auctionBatchGap;
        require(batchId >= firstBatch && batchId <= lastBatch, "not available");

        if (feePerGasInWei <= state.avgSuccessfulBidFeePerGas * 10) {
            revert L1_MAX_FEE_PER_GAS_EXCEEDED(state.avgSuccessfulBidFeePerGas * 10);
        }

        // deposit is the auction bidders "how sure they are they will be able to prove the block"
        // a higher deposit ensures they are quite confident.

        if (!isAuctionOpen(config, state, batchId)) {
            revert L1_AUCTION_CLOSED_FOR_BATCH();
        }

        TaikoData.Bid memory bid = state.bids[batchId];

        uint256 deposit = calculateRequiredDeposit(config, feePerGasInWei);

        TaikoToken tkoToken = TaikoToken(resolver.resolve("taiko_token", false));

        if (bid.bidder != address(0)) {
            if (!isValidBid(config, bid, feePerGasInWei)) {
                revert L1_INVALID_BID();
            }
            // refund deposit if there is an existing bid
            try tkoToken.transfer(bid.bidder, bid.deposit) {}
            catch {
                // allow to fail in case they have a bad onTokenReceived
            }
        }

        if (!tkoToken.transferFrom(msg.sender, address(this), deposit)) {
            revert L1_TRANSFER_FROM_FAILED();
        }

        uint256 auctionStartedAt = bid.auctionStartedAt > 0 ? bid.auctionStartedAt : block.timestamp;

        state.bids[batchId] = TaikoData.Bid({
            bidder: msg.sender,
            feePerGasInWei: feePerGasInWei,
            deposit: deposit,
            auctionStartedAt: auctionStartedAt,
            batchId: batchId
        });

        emit Bid({
            batchId: batchId,
            bidder: msg.sender,
            feePerGasInWei: feePerGasInWei,
            deposit: deposit,
            auctionStartedAt: auctionStartedAt
        });
    }

    // isValidBid determines if a bid is 5% less than an existing bid.
    function isValidBid(
        TaikoData.Config memory config,
        TaikoData.Bid memory currentBid,
        uint256 feePerGasInWei
    ) internal pure returns (bool) {
        return true;
    }

    function calculateRequiredDeposit(TaikoData.Config memory config, uint256 feePerGasInWei)
        internal
        pure
        returns (uint256)
    {
        // todo: should multiple by 1.5, not 2
        return feePerGasInWei * config.blockMaxGasLimit * config.auctionBlockBatchSize * uint256(2);
    }

    function isAuctionOpen(
        TaikoData.Config memory config,
        TaikoData.State storage state,
        uint256 batchId
    ) internal view returns (bool) {
        // auction is always open if there is no winner.
        if (state.bids[batchId].bidder == address(0)) return true;

        // if auctionLengthInSeconds hasnt passed, the auction is still open
        if (state.bids[batchId].auctionStartedAt + config.auctionLengthInSeconds > block.timestamp)
        {
            return true;
        }
        // otherwise we have a winner!
        return false;
    }

    function isBlockIdInBatch(uint256 auctionBlockBatchSize, uint256 blockId, uint256 batchId)
        internal
        pure
        returns (bool)
    {
        (uint256 startBlockId, uint256 endBlockId) =
            startAndEndBlockIdsForBatch(auctionBlockBatchSize, batchId);
        return blockId >= startBlockId && blockId < endBlockId;
    }

    // inclusive of startBlock and endBlock
    function startAndEndBlockIdsForBatch(uint256 auctionBlockBatchSize, uint256 batchId)
        internal
        pure
        returns (uint256 startBlockId, uint256 endBlockId)
    {
        return (
            batchId * auctionBlockBatchSize - auctionBlockBatchSize + 1,
            (batchId * auctionBlockBatchSize)
        );
    }

    function batchIdForBlockId(TaikoData.State storage state, uint256 blockId)
        internal
        pure
        returns (uint256)
    {}

    function isAddressWinnerOfBlockId(
        TaikoData.Config memory config,
        TaikoData.State storage state,
        uint256 blockId,
        address addr
    ) internal pure returns (bool) {}

    function isAddressBlockAuctionCurrentWinner(
        TaikoData.State storage state,
        uint256 batchId,
        address addr
    ) internal view returns (bool) {
        return state.bids[batchId].bidder == addr;
    }
}
