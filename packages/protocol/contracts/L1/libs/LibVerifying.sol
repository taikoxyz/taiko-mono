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
    event BondReturned(address indexed to, uint64 blockId, uint256 bond);
    event BondRewarded(address indexed to, uint64 blockId, uint256 bond);

    error L1_BLOCK_ID_MISMATCH();
    error L1_INVALID_CONFIG();
    error L1_UNEXPECTED_TRANSITION_ID();

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

        // Init state
        state.slotA.genesisHeight = uint64(block.number);
        state.slotA.genesisTimestamp = uint64(block.timestamp);
        state.slotB.numBlocks = 1;
        state.slotB.lastVerifiedAt = uint64(block.timestamp);

        // Init the genesis block
        TaikoData.Block storage blk = state.blocks[0];
        blk.nextTransitionId = 2;
        blk.verifiedTransitionId = 1;
        blk.proposedAt = uint64(block.timestamp);

        // Init the first state transition
        TaikoData.Transition storage tran = state.transitions[0][1];
        tran.blockHash = genesisBlockHash;
        tran.provenAt = uint64(block.timestamp);

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

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        uint32 tid = blk.verifiedTransitionId;
        if (tid == 0) revert L1_UNEXPECTED_TRANSITION_ID();

        bytes32 blockHash = state.transitions[slot][tid].blockHash;

        bytes32 signalRoot;
        TaikoData.Transition storage tran;

        uint64 processed;

        // Unchecked is safe:
        // - assignment is within ranges
        // - blockId and processed values incremented will still be OK in the
        // next 584K years if we verifying one block per every second
        unchecked {
            ++blockId;

            while (blockId < b.numBlocks && processed < maxBlocks) {
                slot = blockId % config.blockRingBufferSize;
                blk = state.blocks[slot];
                if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

                tid = LibUtils.getTransitionId(state, blk, slot, blockHash);
                if (tid == 0) break;

                tran = state.transitions[slot][tid];
                if (tran.prover == address(0)) break;

                uint256 proofCooldown = tran.prover == LibUtils.ORACLE_PROVER
                    ? config.proofOracleCooldown
                    : config.proofRegularCooldown;
                if (block.timestamp <= tran.provenAt + proofCooldown) {
                    break;
                }

                blockHash = tran.blockHash;
                signalRoot = tran.signalRoot;
                blk.verifiedTransitionId = tid;

                // If the default assigned prover is the oracle do not refund
                // because was not even charged.
                if (blk.prover != LibUtils.ORACLE_PROVER) {
                    // Refund bond or give 1/4 of it to the actual prover and
                    // burn the rest.
                    if (
                        tran.prover == LibUtils.ORACLE_PROVER
                            || tran.provenAt <= blk.proposedAt + config.proofWindow
                    ) {
                        state.taikoTokenBalances[blk.prover] += blk.proofBond;
                        emit BondReturned(blk.prover, blockId, blk.proofBond);
                    } else {
                        uint256 rewardAmount = blk.proofBond / 4;
                        state.taikoTokenBalances[tran.prover] += rewardAmount;
                        emit BondRewarded(tran.prover, blockId, rewardAmount);
                    }
                }

                emit BlockVerified(blockId, tran.prover, tran.blockHash);

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
}
