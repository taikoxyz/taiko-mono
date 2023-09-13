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

    error L1_ALREADY_PROVEN();
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


    event ProverBondReceived(address indexed from, uint64 blockId, uint256 bond);

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

        if (evidence.prover == LibUtils.ORACLE_PROVER) {
            // Oracle prover
            if (msg.sender != resolver.resolve("oracle_prover", false)) {
                revert L1_INVALID_ORACLE_PROVER();
            }
        } else {
            // A block can be proven by a regular prover in the following cases:
            // 1. The actual prover is the assigned prover
            // 2. The block has at least one state transition (which must be
            // from the assigned prover)
            // 3. The block has become open
            if (
                evidence.prover != blk.prover && blk.nextTransitionId == 1
                    && block.timestamp <= blk.proposedAt + config.proofWindow
            ) revert L1_NOT_PROVEABLE();
        }

        if (evidence.tier < blk.currentTier) revert L1_INVALID_TIER();

        uint32 tid = state.getTransitionId(blk, slot, evidence.parentHash);
        TaikoData.Transition storage tran;

        // Skip verification if this is a 'simple' challange
        bool skipVerification = false;

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

            // Very important to reset the tier to the default - started tier.
            tran.tier = blk.currentTier;
        } else if (evidence.prover == LibUtils.ORACLE_PROVER) {
            // This is the branch the oracle prover is trying to overwrite
            // We need to check the previous proof is not the same as the
            // new proof
            tran = state.transitions[slot][tid];
            if (
                tran.blockHash == evidence.blockHash
                    && tran.signalRoot == evidence.signalRoot
            ) revert L1_SAME_PROOF();
        } else {
            // See if this evidence tries to prove the same blockhash and singalRoot
            bool registeredTransition = LibTransition.isTransitionRegisteredAlready(state, slot, evidence.blockHash, evidence.signalRoot);
            
            // We need to distinguish 2 different cases. If this transition is registeredTransition already
            // AND this comes with a currentTier+1 proof -> it is a 'confirmation' otherwise it is an invalid
            // transition hence we have it already.
            if (registeredTransition && evidence.tier <= blk.currentTier) {
                    revert L1_ALREADY_PROVEN();
            }

            // If we are here, this means this is a challange !!
            tran = state.transitions[slot][blk.nextTransitionId++];

            // We have a different "ForkChoice/Transition than previous ones"
            // This means it is a challenge (!?) so:
            // 1. Raise the currentTier of the given block
            blk.currentTier++;

            // If this challange's evidence.tier is lower than the NEW blk.currentTier, it means
            // it just signals that something is 'wrong'. But if this is coming with a higher evidence
            // it signals, it already has the proof coming along with this challange.
            if(evidence.tier < blk.currentTier) {
                LibTransition.challange(state, resolver, blk, tran, evidence);
                skipVerification = true;
            }
            else {
                // Pay challanger+prover bonds because it comes (with a  proof)
                (,uint96 provingBond) = LibTransition.getTierBonds(evidence.tier);
                if (provingBond != 0) {
                    LibTaikoToken.receiveTaikoToken(state, resolver, evidence.prover, provingBond);
                    emit ProverBondReceived(evidence.prover, blk.blockId, provingBond);
                }
            }

        }

        tran.blockHash = evidence.blockHash;
        tran.signalRoot = evidence.signalRoot;
        tran.prover = evidence.prover;
        tran.provenAt = uint64(block.timestamp);

        if (!skipVerification) {
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
        if (evidence.tier == LibTransition.TIER_ID_OPTIMISTIC) {
            require(evidence.proofs.length == 0);
        } else if (evidence.tier == LibTransition.TIER_ID_PSE_ZKEVM) {
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
