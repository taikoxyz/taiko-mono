// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibAuction {
    using LibAddress for address;

    uint256 private constant ONE = 1_000_000;

    event BatchBid(uint64 indexed batchId, uint64 startedAt, TaikoData.Bid bid);

    error L1_BID_INVALID();
    error L1_BATCH_NOT_AUCTIONABLE();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_PARAM();
    error L1_NOT_THE_BEST_BID();

    function bidForBatch(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 batchId,
        TaikoData.Bid memory bid
    )
        internal
    {
        if (
            bid.prover != address(0) // auto-fill
                || bid.blockMaxGasLimit != 0 // auto-fill
                || bid.feePerGas == 0 || bid.proofWindow == 0 || bid.deposit == 0
                || bid.proofWindow
                    > state.avgProofWindow * config.auctionProofWindowMultiplier
                || bid.deposit
                    < state.feePerGas
                        * (config.blockFeeBaseGas + config.blockMaxGasLimit)
                        * config.auctionDepositMultipler
        ) {
            revert L1_BID_INVALID();
        }

        if (!isBatchAuctionable(state, config, batchId)) {
            revert L1_BATCH_NOT_AUCTIONABLE();
        }

        bid.prover = msg.sender;
        bid.blockMaxGasLimit = config.blockMaxGasLimit;

        // Have in-memory and write it back at the end of the function
        TaikoData.Auction memory auction =
            state.auctions[batchId % config.auctionRingBufferSize];

        // Deposit amount is per block, not per block * auctionBatchSize
        uint64 totalDeposit = bid.deposit * config.auctionBatchSize;

        if (batchId != auction.batchId) {
            // It is a new auction
            auction.startedAt = uint64(block.timestamp);
            auction.bid = bid;
            auction.batchId = batchId;
            unchecked {
                state.numAuctions += 1;
            }
        } else {
            // An ongoing one
            if (!isBidBetter(bid, auction.bid)) {
                revert L1_NOT_THE_BEST_BID();
            }
            //'Refund' current
            state.taikoTokenBalances[auction.bid.prover] += totalDeposit;
        }

        // Check if bidder at least have the balance
        if (state.taikoTokenBalances[bid.prover] < totalDeposit) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        state.taikoTokenBalances[bid.prover] -= totalDeposit;
        auction.bid = bid;

        state.auctions[batchId % config.auctionRingBufferSize] = auction;

        emit BatchBid(auction.batchId, auction.startedAt, bid);
    }

    function getAuctions(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 startBatchId,
        uint256 count
    )
        internal
        view
        returns (uint256 currentTime, TaikoData.Auction[] memory auctions)
    {
        if (startBatchId == 0 || count == 0) {
            revert L1_INVALID_PARAM();
        }

        currentTime = block.timestamp;
        auctions = new TaikoData.Auction[](count);
        uint256 i;
        for (; i < count; ++i) {
            uint256 _batchId = startBatchId + i;
            TaikoData.Auction memory auction =
                state.auctions[_batchId % config.auctionRingBufferSize];

            if (auction.batchId == _batchId) {
                auctions[i] = auction;
            }
        }
    }

    function isBlockProvableBy(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId,
        address prover
    )
        internal
        view
        returns (bool provable, TaikoData.Auction memory auction)
    {
        if (blockId != 0) {
            if (prover == address(0) || prover == address(1)) {
                // Note that auction may not exist at all.
                provable = true;
            } else {
                // Nobody can prove a block before the auction ended
                bool ended;
                (ended, auction) = _hasAuctionEnded({
                    state: state,
                    config: config,
                    batchId: batchForBlock(config, blockId)
                });

                if (ended) {
                    if (prover == auction.bid.prover) {
                        provable = true;
                    } else {
                        uint64 proofWindowEndAt = auction.startedAt
                            + config.auctionWindow + auction.bid.proofWindow;
                        provable = block.timestamp > proofWindowEndAt;
                    }
                }
            }
        }
    }

    // Mapping blockId to batchId where batchId is a ring buffer, blockId is
    // absolute (aka. block height)
    function batchForBlock(
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        pure
        returns (uint64)
    {
        if (blockId == 0) {
            return 0;
        } else {
            unchecked {
                return uint64((blockId - 1) / config.auctionBatchSize) + 1;
            }
        }
    }

    // Determines if bid a is better than bid b
    function isBidBetter(
        TaikoData.Bid memory a,
        TaikoData.Bid memory b
    )
        internal
        pure
        returns (bool)
    {
        // Normalize both feePerGas and feePerGas to a comparable scale.
        // feePerGas is considered more important than proofWindow, below
        // we use 1 as the weight of feePerGas, 1/2 as the weight of deposit,
        // and 1/4 as the weight of proofWindow.
        //
        // Bid a is only better than bid b if its score is 10% higher.
        return _adjustBidPropertyScore(ONE * b.feePerGas / a.feePerGas, 1)
            * _adjustBidPropertyScore(ONE * a.deposit / b.deposit, 2)
            * _adjustBidPropertyScore(ONE * b.proofWindow / a.proofWindow, 4)
            >= ONE * ONE * ONE * 110 / 100;
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
        if (batchId == 0) return false;

        uint64 currentProposedBatchId = batchForBlock(config, state.numBlocks);
        uint64 currentVerifiedBatchId =
            batchForBlock(config, state.lastVerifiedBlockId + 1);

        // Regardless of auction started or not - do not allow too many auctions
        // to be open
        if (
            // the batch of lastVerifiedBlockId is never auctionable as it has
            // to be ended before the last verifeid block can be verified.
            batchId < currentVerifiedBatchId
            // We cannot start a new auction if the previous one has not started
            || batchId > state.numAuctions + 1
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

        return auction.batchId != batchId
            || block.timestamp <= auction.startedAt + config.auctionWindow;
    }

    // Check if auction ha ended or not
    function _hasAuctionEnded(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 batchId
    )
        private
        view
        returns (bool ended, TaikoData.Auction memory auction)
    {
        if (batchId == 0) {
            ended = true;
        } else {
            auction = state.auctions[batchId % config.auctionRingBufferSize];
            ended = auction.batchId == batchId
                && block.timestamp > auction.startedAt + config.auctionWindow;
        }
    }

    function _adjustBidPropertyScore(
        uint256 score,
        uint256 weightInverse
    )
        private
        pure
        returns (uint256)
    {
        assert(weightInverse >= 1);
        if (score == ONE || weightInverse == 1) {
            return score;
        } else if (score < ONE) {
            return ONE - (ONE - score) / weightInverse;
        } else {
            return ONE + (score - ONE) / weightInverse;
        }
    }
}
