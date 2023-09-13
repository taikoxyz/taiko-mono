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
import { LibTransition } from "./LibTransition.sol";
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
    event BondReturned(address indexed to, uint64 blockId, uint256 bond);
    event BondRewarded(address indexed to, uint64 blockId, uint256 bond);

    error L1_BLOCK_MISMATCH();
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
                || config.proofWindow == 0 || config.proverBond == 0
                || config.proverBond < 10 * config.proposerRewardPerSecond
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
        tran.prover = LibUtils.ORACLE_PROVER;
        tran.provenAt = uint64(block.timestamp);
        tran.challengedAt = tran.provenAt;
        tran.tier = LibTransition.TIER_ORACLE;

        emit BlockVerified({
            blockId: 0,
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
        if (tid == 0) revert L1_UNEXPECTED_TRANSITION_ID();

        bytes32 blockHash = state.transitions[slot][tid].blockHash;

        bytes32 signalRoot;
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
                if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

                tid = LibUtils.getTransitionId(state, blk, slot, blockHash);
                if (tid == 0) break;

                TaikoData.Transition storage tran = state.transitions[slot][tid];

                // if (tran.prover != address(0)) {
                //     // Use a ZK transition to verify the block
                //     uint256 cooldownPeriod = tran.prover
                //         == LibUtils.ORACLE_PROVER
                //         ? config.proofOracleCooldown
                //         : config.proofRegularCooldown;
                //     if (block.timestamp <= tran.timestamp + cooldownPeriod) {
                //         break;
                //     }
                // } else {
                //     // Use an optmistic transition to verify the block.

                //     // If this block requires an ZK transition, or this
                //     // transition is being challenged or is not mature, we
                // have
                //     // to wait.
                //     if (
                //         blk.optimisticBond == 0 // this is a ZK block
                //             || tran.challenger != address(0) // being
                // challenged
                //             || block.timestamp
                //                 <= tran.timestamp + config.optimisticCooldown
                //     ) {
                //         break;
                //     }
                // }

                blockHash = tran.blockHash;
                signalRoot = tran.signalRoot;
                blk.verifiedTransitionId = tid;

                _processTokenomics(state, config, resolver, blk, tran);
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

    function _processTokenomics(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran
    )
        private
    {
        // uint256 extraReward =
        //     tran.challenger == address(0) ? 0 : blk.optimisticBond / 4;

        // // The tran.prover always receives block reward
        // state.taikoTokenBalances[tran.prover] += _mintBlockReward(
        //     state, config, resolver, blk
        // ) + blk.optimisticBond + extraReward;

        // if (
        //     tran.prover == address(0) || tran.prover ==
        // LibUtils.ORACLE_PROVER
        //         || tran.prover == blk.prover
        // ) {
        //     // Return bond to the assigned prover
        //     state.taikoTokenBalances[blk.prover] += blk.proverBond +
        // extraReward;
        // } else if (tran.prover != address(0)) {
        //     // Reward 1/4 bond to the actual prover
        //     state.taikoTokenBalances[tran.prover] +=
        //         blk.proverBond / 4 + extraReward;
        // }
    }

    function _mintBlockReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.Block storage blk
    )
        private
        returns (uint256 reward)
    {
        if (
            config.proposerRewardPerSecond == 0 || config.proposerRewardMax == 0
        ) return 0;

        // Unchecked is safe:
        // - block.timestamp is always greater than block.proposedAt (proposed
        // in the past)
        // - 1x state.taikoTokenBalances[addr] uint256 could theoretically store
        // the whole token supply
        uint64 blockTime;
        unchecked {
            blockTime = blk.proposedAt
                - state.blocks[(blk.blockId - 1) % config.blockRingBufferSize]
                    .proposedAt;
        }
        if (blockTime == 0) return 0;

        reward = (config.proposerRewardPerSecond * blockTime).min(
            config.proposerRewardMax
        );

        // Reward must be minted
        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));
        tt.mint(address(this), reward);
    }
}
