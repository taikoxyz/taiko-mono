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
import { LibTiers } from "./LibTiers.sol";
import { TaikoData } from "../../L1/TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibVerifying {
    using Address for address;
    using LibMath for uint256;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockVerified(
        uint256 indexed blockId,
        address indexed assignedProver,
        address indexed prover,
        bytes32 blockHash
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
        tran.prover = LibUtils.PLACEHOLDER_ADDR;
        tran.timestamp = uint64(block.timestamp);
        tran.tier = LibTiers.TIER_GUARDIAN;

        emit BlockVerified({
            blockId: 0,
            assignedProver: address(0),
            prover: tran.prover,
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
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = blk.verifiedTransitionId;
        if (tid == 0) revert L1_TRANSITION_ID_ZERO();

        bytes32 blockHash = state.transitions[slot][tid].blockHash;

        bytes32 signalRoot;
        uint64 processed;
        address tt; // taiko token address

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
                if (tid == 0) break;

                TaikoData.Transition storage tran = state.transitions[slot][tid];

                if (
                    tran.contester != address(0)
                        || block.timestamp
                            <= uint256(tran.timestamp)
                                + LibTiers.getTierConfig(tran.tier).cooldownWindow
                ) {
                    break;
                }

                blockHash = tran.blockHash;
                signalRoot = tran.signalRoot;
                blk.verifiedTransitionId = tid;

                uint256 bondToReturn =
                    uint256(tran.proofBond) + blk.assignmentBond;

                if (tran.prover != blk.assignedProver) {
                    bondToReturn -= blk.assignmentBond / 2;
                }

                if (tt == address(0)) {
                    tt = resolver.resolve("taiko_token", false);
                }
                TaikoToken(tt).mint(tran.prover, bondToReturn);

                emit BlockVerified(
                    blockId, blk.assignedProver, tran.prover, tran.blockHash
                );

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
