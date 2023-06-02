// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibUtils } from "./LibUtils.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(
        uint256 indexed id,
        bytes32 blockHash,
        uint64 proposerFefund,
        uint64 proverReward
    );

    event CrossChainSynced(
        uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 initFeePerGas
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
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.feePerGas = initFeePerGas;
        state.numBlocks = 1;
        state.lastVerifiedAt = uint64(block.timestamp);

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        emit BlockVerified(0, genesisBlockHash, 0, 0);
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

        address systemProver = resolver.resolve("system_prover", true);
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
                blk: blk,
                fcId: uint24(fcId),
                fc: fc,
                systemProver: systemProver
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
                // TaikoL1
                // deployments, if they share the same signal service, can relay
                // the
                // signal to their corresponding TaikoL2 contract.
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
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId,
        address systemProver
    )
        private
    {
        TaikoData.Auction memory auction = state.auctions[LibUtils.batchForBlock(
            config, blk.blockId
        ) % config.auctionBatchSize];

        uint64 proofTime;
        unchecked {
            proofTime = uint64(fc.provenAt - blk.proposedAt);
        }

        uint64 refund;
        uint64 reward;
        unchecked {
            // Reward the prover
            if (
                fcId == 1
                    && (fc.prover == address(1) || fc.prover == auction.bid.prover)
            ) {
                // Refund to auction winner if the block is proven by him or the
                // system prover.
                // For simplicity, we do not check if the proof is submitted
                // before the proofWindow expires -- as long no other provers
                // submit a valid proof before the auction winner.

                state.taikoTokenBalances[auction.bid.prover] +=
                    auction.bid.deposit;

                reward = auction.bid.feePerGas
                    * (config.blockFeeBaseGas + fc.gasUsed);

                state.taikoTokenBalances[fc.prover] += reward;

                state.feePerGas = updateFeePerGas(
                    state.feePerGas,
                    state.lastVerifiedAt,
                    auction.bid.feePerGas,
                    block.timestamp
                );
            } else {
                // The protocol keep half deposit (can be burnt later)
                uint64 burn = auction.bid.deposit / 2;
                state.taikoTokenBalances[address(1)] += burn;

                // reward the other half to prover with block reward
                reward = auction.bid.deposit - burn
                    + auction.bid.feePerGas * (config.blockFeeBaseGas + fc.gasUsed);

                state.taikoTokenBalances[fc.prover] += reward;

                // Question: shall we increase the fee per gas if the proof
                // is not done by the auction winner?
                state.feePerGas = updateFeePerGas(
                    state.feePerGas,
                    state.lastVerifiedAt,
                    auction.bid.feePerGas * 2,
                    block.timestamp
                );
            }

            // Refund the proposer
            if (auction.bid.blockMaxGasLimit > fc.gasUsed) {
                refund = auction.bid.feePerGas
                    * (auction.bid.blockMaxGasLimit - fc.gasUsed);
                state.taikoTokenBalances[blk.proposer] += refund;
            }
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;

        state.lastVerifiedAt = uint64(block.timestamp);
        emit BlockVerified(blk.blockId, fc.blockHash, refund, reward);
    }

    // TODO(daniel): we need to fine tune this average value calculation to
    // ensure the fees are not changing too dramatically over a given period of
    // time
    function updateFeePerGas(
        uint64 avg,
        uint256 lastTimestamp,
        uint64 newValue,
        uint256 currentTimestamp
    )
        private
        pure
        returns (uint64)
    {
        return (avg * 1023 + newValue) / 1024;
    }
}
