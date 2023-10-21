// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IProofVerifier } from "../IProofVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibProving {
    using LibMath for uint256;

    event BlockProven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover
    );

    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID_MISMATCH();
    error L1_EVIDENCE_MISMATCH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_ORACLE_PROVER();
    error L1_INVALID_PROOF();
    error L1_NOT_PROVEABLE();
    error L1_SAME_PROOF();

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
            evidence.prover == address(0) || evidence.parentHash == 0
                || evidence.blockHash == 0 || evidence.signalRoot == 0
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.SlotB memory b = state.slotB;
        if (blockId <= b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];

        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash) {
            revert L1_EVIDENCE_MISMATCH();
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

        TaikoData.Transition storage tran;

        uint32 tid =
            LibUtils.getTransitionId(state, blk, slot, evidence.parentHash);

        if (tid == 0) {
            tid = blk.nextTransitionId;

            // Unchecked is safe:
            // - Not realistic 2**32 different fork choice per block will be
            // proven and none of them is valid
            unchecked {
                ++blk.nextTransitionId;
            }

            tran = state.transitions[slot][tid];

            if (tid == 1) {
                // We only write the key when tid is 1.
                tran.key = evidence.parentHash;
            } else {
                state.transitionIds[blk.blockId][evidence.parentHash] = tid;
            }
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
            revert L1_ALREADY_PROVEN();
        }

        tran.blockHash = evidence.blockHash;
        tran.signalRoot = evidence.signalRoot;
        tran.prover = evidence.prover;
        tran.provenAt = uint64(block.timestamp);

        IProofVerifier(resolver.resolve("proof_verifier", false)).verifyProofs(
            blockId, evidence.proofs, getInstance(evidence)
        );

        emit BlockProven({
            blockId: blockId,
            parentHash: evidence.parentHash,
            blockHash: evidence.blockHash,
            signalRoot: evidence.signalRoot,
            prover: evidence.prover
        });
    }

    function getTransition(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId,
        bytes32 parentHash
    )
        internal
        view
        returns (TaikoData.Transition storage tran)
    {
        TaikoData.SlotB memory b = state.slotB;
        if (blockId < b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        uint32 tid = LibUtils.getTransitionId(state, blk, slot, parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        tran = state.transitions[slot][tid];
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
}
