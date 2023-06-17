// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibUtils } from "./LibUtils.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";
import { LibL2Consts } from "../../L2/LibL2Consts.sol";

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
        uint48 initFeePerGas,
        uint16 initAvgProofDelay
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
                || config.txListCacheExpiry > 30 * 24 hours
                || config.maxBytesPerTxList > 128 * 1024 //blob up to 128K
                || config.ethDepositMinCountPerBlock == 0
                || config.ethDepositMaxCountPerBlock
                    < config.ethDepositMinCountPerBlock || config.ethDepositGas == 0 //
                || config.ethDepositMinAmount == 0
                || config.ethDepositMaxAmount <= config.ethDepositMinAmount
                || config.ethDepositMaxAmount >= type(uint96).max
                || config.ethDepositMaxFee == 0
                || config.ethDepositMaxFee >= type(uint96).max
                || config.ethDepositMaxFee
                    >= type(uint96).max / config.ethDepositMaxCountPerBlock
                || config.ethDepositRingBufferSize <= 1
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

        state.avgProofDelay = initAvgProofDelay;

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

        IERC20Upgradeable taikoToken =
            IERC20Upgradeable(resolver.resolve("taiko_token", false));

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
                taikoToken: taikoToken,
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
                state.lastVerifiedBlockId, blockHash, signalRoot
            );
        }
    }

    function _verifyBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        IERC20Upgradeable taikoToken,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId
    )
        private
    {
        // the actually mined L2 block's gasLimit is blk.gasLimit +
        // LibL2Consts.ANCHOR_GAS_COST, so fc.gasUsed may greater than
        // blk.gasLimit here.
        uint32 _gasLimit = blk.gasLimit + LibL2Consts.ANCHOR_GAS_COST;
        assert(fc.gasUsed <= _gasLimit);

        // Refund the diff to the proposer
        taikoToken.transfer(
            blk.proposer, (_gasLimit - fc.gasUsed) * blk.feePerGas
        );

        bool rewardActualProver; // reward the actual prover?
        bool slashAssignedProver; // Slash assigned prover?
        bool updateAverage;

        if (fc.prover != address(1)) {
            rewardActualProver = true;

            if (blk.prover == address(0)) {
                updateAverage = true;
            } else if (
                fc.prover == blk.prover
                    && fc.provenAt <= blk.proposedAt + blk.proofWindow
            ) {
                updateAverage = true;
            } else {
                slashAssignedProver = true;
            }
        }

        uint64 proofReward;
        if (rewardActualProver) {
            proofReward = (config.blockFeeBaseGas + fc.gasUsed) * blk.feePerGas;

            taikoToken.transfer(fc.prover, proofReward);
        }

        if (updateAverage) {
            state.avgProofDelay = uint16(
                LibUtils.movingAverage({
                    maValue: state.avgProofDelay,
                    // TODO:  provers dontt have the will to submit
                    // proofs ASAP.
                    newValue: fc.provenAt - blk.proposedAt,
                    maf: 7200
                })
            );

            state.feePerGas = uint48(
                LibUtils.movingAverage({
                    maValue: state.feePerGas,
                    newValue: blk.feePerGas,
                    maf: 7200
                })
            );
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;
        emit BlockVerified(blk.blockId, fc.blockHash, proofReward);
    }
}
