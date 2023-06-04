// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibAuction } from "./LibAuction.sol";
import { LibUtils } from "./LibUtils.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;
    using LibMath for uint256;

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event CrossChainSynced(
        uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 initFeePerGas,
        uint64 initProofWindow
    )
        internal
    {
        if (
            config.chainId <= 1 //
                || config.maxNumProposedBlocks == 1
                || config.blockRingBufferSize <= config.maxNumProposedBlocks + 1
                || config.blockMaxGasLimit == 0
                || config.maxTransactionsPerBlock == 0
                || config.maxBytesPerTxList == 0
            // EIP-4844 blob size up to 128K
            || config.maxBytesPerTxList > 128 * 1024
                || config.maxEthDepositsPerBlock == 0
                || config.maxEthDepositsPerBlock < config.minEthDepositsPerBlock
            // EIP-4844 blob deleted after 30 days
            || config.txListCacheExpiry > 30 * 24 hours
                || config.ethDepositGas == 0 //
                || config.ethDepositMaxFee == 0
                || config.ethDepositMaxFee >= type(uint96).max
                || config.auctionWindow == 0 || config.auctionMaxProofWindow == 0
                || config.auctionBatchSize == 0
                || config.auctionRingBufferSize
                    <= (
                        config.maxNumProposedBlocks / config.auctionBatchSize + 1
                            + config.auctonMaxAheadOfProposals
                    ) //
                || config.auctionProofWindowMultiplier <= 1
                || config.auctionWindow <= 24 || config.auctionDepositMultipler <= 1
                || config.auctionMaxFeePerGasMultipler <= 1
                || config.auctionDepositMultipler
                    < config.auctionMaxFeePerGasMultipler
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.feePerGas = initFeePerGas;
        state.numBlocks = 1;

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        state.proofWindow = initProofWindow;

        emit BlockVerified(0, genesisBlockHash, 0);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks
    )
        internal
    {
        uint256 i = state.lastVerifiedBlockId;
        TaikoData.Block storage blk =
            state.blocks[i % config.blockRingBufferSize];

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
            // assert(blk.blockId == i);

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

            _markBlockVerified({
                state: state,
                config: config,
                resolver: resolver,
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
                state.lastVerifiedBlockId, blockHash, signalRoot
            );
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId
    )
        private
    {
        TaikoData.Auction memory auction = state.auctions[LibAuction
            .blockIdToBatchId(config, blk.blockId) % config.auctionRingBufferSize];

        unchecked {
            // update the average proofWindow
            uint64 auctionEndAt = auction.startedAt + config.auctionWindow;
            uint64 proofStartAt =
                auctionEndAt > blk.proposedAt ? auctionEndAt : blk.proposedAt;
            uint256 proofTime = uint256(config.auctionMaxProofWindow).max(
                fc.provenAt - proofStartAt
            );

            state.proofWindow = uint64(
                LibUtils.movingAverage(state.proofWindow, proofTime, 2048)
            );
        }

        uint64 rewardPerBlock = fc.gasUsed * auction.bid.feePerGas;

        if (fc.gasUsed < blk.gasLimit) {
            // Refund the diff to the proposer
            state.taikoTokenBalances[blk.proposer] +=
                (blk.gasLimit - fc.gasUsed) * blk.feePerGas;
        }

        // TODO(daniel): we need to fine tune this average value calculation to
        // ensure the fees are not changing too dramatically over a given period
        // of
        state.feePerGas = uint64(
            LibUtils.movingAverage(state.feePerGas, auction.bid.feePerGas, 100)
        );

        // Prover indeed the one who won the auction
        if (auction.bid.prover == fc.prover) {
            // Check if withing window OR not. If window: then OK, if not, then
            // pentaly.
            // 2 deadlines:
            //1. proofWindowd deadline (auciton started + auction wnidow + proof
            // window)
            //2. proposedAt + proofWindow.
            // Check if proof smaller than the largest.
            if (
                block.timestamp
                    < auction.startedAt + config.auctionWindow
                        + auction.bid.proofWindow
                    || block.timestamp < blk.proposedAt + auction.bid.proofWindow
            ) {
                // Within the window
                state.taikoTokenBalances[auction.bid.prover] +=
                    auction.bid.deposit + rewardPerBlock;
            } else {
                // Still the winning bidder is the prover, but ran out of time
                // so this block's deposit
                // burnt, but he/she gets the reward
                TaikoToken tkoToken =
                    TaikoToken(resolver.resolve("tko_token", false));
                tkoToken.burn((address(this)), auction.bid.deposit);
                // Within the window
                state.taikoTokenBalances[auction.bid.prover] += rewardPerBlock;
            }
        } else {
            // Give reward + half of the deposit/block
            state.taikoTokenBalances[fc.prover] += auction.bid.deposit
                / (config.auctionBatchSize * 2) + rewardPerBlock;

            // Burn half of the deposit/block from original prover since he
            // missed proving this block
            // We dont need to add / deduct anything to/from
            // state.taikoTokenBalances, because we already
            // deducted it at bidding

            TaikoToken tkoToken =
                TaikoToken(resolver.resolve("tko_token", false));
            tkoToken.burn(
                (address(this)),
                auction.bid.deposit / (config.auctionBatchSize * 2)
            );
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;
        emit BlockVerified(blk.blockId, fc.blockHash, rewardPerBlock);
    }
}
