// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IProofVerifier } from "../IProofVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTaikoToken } from "./LibTaikoToken.sol";
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

    error L1_ALREADY_ASSERTED();
    error L1_ALREADY_CHALLANGED();
    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID_MISMATCH();
    error L1_EVIDENCE_MISMATCH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_ORACLE_PROVER();
    error L1_INVALID_PROOF();
    error L1_NOT_CHALLANGED();
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
            evidence.parentHash == 0 || evidence.blockHash == 0
                || evidence.signalRoot == 0
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.SlotB memory b = state.slotB;
        if (blockId <= b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        bool isZkTransition = evidence.prover != address(0);
        bool isZkBlock = blk.transitionBond == 0;

        // If this is an OP transition
        if (!isZkTransition && (isZkBlock || evidence.proofs.length != 0)) {
            revert L1_INVALID_EVIDENCE();
        }

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash) {
            revert L1_EVIDENCE_MISMATCH();
        }

        uint32 tid =
            LibUtils.getTransitionId(state, blk, blockId, evidence.parentHash);

        TaikoData.Transition storage tran;

        if (tid == 0) {
            // This is the first transition for a given parentHash.
            unchecked {
                // Unchecked is safe:
                // - Not realistic 2**32 different fork choice per block will be
                // proven and none of them is valid
                tid = blk.nextTransitionId++;
            }

            tran = state.transitions[blk.blockId][tid];

            if (tid == 1) {
                // We only write the key when tid is 1.
                tran.key = evidence.parentHash;
            } else {
                state.transitionIds[blk.blockId][evidence.parentHash] = tid;
            }

            // A ZK transition is only allowed if this block requires a ZK
            // transition.
            if (!isZkBlock && isZkTransition) {
                revert L1_NOT_CHALLANGED();
            }

            tran.blockHash = evidence.blockHash;
            tran.signalRoot = evidence.signalRoot;
            tran.owner = isZkTransition ? blk.beneficiary : msg.sender;
            tran.createdAt = uint64(block.timestamp);
            tran.challenger = address(0);
            // Keep tran.challengedAt as-is;tran.prover and tran.provenAt will
            // be initialized later in this function.

            if (blk.transitionBond > 0) {
                LibTaikoToken.receiveTaikoToken(
                    state, resolver, tran.owner, blk.transitionBond
                );
            }
        } else {
            tran = state.transitions[blk.blockId][tid];

            if (tran.prover != address(0)) {
                // Amd only when the new ZK transition is a different one
                if (
                    tran.blockHash == evidence.blockHash
                        && tran.signalRoot == evidence.signalRoot
                ) revert L1_SAME_PROOF();

                // Overwriting a ZK transiction, which is only possible by the
                // oracle prover.
                if (evidence.prover != LibUtils.ORACLE_PROVER) {
                    revert L1_ALREADY_PROVEN();
                }

                tran.blockHash = evidence.blockHash;
                tran.signalRoot = evidence.signalRoot;
            } else {
                // The existing transition is an optimistic transition
                if (
                    tran.blockHash == evidence.blockHash
                        && tran.signalRoot == evidence.signalRoot
                ) {
                    // Only ZK transition can overwrite an optmistic transition
                    // with the same blockHash and signalRoot.
                    if (!isZkTransition) {
                        revert L1_ALREADY_ASSERTED();
                    }

                    // Allowed only when the optimistic transition is
                    // challenged.
                    if (tran.challenger != address(0)) {
                        revert L1_NOT_CHALLANGED();
                    }

                    // Clear the challenger but keep the challengedAt timestamp.
                    tran.challenger = address(0);
                } else if (!isZkTransition) {
                    // A different optmistic transition is trying to
                    // overwrite an existing optimitic transition, we need
                    // to make sure the existing transition has not been
                    // challenged yet.
                    if (tran.challenger != address(0)) {
                        revert L1_ALREADY_CHALLANGED();
                    }

                    // Burn some tokens then set the challenger
                    LibTaikoToken.receiveTaikoToken(
                        state, resolver, msg.sender, blk.transitionBond
                    );

                    tran.challenger = msg.sender;
                    tran.challengedAt = uint64(block.timestamp);
                } else {
                    // A ZK transition overwrite an optimistic transition
                    // with different blockHash or signalRoot.
                    // We see this as a challenge followed by a ZK immediately.
                    tran.blockHash = evidence.blockHash;
                    tran.signalRoot = evidence.signalRoot;
                    if (tran.challenger == address(0)) {
                        tran.owner = evidence.prover;
                        // The following line is important to calculate
                        // timeStart below.
                        tran.challengedAt = uint64(block.timestamp);
                    } else {
                        tran.owner = tran.challenger;
                        tran.challenger = address(0);
                    }
                }
            }
        }

        tran.prover = evidence.prover;
        tran.provenAt = uint64(block.timestamp);

        if (isZkTransition) {
            if (evidence.prover == LibUtils.ORACLE_PROVER) {
                // Oracle prover
                if (msg.sender != resolver.resolve("oracle_prover", false)) {
                    revert L1_INVALID_ORACLE_PROVER();
                }
            } else {
                // A block can be proven by a regular prover in the following
                // cases:
                // 1. The actual prover is the assigned prover
                // 2. The block has at least one state transition (which must be
                // from the assigned prover)
                // 3. The block has become open
                uint64 timeStart =
                    isZkBlock ? blk.proposedAt : tran.challengedAt;
                if (
                    evidence.prover != blk.prover && blk.nextTransitionId == 1
                        && block.timestamp <= timeStart + config.proofWindow
                ) revert L1_NOT_PROVEABLE();
            }

            IProofVerifier(resolver.resolve("proof_verifier", false))
                .verifyProofs(blockId, evidence.proofs, getInstance(evidence));
        }

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

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID_MISMATCH();

        uint32 tid = LibUtils.getTransitionId(state, blk, blockId, parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        tran = state.transitions[blockId][tid];
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
