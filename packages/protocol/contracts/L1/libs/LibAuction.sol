// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibAuction {
    using LibAddress for address;

    event Bid(
        uint256 indexed id,
        address claimer,
        uint256 claimedAt,
        uint256 deposit,
        uint256 minFeePerGasInWei
    );

    event BidDepositRefunded(
        uint256 indexed batchStartId, address claimer, uint256 refundedAt, uint256 refund
    );

    error L1_BLOCK_ID();
    error L1_BID_AUCTION_CLOSED();
    error L1_BID_NOT_ACCEPTABLE();
    error L1_ID_NOT_START_OF_A_BATCH();

    function bidForBatch(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Config memory config,
        uint256 batchStartBlockId,
        uint256 minFeePerGasInWei
    ) internal {
        // If it verified already -> Revert, otherwise it would be possible
        // to bid for future (unproposed) blocks - tho risky given the unknown costs yet.
        if (batchStartBlockId <= state.lastVerifiedBlockId) {
            revert L1_BLOCK_ID();
        }

        // We also need to be sure, that the blockId here is indeed a start blockId
        if (batchStartBlockId != getBatchStartBlockId(config, batchStartBlockId)) {
            revert L1_ID_NOT_START_OF_A_BATCH();
        }

        TaikoData.Bid memory currentBid = state.bids[batchStartBlockId];

        // if a current bid exists, and the delay after the current bid exists
        // has passed, bidding is over.
        if (!isBiddingOpenForBlock(config, currentBid)) {
            revert L1_BID_AUCTION_CLOSED();
        }

        TaikoToken tkoToken = TaikoToken(resolver.resolve("tko_token", false));

        // If there is an existing bid already
        // we compare this bid to the existing one first, to see if its a
        // lower fee accepted.
        if (currentBid.bidder != address(0)) {
            if (!isBidAcceptable(config, currentBid, minFeePerGasInWei, msg.value)) {
                revert L1_BID_NOT_ACCEPTABLE();
            } else {
                // otherwise we have a new high bid, and can refund the previous claimer deposit
                try tkoToken.transfer(currentBid.bidder, currentBid.deposit) {}
                catch {
                    // allow to fail in case they have a bad onTokenReceived
                    // so they cant be outbid
                }
                emit BidDepositRefunded(
                    batchStartBlockId, currentBid.bidder, block.timestamp, currentBid.deposit
                );
            }
        }

        // transfer deposit from bidder to this contract
        tkoToken.transferFrom(msg.sender, address(this), msg.value);

        // then we can update the bid for the blockID to the new bidder
        state.bids[batchStartBlockId] = TaikoData.Bid({
            bidder: msg.sender,
            bidAt: block.timestamp,
            deposit: msg.value,
            minFeePerGasInWei: minFeePerGasInWei
        });

        emit Bid(batchStartBlockId, msg.sender, block.timestamp, msg.value, minFeePerGasInWei);

    }

    // Example, visual representation of what the config parameters mean:
    // These are the block below:
    // 0   1   2   3   4   5   6   7   8   9   10
    // ■ - ■ - ■ - ■ - ■ - ■ - ■ - ■ - ■ - ■ - ■
    // If config.batchSize is 2 AND config.batchModulo 5 it means: 
    // bidder bids for 0th + 5th, or 1st + 6th, etc.
    // The given startBlockId / batch is the first blockId of that given batch
    // it can even serve as a unique batchId.
    function getBatchStartBlockId(
        TaikoData.Config memory config,
        uint256 blockId
    ) internal pure returns (uint256 startBlockId){
        return blockId - blockId % config.auctionBatchModulo;
    }

    // isBidAcceptable determines is checking if the bid is acceptable based on the defined
    // criteria
    function isBidAcceptable(
        TaikoData.Config memory config,
        TaikoData.Bid memory bid,
        uint256 minFeePerGasInWei,
        uint256 depositAmount
    )
        internal
        pure
        returns (bool result) 
    {

        if (
            minFeePerGasInWei >= config.auctionSmallestGasPerBlockBid 
            &&
            minFeePerGasInWei <= ((bid.minFeePerGasInWei - ((bid.minFeePerGasInWei * config.bidDiffBp) / 10000)))
            &&
            depositAmount <= ((bid.deposit - ((bid.deposit * config.bidDiffBp) / 10000)))
        )
        {
            result = true;
        }

    }

    // isBiddingOpenForBlockId determines whether a new bid for a block
    // would be accepted or not. It is kind of 'open ended' - so returns true if no bids came regardless of time
    function isBiddingOpenForBlock(TaikoData.Config memory config, TaikoData.Bid memory currentBid)
        internal
        view
        returns (bool)
    {
        if (currentBid.bidder == address(0)) return true;

        return (block.timestamp - currentBid.bidAt > config.auctionWindowInSec);
    }
}
