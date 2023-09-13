// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IPseProofVerifier } from "../PseProofVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTaikoToken } from "./LibTaikoToken.sol";
import { LibTransition } from "./LibTransition.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibProving {
    using LibMath for uint256;
    using LibTransition for TaikoData.State;
    using LibUtils for TaikoData.State;

    error L1_BLOCK_MISMATCH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_ORACLE_PROVER();
    error L1_INVALID_PROOF();
    error L1_INVALID_TIER();
    error L1_NOT_PROPOSER();
    error L1_NOT_PROVEABLE();
    error L1_SAME_PROOF();

    error L1_TIER_INVALID();

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
            evidence.parentHash == 0 || evidence.blockHash == 0
                || evidence.signalRoot == 0
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

        if (evidence.tier < blk.minTier) revert L1_INVALID_TIER();

        uint32 tid = state.getTransitionId(blk, slot, evidence.parentHash);
        TaikoData.Transition storage tran;

        if (tid == 0) {
            // This is the first transition for a given parentHash.
            unchecked {
                // Unchecked is safe:  Not realistic 2**32 different fork choice
                // per block will be proven and none of them is valid
                tid = blk.nextTransitionId++;
            }

            tran = state.transitions[slot][tid];

            if (tid == 1) {
                // This is a trick to reduce gas cost for most blocks whose
                // first transition should be the correct one.
                // Writing to `tran` is cheaper as it's in the ring buffer,
                // while writing to `transitionIds` is not.
                tran.key = evidence.parentHash;
            } else {
                state.transitionIds[blk.blockId][evidence.parentHash] = tid;
            }

            // Very important to reset the tier to zero.
            tran.tier = 0;
            tran.challengedAt = blk.proposedAt;
        } else {
            tran = state.transitions[slot][tid];
            assert(tran.tier != 0);
        }

        if (state.applyEvidence(resolver, blk, tran, evidence)) {
            _verifyProof(resolver, blk, tran, evidence);
        }
    }

    function getInstance(TaikoData.BlockEvidence memory evidence)
        internal
        pure
        returns (bytes32 instance)
    {
        if (evidence.prover == LibUtils.ORACLE_PROVER) {
            return 0;
        } else {
            return keccak256(
                abi.encode(
                    evidence.metaHash,
                    evidence.parentHash,
                    evidence.blockHash,
                    evidence.signalRoot,
                    evidence.graffiti,
                    evidence.prover
                )
            );
        }
    }

    function _verifyProof(
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran,
        TaikoData.BlockEvidence memory evidence
    )
        private
    {
        if (evidence.tier == LibTransition.TIER_OPTIMISTIC) {
            require(evidence.proofs.length == 0);
        } else if (evidence.tier == LibTransition.TIER_PSE_ZKEVM) {
            if (
                evidence.prover != blk.prover
                    && block.timestamp <= tran.challengedAt + 1 hours
            ) revert L1_NOT_PROVEABLE();

            IPseProofVerifier(resolver.resolve("proof_verifier", false))
                .verifyProofs(blk.blockId, evidence.proofs, getInstance(evidence));
        } else if (evidence.tier == LibTransition.TIER_ORACLE) {
            if (msg.sender != resolver.resolve("oracle_prover", false)) {
                revert L1_INVALID_ORACLE_PROVER();
            }
        } else {
            revert L1_TIER_INVALID();
        }
    }
}
