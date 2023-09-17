// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IEvidenceVerifier } from "../verifiers/IEvidenceVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTiers } from "./LibTiers.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from ".././TaikoToken.sol";

library LibProving {
    using LibMath for uint256;

    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_ASSIGNED_PROVER_NOT_ALLOWED();
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_TIER();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_NOT_CONTESTABLE();

    event Proved(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint96 proofBond,
        uint16 tier
    );

    event Contested(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 blockId,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        if (
            evidence.tier == 0 || evidence.parentHash == 0
                || evidence.blockHash == 0 || evidence.signalRoot == 0
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.SlotB memory b = state.slotB;
        if (blockId <= b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];

        if (blk.blockId != blockId || blk.metaHash != evidence.metaHash) {
            revert L1_BLOCK_MISMATCH();
        }

        uint32 tid =
            LibUtils.getTransitionId(state, blk, slot, evidence.parentHash);
        TaikoData.Transition storage tran;

        if (tid == 0) {
            // This is the first transition for a given parentHash.
            unchecked {
                // Unchecked is safe:  Not realistic 2**32 different fork choice
                // per block will be proven and none of them is valid
                tid = blk.nextTransitionId++;
            }

            tran = state.transitions[slot][tid];
            tran.blockHash = 0;
            tran.signalRoot = 0;
            tran.proofBond = 0;
            // Always mark the pre-inited transition as being contested by
            // setting the contester to a nonzero value.
            tran.contester = address(0);
            tran.contestBond = 1; // non-zero to save gas
            tran.timestamp = uint64(block.timestamp);
            tran.tier = 0;

            if (tid == 1) {
                // This is a trick to reduce gas cost for most blocks whose
                // first transition should be the correct one.
                // Writing to `tran` is cheaper as it's in the ring buffer,
                // while writing to `transitionIds` is not.
                tran.key = evidence.parentHash;

                // Mark the prover to be the block's assigned prover so that
                // this block is considered as reserved for the assigned prover
                // to prove. If the assigned prover failed to prove this block
                // within a the proof window, he can no longer prove the first
                // transition.
                tran.prover = blk.assignedProver;
            } else {
                tran.prover = address(0);
                state.transitionIds[blk.blockId][evidence.parentHash] = tid;
            }
        } else {
            tran = state.transitions[slot][tid];
            assert(tran.tier >= blk.minTier);
        }

        if (evidence.tier < blk.minTier || evidence.tier < tran.tier) {
            revert L1_INVALID_TIER();
        }

        TaikoData.TierConfig memory tier = LibTiers.getTierConfig(evidence.tier);
        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));

        {
            address verifier = resolver.resolve(tier.verifierName, true);
            if (verifier != address(0)) {
                IEvidenceVerifier(verifier).verifyProof({
                    blockId: blk.blockId,
                    prover: msg.sender,
                    isContesting: evidence.tier == tran.tier,
                    evidence: evidence
                });
            }
        }

        if (evidence.tier == tran.tier) {
            // To contest the existing transition
            // The block hash or signal root must be different
            if (
                evidence.blockHash == tran.blockHash
                    && evidence.signalRoot == tran.signalRoot
            ) {
                revert L1_ALREADY_PROVED();
            }

            // The existing transiton must not have been contested
            if (tran.contester != address(0)) revert L1_ALREADY_CONTESTED();

            // Contest bond being zero means this tier is not contestable.
            if (tier.contestBond == 0) {
                revert L1_NOT_CONTESTABLE();
            }

            // Burn the contest bond
            tt.burn(msg.sender, tier.contestBond);

            tran.contester = msg.sender;
            tran.contestBond = tier.contestBond;
            tran.timestamp = uint64(block.timestamp);

            emit Contested(
                blk.blockId,
                evidence.parentHash,
                tran.blockHash,
                tran.signalRoot,
                msg.sender,
                tier.contestBond,
                evidence.tier
            );
        } else {
            // To prove or re-approve the transition
            if (
                tran.contester == address(0)
                    && tran.blockHash == evidence.blockHash
                    && tran.signalRoot == evidence.signalRoot
            ) {
                revert L1_ALREADY_PROVED();
            }

            if (tid == 1) {
                // Special handing for the first transition, if the current
                // prover is the assigned prover, we only allow the assigned
                // approve to aprove within the proof window.
                if (
                    tran.prover == blk.assignedProver
                        && msg.sender != blk.assignedProver
                        && block.timestamp <= tran.timestamp + tier.provingWindow
                ) {
                    revert L1_NOT_ASSIGNED_PROVER();
                }
            } else {
                // The assigned prover cannot prove transitions other than the
                // first one.
                if (msg.sender == blk.assignedProver) {
                    revert L1_ASSIGNED_PROVER_NOT_ALLOWED();
                }
            }

            tt.burn(msg.sender, tier.proofBond);

            unchecked {
                uint256 reward;
                if (
                    tran.blockHash == evidence.blockHash
                        && tran.signalRoot == evidence.signalRoot
                ) {
                    // Challenger lost
                    reward = tran.contestBond / 4;
                    tt.mint(tran.prover, reward + tran.proofBond);
                } else {
                    // Challenger won
                    reward = tran.proofBond / 4;
                    if (
                        tran.contester != address(0)
                            && tran.contester != LibUtils.PLACEHOLDER_ADDR
                    ) {
                        tt.mint(tran.contester, reward + tran.contestBond);
                    }
                    tran.blockHash = evidence.blockHash;
                    tran.signalRoot = evidence.signalRoot;
                }

                if (reward != 0) {
                    tt.mint(msg.sender, reward);
                }
            }

            tran.prover = msg.sender;
            tran.proofBond = tier.proofBond;
            tran.contester = address(0);
            tran.contestBond = 1; // non-zero to save gas
            tran.timestamp = uint64(block.timestamp);
            tran.tier = evidence.tier;

            emit Proved(
                blk.blockId,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                msg.sender,
                tier.proofBond,
                evidence.tier
            );
        }
    }
}
