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
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import {TaikoToken} from "../TaikoToken.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event CrossChainSynced(
        uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 initBlockFee
    )
        internal
    {
        if (
            config.chainId <= 1 //
                || config.maxNumProposedBlocks == 1
                || config.ringBufferSize <= config.maxNumProposedBlocks + 1
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
                || config.auctionWindowInSec == 0
                || config.worstCaseProofWindowInSec == 0
                || config.auctionBatchSize == 0
                || config.auctionSmallestGasPerBlockBid == 0
                || config.proposerBlockFeeMultiplierBP == 0
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.blockFee = initBlockFee;
        state.numBlocks = 1;

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

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
        TaikoData.Block storage blk = state.blocks[i % config.ringBufferSize];

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
            blk = state.blocks[i % config.ringBufferSize];
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
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId
    )
        private
    {
        uint64 proofTime;
        unchecked {
            proofTime = uint64(fc.provenAt - blk.proposedAt);
        }

        TaikoData.Bid memory winningBid = state.auctions[LibAuction.blockIdToBatchId(config, blk.blockId)].bid;
        
        uint64 rewardPerBlock = fc.gasUsed * winningBid.feePerGas;

        if(fc.gasUsed < blk.gasLimit) {
            // Refund the diff
            state.taikoTokenBalances[blk.proposer] += (blk.gasLimit - fc.gasUsed)  * winningBid.feePerGas;
        }
    
        state.avgFeePerGas = uint64(LibUtils.movingAverage(state.avgFeePerGas, winningBid.feePerGas, 100));

        TaikoToken tkoToken = TaikoToken(resolver.resolve("tko_token", false));
        // Prover indeed the one who won the auction
        if(winningBid.prover == fc.prover) {
            state.taikoTokenBalances[winningBid.prover] += (winningBid.deposit / config.auctionBatchSize) + rewardPerBlock;
        }
        else{
            // Give reward + half of the deposit/block
            state.taikoTokenBalances[fc.prover] += winningBid.deposit / (config.auctionBatchSize * 2) + rewardPerBlock;

            // Burn half of the deposit/block from original prover since he missed proving this block
            // We dont need to add / deduct anything to/from state.taikoTokenBalances, because we already
            // deducted it at bidding
            tkoToken.burn((address(this)), winningBid.deposit / (config.auctionBatchSize * 2));
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;
        emit BlockVerified(blk.blockId, fc.blockHash, rewardPerBlock);
    }
}
