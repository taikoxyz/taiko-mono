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
        uint256 feePerGas
    );

    error L1_BLOCK_ID();
    error L1_BID_CANNOT_BE_SUBMITTED();
    error L1_BID_DEPOSIT_AND_MSG_VALUE_MISMATCH();
    error L1_BID_NOT_ACCEPTABLE();
    error L1_ID_NOT_BATCH_ID();

    function bidForBatch(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Config memory config,
        TaikoData.Bid calldata newBid
    ) internal {

        if (!isBatchAuctionable(state, config, newBid.batchId)) {
            revert L1_BID_CANNOT_BE_SUBMITTED();
        }

        if (msg.value != newBid.deposit) {
            revert L1_BID_DEPOSIT_AND_MSG_VALUE_MISMATCH();
        }

        TaikoToken tkoToken = TaikoToken(resolver.resolve("tko_token", false));

        TaikoData.Auction memory auction = state.auctions[newBid.batchId];
        // If there is an existing bid already
        // we compare this bid to the existing one first, to see if its a
        // lower fee accepted.
        if (auction.startedAt != 0) {
            if (!isBidAcceptable(state, config, newBid)) {
                revert L1_BID_NOT_ACCEPTABLE();
            } else {
                // otherwise we have a new high bid, and can refund the previous claimer deposit
                try tkoToken.transfer(auction.bid.prover, auction.bid.deposit) {}
                catch {
                    // allow to fail in case they have a bad onTokenReceived
                    // so they cant be outbid
                }
            }
        }

        // transfer deposit from current auction winner to this contract
        tkoToken.transferFrom(msg.sender, address(this), msg.value);

        // then we can update the bid for the blockID to the new bidder
        state.auctions[newBid.batchId] = TaikoData.Auction({
            bid: newBid,
            startedAt: uint64(auction.startedAt == 0 ? block.timestamp : auction.startedAt)
        });

        emit Bid(newBid.batchId, msg.sender, block.timestamp, msg.value, newBid.feePerGas);

    }

    // Mapping blockId to batchId
    function blockIdToBatchId(
        TaikoData.Config memory config,
        uint256 blockId
    ) internal pure returns (uint256){
        return (blockId - 1) / config.auctionBatchSize;
    }

    // isBidAcceptable determines is checking if the bid is acceptable based on the defined
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
            &&
            newBid.feePerGas <= ((winningBid.feePerGas - ((winningBid.feePerGas * config.bidGasDiffBp) / 10000)))
            &&
            newBid.deposit <= ((winningBid.deposit - ((winningBid.deposit * config.bidDepositDiffBp) / 10000)))
        )
        {
            result = true;
        }

    }

    // isBatchAuctionable determines whether a new bid for a block
    // would be accepted or not. 'open ended' - so returns true if no bids came yet
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

        // 3 scenarios: 
        // TRUE: 1. auction not started yet -> startedAt == 0 -> TRUE
        // TRUE: 2. auction is up and running -> startedAt is not 0 and block.timestamp < starteAt + auctionWindowInSec
        // FALSE: 3. auction ended already -> block.timestamp > starteAt + auctionWindowInSec

        TaikoData.Auction memory auction = state.auctions[batchId];

        if (
            auction.startedAt == 0 
            ||
            (auction.startedAt != 0 && block.timestamp <= auction.startedAt + config.auctionWindowInSec)
        ) return true;
    }
}
