// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ISignalService} from "../../signal/ISignalService.sol";
import {LibAuction} from "./LibAuction.sol";
import {LibUtils} from "./LibUtils.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;
    using LibMath for uint256;

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event CrossChainSynced(
        uint256 indexed srcHeight,
        bytes32 blockHash,
        bytes32 signalRoot
    );

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 initFeePerGas,
        uint64 initAvgProofWindow
    ) internal {
        if (
            config.chainId <= 1 || //
            config.maxNumProposedBlocks == 1 ||
            config.blockRingBufferSize <= config.maxNumProposedBlocks + 1 ||
            config.blockMaxGasLimit == 0 ||
            config.maxTransactionsPerBlock == 0 ||
            config.maxBytesPerTxList == 0 ||
            // EIP-4844 blob size up to 128K
            config.maxBytesPerTxList > 128 * 1024 ||
            config.maxEthDepositsPerBlock == 0 ||
            config.maxEthDepositsPerBlock < config.minEthDepositsPerBlock ||
            // EIP-4844 blob deleted after 30 days
            config.txListCacheExpiry > 30 * 24 hours ||
            config.ethDepositGas == 0 || //
            config.ethDepositMaxFee == 0 ||
            config.ethDepositMaxFee >= type(uint96).max ||
            config.auctionWindow == 0 ||
            config.auctionMaxProofWindow == 0 ||
            config.auctionBatchSize == 0 ||
            config.auctionRingBufferSize <=
            (config.maxNumProposedBlocks /
                (config.auctionBatchSize +
                    1 +
                    config.auctionMaxAheadOfProposals)) || //
            config.auctionProofWindowMultiplier <= 1 ||
            config.auctionWindow <= 24 ||
            config.auctionDepositMultipler <= 1 ||
            config.auctionMaxFeePerGasMultipler <= 1 ||
            config.auctionDepositMultipler < config.auctionMaxFeePerGasMultipler
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.lastVerifiedAt = uint64(block.timestamp);
        state.feePerGas = initFeePerGas;
        state.numBlocks = 1;

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        state.avgProofWindow = initAvgProofWindow;

        emit BlockVerified(0, genesisBlockHash, 0);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks
    ) internal {
        uint256 i = state.lastVerifiedBlockId;
        TaikoData.Block storage blk = state.blocks[
            i % config.blockRingBufferSize
        ];

        uint256 fcId = blk.verifiedForkChoiceId;
        // assert(fcId > 0);
        bytes32 blockHash = blk.forkChoices[fcId].blockHash;
        uint32 gasUsed = blk.forkChoices[fcId].gasUsed;
        bytes32 signalRoot;

        uint64 processed;
        unchecked {
            ++i;
        }

        while (i < state.numBlocks && processed < maxBlocks) {
            blk = state.blocks[i % config.blockRingBufferSize];
            assert(blk.blockId == i);

            fcId = LibUtils.getForkChoiceId(state, blk, blockHash, gasUsed);

            if (fcId == 0) break;

            TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

            if (fc.prover == address(0)) break;

            uint256 proofCooldownPeriod = fc.prover == address(1)
                ? config.systemProofCooldownPeriod
                : config.proofCooldownPeriod;

            if (block.timestamp < fc.provenAt + proofCooldownPeriod) break;

            blockHash = fc.blockHash;
            gasUsed = fc.gasUsed;
            signalRoot = fc.signalRoot;

            _verifyBlock({
                state: state,
                config: config,
                blk: blk,
                fcId: uint24(fcId),
                fc: fc
            });

            unchecked {
                ++i;
                ++processed;
            }
        }

        if (processed > 0) {
            unchecked {
                state.lastVerifiedAt = uint64(block.timestamp);
                state.lastVerifiedBlockId += processed;
            }

            if (config.relaySignalRoot) {
                // Send the L2's signal root to the signal service so other
                // TaikoL1  deployments, if they share the same signal
                // service, can relay the signal to their corresponding
                // TaikoL2 contract.
                ISignalService(resolver.resolve("signal_service", false))
                    .sendSignal(signalRoot);
            }
            emit CrossChainSynced(
                state.lastVerifiedBlockId,
                blockHash,
                signalRoot
            );
        }
    }

    function _verifyBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId
    ) private {
        TaikoData.Auction memory auction;
        {
            uint64 batchId = LibAuction.batchForBlock(config, blk.blockId);
            auction = state.auctions[batchId % config.auctionRingBufferSize];
            assert(auction.batchId == batchId);
        }

        // Refund the diff to the proposer
        assert(fc.gasUsed <= blk.gasLimit);
        state.taikoTokenBalances[blk.proposer] +=
            (blk.gasLimit - fc.gasUsed) *
            blk.feePerGas;

        bool refundBidder;
        bool rewardProver;
        bool updateAverage;

        if (fc.prover == address(1)) {
            // This is the system prover.
            refundBidder = true;
            // rewardProver = false;
            // updateAverage = false;
        } else {
            uint64 proofWindowEndAt;
            unchecked {
                uint64 auctionEndAt = auction.startedAt + config.auctionWindow;
                proofWindowEndAt = auctionEndAt > blk.proposedAt
                    ? auctionEndAt + auction.bid.proofWindow
                    : blk.proposedAt + auction.bid.proofWindow;
            }

            if (
                fc.prover == auction.bid.prover &&
                fc.provenAt <= proofWindowEndAt
            ) {
                // The prover is the auction winner and proof submitted within
                // the proof window
                refundBidder = true;
                rewardProver = true;
                updateAverage = true;
            } else {
                // The prover is not the auction winner or the proof
                // as submitted out of the proof window
                rewardProver = true;
                // refundBidder = false;
                // updateAverage = false;
            }
        }

        if (refundBidder) {
            state.taikoTokenBalances[auction.bid.prover] += auction.bid.deposit;
        } else {
            // During the deposit we already burnt it. So it is rather
            // minting.
            uint64 amountToDeduct = rewardProver // deduct all or half
                ? auction.bid.deposit / 2
                : auction.bid.deposit;

            state.taikoTokenBalances[auction.bid.prover] -= amountToDeduct;
        }

        uint64 proofReward;
        if (rewardProver) {
            proofReward =
                (config.blockFeeBaseGas + fc.gasUsed) *
                auction.bid.feePerGas;
            state.taikoTokenBalances[fc.prover] +=
                auction.bid.deposit /
                2 +
                proofReward;
        }

        if (updateAverage) {
            unchecked {
                state.avgProofWindow = uint64(
                    LibUtils.movingAverage({
                        maValue: state.avgProofWindow,
                        newValue: auction.bid.proofWindow,
                        maf: 7200
                    })
                );

                state.feePerGas = uint64(
                    LibUtils.movingAverage({
                        maValue: state.feePerGas,
                        newValue: auction.bid.feePerGas,
                        maf: 7200
                    })
                );
            }
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;
        emit BlockVerified(blk.blockId, fc.blockHash, proofReward);
    }
}
