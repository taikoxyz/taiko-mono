// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { IProver } from "../IProver.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibVerifying {
    using Address for address;
    using LibUtils for TaikoData.State;
    using LibMath for uint256;

    event BlockVerified(
        uint256 indexed blockId, address indexed prover, bytes32 blockHash
    );
    event CrossChainSynced(
        uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    error L1_BLOCK_ID_MISMATCH();
    error L1_INVALID_CONFIG();
    error L1_UNEXPECTED_FORK_CHOICE_ID();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash
    )
        internal
    {
        if (
            config.chainId <= 1 //
                || config.blockMaxProposals == 1
                || config.blockRingBufferSize <= config.blockMaxProposals + 1
                || config.blockMaxGasLimit == 0 || config.blockMaxTxListBytes == 0
                || config.blockTxListExpiry > 30 * 24 hours
                || config.blockMaxTxListBytes > 128 * 1024 //blob up to 128K
                || config.proofRegularCooldown < config.proofOracleCooldown
                || config.proofWindow == 0 || config.proofBond == 0
                || config.proofBond < 10 * config.proposerRewardPerSecond
                || config.ethDepositRingBufferSize <= 1
                || config.ethDepositMinCountPerBlock == 0
                || config.ethDepositMaxCountPerBlock
                    < config.ethDepositMinCountPerBlock
                || config.ethDepositMinAmount == 0
                || config.ethDepositMaxAmount <= config.ethDepositMinAmount
                || config.ethDepositMaxAmount >= type(uint96).max
                || config.ethDepositGas == 0 || config.ethDepositMaxFee == 0
                || config.ethDepositMaxFee >= type(uint96).max
                || config.ethDepositMaxFee
                    >= type(uint96).max / config.ethDepositMaxCountPerBlock
        ) revert L1_INVALID_CONFIG();

        unchecked {
            uint64 timeNow = uint64(block.timestamp);

            // Init state
            state.slotA.genesisHeight = uint64(block.number);
            state.slotA.genesisTimestamp = timeNow;
            state.slotB.numBlocks = 1;
            state.slotB.lastVerifiedAt = uint64(block.timestamp);

            // Init the genesis block
            TaikoData.Block storage blk = state.blocks[0];
            blk.nextForkChoiceId = 2;
            blk.verifiedForkChoiceId = 1;
            blk.proposedAt = timeNow;

            // Init the first fork choice
            TaikoData.ForkChoice storage fc = state.forkChoices[0][1];
            fc.blockHash = genesisBlockHash;
            fc.provenAt = timeNow;
        }

        emit BlockVerified({
            blockId: 0,
            prover: LibUtils.ORACLE_PROVER,
            blockHash: genesisBlockHash
        });
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 maxBlocks
    )
        internal
    {
        TaikoData.SlotB memory b = state.slotB;
        uint64 blockId = b.lastVerifiedBlockId;

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        uint16 fcId = blk.verifiedForkChoiceId;
        if (fcId == 0) revert L1_UNEXPECTED_FORK_CHOICE_ID();

        bytes32 blockHash = state.forkChoices[blockId][fcId].blockHash;

        bytes32 signalRoot;
        TaikoData.ForkChoice memory fc;

        uint64 processed;
        unchecked {
            ++blockId;

            while (blockId < b.numBlocks && processed < maxBlocks) {
                blk = state.blocks[blockId % config.blockRingBufferSize];
                if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

                fcId = LibUtils.getForkChoiceId(state, blk, blockId, blockHash);
                if (fcId == 0) break;

                fc = state.forkChoices[blockId][fcId];
                if (fc.prover == address(0)) break;

                uint256 proofCooldown = fc.prover == LibUtils.ORACLE_PROVER
                    ? config.proofOracleCooldown
                    : config.proofRegularCooldown;
                if (block.timestamp <= fc.provenAt + proofCooldown) {
                    break;
                }

                blockHash = fc.blockHash;
                signalRoot = fc.signalRoot;
                blk.verifiedForkChoiceId = fcId;

                _rewardProver(state, blk, fc);
                emit BlockVerified(blockId, fc.prover, fc.blockHash);

                ++blockId;
                ++processed;
            }

            if (processed > 0) {
                uint64 lastVerifiedBlockId = b.lastVerifiedBlockId + processed;
                state.slotB.lastVerifiedBlockId = lastVerifiedBlockId;
                state.slotB.lastVerifiedAt = uint64(block.timestamp);

                if (config.relaySignalRoot) {
                    // Send the L2's signal root to the signal service so other
                    // TaikoL1  deployments, if they share the same signal
                    // service, can relay the signal to their corresponding
                    // TaikoL2 contract.
                    ISignalService(resolver.resolve("signal_service", false))
                        .sendSignal(signalRoot);
                }
                emit CrossChainSynced(
                    lastVerifiedBlockId, blockHash, signalRoot
                );
            }
        }
    }

    function _rewardProver(
        TaikoData.State storage state,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice memory fc
    )
        private
    {
        address recipient = blk.prover;
        uint256 amount = blk.proofBond;
        unchecked {
            if (
                fc.prover != LibUtils.ORACLE_PROVER
                    && fc.provenAt > blk.proposedAt + blk.proofWindow
            ) {
                recipient = fc.prover;
                amount /= 4;
            }
        }

        state.taikoTokenBalances[recipient] += amount;
    }
}
