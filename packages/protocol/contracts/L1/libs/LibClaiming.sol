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

library LibClaiming {
    using LibAddress for address;

    event ClaimBlockBid(
        uint256 indexed id,
        address claimer,
        uint256 claimedAt,
        uint256 deposit
    );

    event BidRefunded(
        uint256 indexed id,
        address claimer,
        uint256 refundedAt,
        uint256 refund
    );

    error L1_ID();
    error L1_CLAIM_AUCTION_WINDOW_PASSED();
    error L1_HALTED();
    error L1_ALREADY_CLAIMED();
    error L1_INVALID_CLAIM_DEPOSIT();
    error L1_CLAIM_AUCTION_DELAY_PASSED();

    // claimBlock lets a prover claim a block for only themselves to prove,
    // for a limited amount of time.
    // if the time passes and they dont submit a proof,
    // they will lose their deposit, half to the new prover, half is burnt.
    // there is a set window anyone can bid, then the winner has N time to prove it.
    // after which anyone can prove.
    function claimBlock(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Config memory config,
        uint256 blockId,
        uint256 bid
    ) internal {
        if (
            state.proposedBlocks[blockId % config.maxNumBlocks].proposer ==
            address(0)
        ) {
            revert L1_ID();
        }

        TaikoData.Claim memory currentClaim = state.claims[blockId];

        if (
            currentClaim.claimer != address(0) &&
            (block.timestamp - currentClaim.claimedAt >
                config.claimAuctionDelayInSeconds)
        ) {
            revert L1_CLAIM_AUCTION_DELAY_PASSED();
        }

        // we need to make sure this bid
        // is within it claimAuctionWindowInSeconds.
        if (
            block.timestamp -
                state.proposedBlocks[blockId % config.maxNumBlocks].proposedAt >
            config.claimAuctionWindowInSeconds
        ) {
            revert L1_CLAIM_AUCTION_WINDOW_PASSED();
        }

        uint256 baseFee = claimBaseFee(state);
        // if user hasnt sent enough to meet their personal base deposit amount
        // we dont allow them to claim.
        if (bid < baseFee) {
            revert L1_INVALID_CLAIM_DEPOSIT();
        }

        TaikoToken tkoToken = TaikoToken(resolver.resolve("tko_token", false));

        // if there is an existing claimer, we need to see if msg.value sent is higher than the previous deposit.
        if (currentClaim.claimer != address(0)) {
            if (
                bid < minRequiredBidForClaim(state, blockId) // bid should be at minimum 10% higher than previous
            ) {
                revert L1_INVALID_CLAIM_DEPOSIT();
            } else {
                // otherwise we have a new high bid, and can refund the previous claimer
                // refund the previous claimer
                try
                    tkoToken.transfer(
                        currentClaim.claimer,
                        currentClaim.deposit
                    )
                {} catch {
                    // allow to fail in case they have a bad onTokenReceived
                    // so they cant be outbid
                }
                emit BidRefunded(
                    blockId,
                    currentClaim.claimer,
                    block.timestamp,
                    currentClaim.deposit
                );
            }
        } else {
            try tkoToken.transferFrom(msg.sender, address(this), bid) {} catch {
                // allow to fail in case they have a bad onTokenReceived
                // so they cant be outbid
            }
        }

        // then we can update the claim for the blockID to the new claimer
        state.claims[blockId] = TaikoData.Claim({
            claimer: msg.sender,
            claimedAt: block.timestamp,
            deposit: bid
        });

        emit ClaimBlockBid(blockId, msg.sender, block.timestamp, msg.value);
    }

    function claimBaseFee(
        TaikoData.State storage state
    ) internal view returns (uint256) {
        return state.feeBase * 4; // 4x base proving fee costs
    }

    function minRequiredBidForClaim(
        TaikoData.State storage state,
        uint256 blockId
    ) internal view returns (uint256) {
        TaikoData.Claim memory claim = state.claims[blockId];
        if (claim.claimer == address(0)) {
            return claimBaseFee(state);
        }

        return claim.deposit + ((claim.deposit * 1000) / 10000);
    }
}
