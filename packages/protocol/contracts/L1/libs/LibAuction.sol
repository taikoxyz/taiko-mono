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
        if (!isBatchAuctionable(state, config, newBid.batchId)) {
            revert L1_BID_CANNOT_BE_SUBMITTED();
        }

        // Have in-memory and write it back at the end of the function
        TaikoData.Auction memory auction = state.auctions[newBid.batchId % config.auctionRingBufferSize];
        
        // Clear auction in case the ring buffer overflow and this auction not an empty one but 'expired'
        if(auction.startedAt != 0 && auction.bid.batchId != newBid.batchId) {
            auction.startedAt = 0;
            TaikoData.Bid memory emptyBid;
            auction.bid = emptyBid;
        }

        // If there is an existing bid already for this actual auction
        // we compare this bid to the existing one first, to see if its a
        // lower fee accepted.
        if (auction.startedAt != 0) {
            if (!isBidAcceptable(state, config, newBid)) {
                revert L1_BID_NOT_ACCEPTABLE();
            } else {
                // We have a new high bid, refunding back the deposit credited
                // with taikoTokenBalances
                state.taikoTokenBalances[auction.bid.prover] +=
                    auction.bid.deposit;
            }
        }

        // New winner, so deduct deposit
        if (state.taikoTokenBalances[newBid.prover] < newBid.deposit) {
            revert L1_INSUFFICIENT_TOKEN();
        }
        state.taikoTokenBalances[newBid.prover] -= newBid.deposit;

        // then we can update the bid for the blockID to the new bidder (prover)
        state.auctions[newBid.batchId] = TaikoData.Auction({
            bid: newBid,
            startedAt: uint64(
                auction.startedAt == 0 ? block.timestamp : auction.startedAt
                )
        });

        emit Bid(
            newBid.batchId,
            msg.sender,
            uint64(block.timestamp),
            newBid.deposit,
            newBid.feePerGas,
            newBid.committedProofWindow
        );
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
        return uint64((blockId - 1) / config.auctionBatchSize);
    }

    // According to David's suggestion:
    // https://github.com/taikoxyz/taiko-mono/pull/13831#discussion_r1211886142
    function isPreviousAuctionEnded(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 batchId
    )
        internal
        view
        returns (bool result)
    {
        if(batchId == 0) {
            return true;
        }

        //Otherwise batchId is above 0, so we can deduct 1 safely
        TaikoData.Auction memory auction = state.auctions[(batchId-1) % config.auctionRingBufferSize];
        if(auction.startedAt != 0 && block.timestamp > auction.startedAt + config.auctionWindowInSec) {
            return true;
        }
    }

    // isBidAcceptable determines is checking if the bid is acceptable based on
    // the defined
    // criteria. Shall be called after isBatchAuctionable() returns true.
    function isBidAcceptable(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Bid calldata newBid
    )
        internal
        view
        returns (bool result)
    {
        TaikoData.Bid memory winningBid = state.auctions[newBid.batchId].bid;

        if (
            newBid.feePerGas >= config.auctionSmallestGasPerBlockBid
                && newBid.feePerGas
                    <= (
                        (
                            winningBid.feePerGas
                                - ((winningBid.feePerGas * 9000) / 10_000)
                        )
                    ) // 90%
                && newBid.deposit
                    <= ((winningBid.deposit - ((winningBid.deposit * 5000) / 10_000))) // 50%
                // Commenting out this one, because we need a scoring /
                    // weighting system rather then just checking if
                // committedProofWindow is smaller. ProofWindow might be bigger
                    // but what if the feePerGas is much better.. ?
                // &&
                // newBid.committedProofWindow <=
                    // winningBid.committedProofWindow
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
        // We should expose this function so that clients could query.
        // We also need to be sure, that the batchId of bid is indeed valid
        if (batchId != blockIdToBatchId(config, batchId)) {
            revert L1_ID_NOT_BATCH_ID();
        }

        if (!isPreviousAuctionEnded(state, config, batchId)){
            return false;
        }


        // 3 scenarios:
        // TRUE: 1. auction not started yet -> startedAt == 0 -> TRUE
        // TRUE: 2. auction is up and running -> startedAt is not 0 and
        // block.timestamp < starteAt + auctionWindowInSec
        // FALSE: else

        TaikoData.Auction memory auction = state.auctions[batchId];

        if (
            auction.startedAt == 0
                || (
                    auction.startedAt != 0
                        && block.timestamp
                            <= auction.startedAt + config.auctionWindowInSec
                )
        ) return true;
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
        TaikoData.Auction memory auction = state.auctions[batchId];

        // 2 cases: If a prover committed to a proofWindow or not and submits a
        // proof somewhere within the worstCaseProofWindowInSec
        if (auction.startedAt != 0) {
            if (auction.bid.committedProofWindow == 0) {
                if (
                    block.timestamp
                        > auction.startedAt + config.auctionWindowInSec
                            + config.worstCaseProofWindowInSec
                        || (
                            block.timestamp
                                > auction.startedAt + config.auctionWindowInSec
                                && auction.bid.prover == prover
                        )
                ) {
                    return true;
                }
            } else {
                if (
                    block.timestamp
                        > auction.startedAt + config.auctionWindowInSec
                            + auction.bid.committedProofWindow
                        || (
                            block.timestamp
                                > auction.startedAt + config.auctionWindowInSec
                                && auction.bid.prover == prover
                        )
                ) {
                    return true;
                }
            }
        }
    }
}
