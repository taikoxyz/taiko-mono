// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibAuction {
    using LibAddress for address;

    event Bid(
        uint256 indexed id,
        address claimer,
        uint256 claimedAt,
        uint256 deposit,
        uint256 minFeePerGasAcceptedInWei
    );

    event BidDepositRefunded(
        uint256 indexed id, address claimer, uint256 refundedAt, uint256 refund
    );

    error L1_ID();
    error L1_HALTED();
    error L1_ALREADY_CLAIMED();
    error L1_INVALID_BID_AMOUNT();
    error L1_BID_AUCTION_DELAY_PASSED();

    // bidForBlock lets a prover claim a block for only themselves to prove,
    // for a limited amount of time.
    // if the time passes and they dont submit a proof,
    // they will lose their deposit, half to the new prover, half is burnt.
    // there is a set window anyone can bid, then the winner has N time to prove it.
    // after which anyone can prove.
    function bidForBlock(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Config memory config,
        uint256 blockId,
        uint256 minFeePerGasAcceptedInWei
    ) internal {
        // if the block hasnt been proposed yet, dont allow bid.
        if (blockId <= state.lastVerifiedBlockId || blockId >= state.numBlocks) {
            revert L1_ID();
        }

        TaikoData.Bid memory currentBid = state.bids[blockId % config.ringBufferSize];

        // if a current bid exists, and the delay after the current bid exists
        // has passed, bidding is over.
        if (!isBiddingOpenForBlock(config, currentBid)) {
            revert L1_BID_AUCTION_DELAY_PASSED();
        }

        TaikoToken tkoToken = TaikoToken(resolver.resolve("tko_token", false));

        // if there is an existing claimer,
        // we compare this bid to the existing one first, to see if its a
        // lower fee accepted.
        if (currentBid.bidder != address(0)) {
            // if 0, there is no existing bid, any value is fine.
            uint256 maxRequiredFeePerGasAccepted = maxRequiredBid(state, blockId);
            if (
                maxRequiredFeePerGasAccepted != 0
                    && minFeePerGasAcceptedInWei < maxRequiredFeePerGasAccepted
            ) {
                revert L1_INVALID_BID_AMOUNT();
            } else {
                // otherwise we have a new high bid, and can refund the previous claimer deposit
                try tkoToken.transfer(currentBid.bidder, currentBid.deposit) {}
                catch {
                    // allow to fail in case they have a bad onTokenReceived
                    // so they cant be outbid
                }
                emit BidDepositRefunded(
                    blockId, currentBid.bidder, block.timestamp, currentBid.deposit
                );
            }
        }

        // transfer deposit from bidder to this contract
        tkoToken.transferFrom(msg.sender, address(this), msg.value);

        // then we can update the bid for the blockID to the new bidder
        state.bids[blockId] = TaikoData.Bid({
            bidder: msg.sender,
            bidAt: block.timestamp,
            deposit: msg.value,
            minFeePerGasAcceptedInWei: minFeePerGasAcceptedInWei,
            blockId: blockId
        });

        emit Bid(blockId, msg.sender, block.timestamp, msg.value, minFeePerGasAcceptedInWei);
    }

    // maxRequiredBid determines the highest viable amount one could bid
    // on the current block. If it returns 0, any amount is accepted.
    function maxRequiredBid(TaikoData.State storage state, uint256 blockId)
        internal
        view
        returns (uint256)
    {
        TaikoData.Bid memory bid = state.bids[blockId];
        if (bid.bidder == address(0)) {
            return 0;
        }

        return bid.minFeePerGasAcceptedInWei + ((bid.minFeePerGasAcceptedInWei * 1000) / 10000);
    }

    // isBiddingOpenForBlockId determines whether a new bid for a block
    // would be accepted or not
    function isBiddingOpenForBlock(TaikoData.Config memory config, TaikoData.Bid memory currentBid)
        internal
        view
        returns (bool)
    {
        if (currentBid.bidder == address(0)) return true;

        return (block.timestamp - currentBid.bidAt > config.auctionDelayInSeconds);
    }

    // isAuctionWinnersBidForfeited determines whether that bidder still has sole claim
    // over their bid, or if they have forfeited their right, and anyone
    // can now prove, to win their deposit.
    // if block.timestamp minus the bidAt time is greater than than the delay in seconds
    // they forfeit.
    function isAuctionWinnersBidForfeited(
        TaikoData.Config memory config,
        TaikoData.Bid memory currentBid
    ) internal view returns (bool) {
        return
            block.timestamp - currentBid.bidAt > config.auctionTimeForProverToSubmitProofInSeconds;
    }
}
