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

    event Bid(uint64 batchId, uint64 startedAt, TaikoData.Bid bid);

    error L1_BID_INVALID();
    error L1_BATCH_NOT_AUCTIONABLE();
    error L1_INSUFFICIENT_TOKEN();
    error L1_NOT_THE_BEST_BID();

    function bidForBatch(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Bid memory newBid,
        uint64 batchId
    )
        internal
    {
        if (!isBidValid(state, config, newBid, batchId)) {
            revert L1_BID_INVALID();
        }

        if (!isBatchAuctionable(state, config, batchId)) {
            revert L1_BATCH_NOT_AUCTIONABLE();
        }

        newBid.prover = msg.sender;

        // Have in-memory and write it back at the end of the function
        TaikoData.Auction memory auction =
            state.auctions[batchId % config.auctionRingBufferSize];

        // Deposit amount is per block, not per block * auctionBatchSize
        uint64 totalDeposit = newBid.deposit * config.auctionBatchSize;

        if (batchId != auction.batchId) {
            // It is a new auction
            auction.startedAt = uint64(block.timestamp);
            auction.bid = newBid;
            auction.batchId = batchId;
            unchecked {
                state.numOfAuctions += 1;
            }
        } else {
            // An ongoing one
            if (!isBidBetter(auction.bid, newBid)) {
                revert L1_NOT_THE_BEST_BID();
            }
            //'Refund' current
            state.taikoTokenBalances[auction.bid.prover] += totalDeposit;
        }

        // Check if bidder at least have the balance
        if (state.taikoTokenBalances[newBid.prover] < totalDeposit) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        state.taikoTokenBalances[newBid.prover] -= totalDeposit;
        auction.bid = newBid;

        emit Bid(auction.batchId, auction.startedAt, newBid);
    }

    // Mapping blockId to batchId where batchId is a ring buffer, blockId is
    // absolute (aka. block height)
    function blockIdToBatchId(
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        pure
        returns (uint64)
    {
        return 1 + uint64((blockId - 1) / config.auctionBatchSize);
    }

    // Check validity requirements
    function isBidValid(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Bid memory newBid,
        uint64 batchId
    )
        internal
        view
        returns (bool)
    {
        if (
            batchId == 0 || config.maxFeePerGas < newBid.feePerGas
                || newBid.prover != address(0) // auto-fill
                || newBid.proofWindow
                    > state.avgProofWindow * config.auctionProofWindowMultiplier // Cannot
                // be more than 2x of average
                // TODO(daniel): why
                // TODO(daniel): rename maxFeePerGas?
                || newBid.feePerGas > config.maxFeePerGas
        ) {
            return false;
        }

        return true;
    }

    // Check if auction ha ended or not
    function hasAuctionEnded(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 batchId
    )
        internal
        view
        returns (bool)
    {
        TaikoData.Auction memory auction =
            state.auctions[batchId % config.auctionRingBufferSize];

        if (block.timestamp < auction.startedAt + config.auctionWindowInSec) {
            return false;
        }

        return true;
    }

    // isBidAcceptable determines is checking if the bid is acceptable based on
    // the defined
    // criteria. Shall be called after isBatchAuctionable() returns true.
    function isBidBetter(
        TaikoData.Bid memory oldBid,
        TaikoData.Bid memory newBid
    )
        internal
        pure
        returns (bool result)
    {
        if (
            newBid.feePerGas
                <= (oldBid.feePerGas - ((oldBid.feePerGas * 9000) / 10_000)) // 90%
                && newBid.deposit
                    <= ((oldBid.deposit - ((oldBid.deposit * 5000) / 10_000))) // 50%
        ) {
            result = true;
        }
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
        uint64 currentProposedBatchId =
            blockIdToBatchId(config, state.numBlocks);
        uint64 currentVerifiedBatchId =
            blockIdToBatchId(config, state.lastVerifiedBlockId + 1);

        // Regardless of auction started or not - do not allow too many auctions
        // to be open
        if (
            // the batch of lastVerifiedBlockId is never auctionable as it has
            // to be ended before the last verifeid block can be verified.
            batchId < currentVerifiedBatchId
            // We cannot start a new auction if the previous one has not started
            || batchId > state.numOfAuctions + 1
            // We cannot start a new auction if we have to keep all the auctions
            // info in order to prove/verify blocks
            || batchId >= currentVerifiedBatchId + config.auctionRingBufferSize
                || batchId
                    >= currentProposedBatchId + config.auctonMaxAheadOfProposals
        ) {
            return false;
        }

        TaikoData.Auction memory auction =
            state.auctions[batchId % config.auctionRingBufferSize];

        // Auction not started yet
        if (auction.batchId != batchId) return true;

        // Already out of the auction window
        if (block.timestamp > auction.startedAt + config.auctionWindowInSec) {
            return false;
        }

        return true;
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
        uint64 batchId = blockIdToBatchId(config, blockId);

        // Either:
        // 1. we are in the window granted for prover or commited by the prover
        // he/she submits the proof
        // 2. anyone can submit proofs if we are outside of that window
        if (!hasAuctionEnded(state, config, batchId)) return false;

        TaikoData.Auction memory auction =
            state.auctions[batchId % config.auctionRingBufferSize];

        uint64 timerStart = auction.startedAt + config.auctionWindowInSec;
        uint64 deadline = timerStart + auction.bid.proofWindow;

        if (block.timestamp > deadline) return true;
        else return prover == auction.bid.prover;
    }
}
