// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibAuction {
    using LibAddress for address;

    event Bid(
        uint256 indexed id,
        address prover,
        uint64 bidAt,
        uint64 deposit,
        uint64 feePerGas,
        uint16 committedProofWindow
    );

    error L1_BLOCK_ID();
    error L1_BID_CANNOT_BE_SUBMITTED();
    error L1_BID_DEPOSIT_AND_MSG_VALUE_MISMATCH();
    error L1_BID_NOT_ACCEPTABLE();
    error L1_ID_NOT_BATCH_ID();
    error L1_INSUFFICIENT_TOKEN();

    function bidForBatch(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Bid calldata newBid
    )
        internal
    {
        // Check if the new bid is valid (without checking if it is better)
        // check newBid.batchId > 0, not == 0
        // also check the new bidder's balance is sufficient

        /*
         if (state.taikoTokenBalances[newBid.prover] < newBid.deposit) {
            revert L1_INSUFFICIENT_TOKEN();
        }
        */

        if (!isBidValid(state, config, newBid)) {
            revert("invalid bid");
        }

        if (!isBatchAuctionable(state, config, newBid.batchId)) {
            revert L1_BID_CANNOT_BE_SUBMITTED();
        }


        TaikoData.Auction storage auction = state.auctions[newBid.batchId % config.auctionRingBufferSize];
        if (auction.bid.batchId != newBid.batchId) {
            // auction has not started
            auction.startedAt = uint64(block.timestamp);
            auction.bid = newBid;
        } else {
            // auction has started
            if (!isBidAcceptable(oldBid, newBid, config)) {
                revert ("not a better bid");
            }
            state.taikoTokenBalances[bid.prover] += bid.deposit;
            state.taikoTokenBalances[newBid.prover] -= newBid.deposit;
            auction.bid = newBid;
        }

        emit Bid(auction.startedAt, bid); // make it simpler
    }

    // Mapping blockId to batchId where batchId is a ring buffer, blockId is absolute (aka. block height)
    function blockIdToBatchId(
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        pure
        returns (uint64)
    {
        // make sure the batch ID for block #1 is 1, not zero.
        return 1 + uint64((blockId - 1) / config.auctionBatchSize);
    }

    // According to David's suggestion:
    // https://github.com/taikoxyz/taiko-mono/pull/13831#discussion_r1211886142
    // Nope, the suggestion is incorrect, should impl isPreviousAuctionStarted
    function isPreviousAuctionEverStarted(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 batchId
    )
        internal
        view
        returns (bool result)
    {
        require(batchId > 0);
        if(batchId == 1) {
            return true;
        }

        //Otherwise batchId is above 0, so we can deduct 1 safely
        TaikoData.Auction storage prevAuction = state.auctions[(batchId-1) % config.auctionRingBufferSize];
        uint64 prevBatchId = batchId - 1;

        return state.auctions[prevBatchId % config.auctionRingBufferSize].batchId == prevBatchId;
    }

    // isBidAcceptable determines is checking if the bid is acceptable based on
    // the defined
    // criteria. Shall be called after isBatchAuctionable() returns true.
    // Lets name it this way so we simply compare two bids instead of verifying if
    // it can be accepted. IF the new bid is better and the block is still auctionable,
    //the the bid is "acceptable".

    function isBidBetter(
        TaikoData.Config memory config,
        TaikoData.Bid calldata newBid,
        TaikoData.Bid calldata oldBid
    )
        internal
        pure
        view
        returns (bool result)
    {
        // TODO: Lets worry about the impl later.
    }

    // isBatchAuctionable determines whether a new bid for a batch of blocks
    // would be accepted or not. 'open ended' - so returns true if no bids came
    // yet
    function isBatchAuctionable(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 batchId
    )
        internal
        view
        returns (bool result)
    {
        // We should expose this function so that clients could query.
        // We also need to be sure, that the batchId of bid is indeed valid
        // Q: why we need to call `blockIdToBatchId` for `batchId` here?
        // if (batchId != blockIdToBatchId(config, batchId)) {
        //     revert L1_ID_NOT_BATCH_ID();
        // }

        if (!isPreviousAuctionEverStarted(state, config, batchId)){
            return false;
        }


        // 3 scenarios:
        // TRUE: 1. auction not started yet -> startedAt == 0 -> TRUE
        // TRUE: 2. auction is up and running -> startedAt is not 0 and
        // block.timestamp < starteAt + auctionWindowInSec
        // FALSE: else

        TaikoData.Auction storage auction = state.auctions[batchId % config.auctionRingBufferSize];

        // the auction has not started yet
        if (auction.batchId != batchId) return true;

        // Still in the auction windown
        if (block.timestamp > auction.startedAt + config.auctionWindowInSec) return false;

        uint64 MAX_LEADING_BATCHES = 10;
        if (batchId >  blockIdToBatchId(state.numBlocks) + MAX_LEADING_BATCHES) return false;

        return false;
    }

    function isBlockProvableBy(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId,
        address prover
    )
        internal
        view
        returns (bool result)
    {
        // address(0) or address(1) means oracle or system prover. During
        // proveBlock() we
        // pass the evidence.prover. If there is a malicious actor who would
        // submit the
        // proof with evidence.prover == address(1) to mock the system he/she
        // gets back
        // true here, but will revert later, in LibProving.sol here:
        // "if (specialProver != address(0) && msg.sender != specialProver)"
        if (prover == address(0) || prover == address(1)) {
            return true;
        }
        // We should expose this function so that clients could query.
        // We also need to be sure, that the batchId of bid is indeed valid
        uint256 batchId = blockIdToBatchId(config, blockId);

        // Either:
        // 1. we are in the window granted for prover or commited by the prover
        // he/she submits the proof
        // 2. anyone can submit proofs if we are outside of that window


        if (!hasAuctionEnded(batchId)) return false;

        TaikoData.Auction storage auction = state.auctions[batchId % SIZE];

        uint64 timerStart = block.proposedAt.max(auction.startedAt + config.auctionWindowInSec);
        uint64 deadline = timerStart + config.committedProofWindow;

        if (block.timestamp > deadline) return true;
        else return prover == auction.bid.prover;
    }
}
