// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

import { TaikoToken } from "../TaikoToken.sol";

import { LibUtils } from "./LibUtils.sol";
import { LibTiers } from "./LibTiers.sol";

/// @title LibVerifying
/// @notice A library for handling block verification in the Taiko protocol.
library LibVerifying {
    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed assignedProver,
        address indexed prover,
        bytes32 blockHash,
        bytes32 signalRoot
    );

    event CrossChainSynced(
        uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_CONFIG();
    error L1_TRANSITION_ID_ZERO();

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
                || config.blockMaxTxListBytes > 128 * 1024 //blob up to 128K
                || config.assignmentBond == 0
                || config.assignmentBond < 10 * config.proposerRewardPerSecond
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
        blk.proposedAt = uint64(block.timestamp);
        blk.verifiedTransitionId = 1;

        // Init the first state transition
        TaikoData.Transition storage tran = state.transitions[0][1];
        tran.blockHash = genesisBlockHash;
        tran.prover = address(0);
        tran.timestamp = uint64(block.timestamp);
        tran.tier = LibTiers.TIER_GUARDIAN;

        emit BlockVerified({
            blockId: 0,
            assignedProver: address(0),
            prover: address(0),
            blockHash: genesisBlockHash,
            signalRoot: 0
        });
    }

    /// @dev Verifies up to N blocks.
    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 maxBlocks
    )
        internal
    {
        // Retrieve the latest verified block and the associated transition used
        // for its verification.
        TaikoData.SlotB memory b = state.slotB;
        uint64 blockId = b.lastVerifiedBlockId;

        uint64 slot = blockId % config.blockRingBufferSize;

        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = blk.verifiedTransitionId;

        // The following scenario should never occur but is included as a
        // precaution.
        if (tid == 0) revert L1_TRANSITION_ID_ZERO();

        // The `blockHash` variable represents the most recently trusted
        // blockHash on L2.
        bytes32 blockHash = state.transitions[slot][tid].blockHash;
        bytes32 signalRoot;
        uint64 processed;

        // The Taiko token address which will be initialized as needed.
        address tt;

        // Unchecked is safe:
        // - assignment is within ranges
        // - blockId and processed values incremented will still be OK in the
        // next 584K years if we verifying one block per every second
        unchecked {
            ++blockId;

            while (blockId < b.numBlocks && processed < maxBlocks) {
                slot = blockId % config.blockRingBufferSize;

                blk = state.blocks[slot];
                if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

                tid = LibUtils.getTransitionId(state, blk, slot, blockHash);

                // When `tid` is 0, it indicates that there is no proven
                // transition with its parentHash equal to the blockHash of the
                // most recently verified block.
                if (tid == 0) break;

                // A transition with the correct `parentHash` has been located.
                TaikoData.Transition storage tran = state.transitions[slot][tid];

                // It's not possible to verify this block if either the
                // transition is contested and awaiting higher-tier proof or if
                // the transition is still within its cooldown period.
                if (
                    tran.contester != address(0)
                        || block.timestamp
                            <= uint256(tran.timestamp)
                                + LibTiers.getTierConfig(tran.tier).cooldownWindow
                ) {
                    break;
                }

                // Mark this block as verified
                blk.verifiedTransitionId = tid;

                // Update variables
                blockHash = tran.blockHash;
                signalRoot = tran.signalRoot;

                // We consistently return the assignment bond and the proof bond
                // to the actual prover of the transition utilized for block
                // verification. If the actual prover happens to be the block's
                // assigned prover, he will receive both deposits, ultimately
                // earning the proving fee paid during block proposal. In
                // contrast, if the actual prover is different from the block's
                // assigned prover, the assignment bond serves as a reward to
                // the actual prover, while the assigned prover forfeits his
                // assignment bond due to failure to fulfill their commitment.
                uint256 bondToReturn =
                    uint256(tran.proofBond) + blk.assignmentBond;

                // Nevertheless, it's possible for the actual prover to be the
                // same individual or entity as the block's assigned prover.
                // Consequently, we have chosen to grant the actual prover only
                // half of the assignment bond as a reward.
                if (tran.prover != blk.assignedProver) {
                    bondToReturn -= blk.assignmentBond / 2;
                }

                if (tt == address(0)) {
                    tt = resolver.resolve("taiko_token", false);
                }
                TaikoToken(tt).mint(tran.prover, bondToReturn);

                // Note: We exclusively address the bonds linked to the
                // transition used for verification. While there may exist
                // other transitions for this block, we disregard them entirely.
                // The bonds for these other transitions are burned either when
                // the transitions are generated or proven. In such cases, both
                // the provers and contesters of  of those transitions forfeit
                // their bonds.

                emit BlockVerified({
                    blockId: blockId,
                    assignedProver: blk.assignedProver,
                    prover: tran.prover,
                    blockHash: tran.blockHash,
                    signalRoot: tran.signalRoot
                });

                ++blockId;
                ++processed;
            }

            if (processed > 0) {
                uint64 lastVerifiedBlockId = b.lastVerifiedBlockId + processed;

                // Update protocol level state variables
                state.slotB.lastVerifiedBlockId = lastVerifiedBlockId;
                state.slotB.lastVerifiedAt = uint64(block.timestamp);

                if (config.relaySignalRoot) {
                    // Forward the L2's signal root to the signal service to
                    // enable other TaikoL1 deployments, which share the same
                    // signal service, to relay the signal to their respective
                    // TaikoL2 contracts. This enables direct L1-to-L3 and
                    // L2-to-L2 bridging without assets passing an intermediary
                    // layer.
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
