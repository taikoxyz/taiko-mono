// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IProverPool } from "../ProverPool.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibProving {
    using LibMath for uint256;
    using LibUtils for TaikoData.State;

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint32 parentGasUsed
    );

    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_EVIDENCE_MISMATCH(bytes32 expected, bytes32 actual);
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_PROOF();
    error L1_INVALID_PROOF_OVERWRITE();
    error L1_NOT_PROVEABLE();
    error L1_NOT_SPECIAL_PROVER();
    error L1_SAME_PROOF();
    error L1_UNAUTHORIZED();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        if (
            evidence.prover == address(0)
            //
            || evidence.parentHash == 0
            //
            || evidence.blockHash == 0
            //
            || evidence.blockHash == evidence.parentHash
            //
            || evidence.signalRoot == 0
            //
            || evidence.gasUsed == 0
        ) revert L1_INVALID_EVIDENCE();

        if (blockId <= state.lastVerifiedBlockId || blockId >= state.numBlocks)
        {
            revert L1_BLOCK_ID();
        }

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];

        assert(blk.blockId == blockId);

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash) {
            revert L1_EVIDENCE_MISMATCH(blk.metaHash, evidence.metaHash);
        }

        if (
            evidence.prover != address(1)
            //
            && evidence.prover != blk.assignedProver
            //
            && block.timestamp <= blk.proposedAt + blk.proofWindow
        ) revert L1_NOT_PROVEABLE();

        if (
            evidence.prover == address(1)
                && msg.sender != resolver.resolve("oracle_prover", false)
        ) {
            revert L1_UNAUTHORIZED();
        }

        TaikoData.ForkChoice storage fc;

        uint24 fcId = LibUtils.getForkChoiceId(
            state, blk, evidence.parentHash, evidence.parentGasUsed
        );

        if (fcId == 0) {
            fcId = blk.nextForkChoiceId;

            unchecked {
                ++blk.nextForkChoiceId;
            }

            fc = blk.forkChoices[fcId];

            if (fcId == 1) {
                // We only write the key when fcId is 1.
                fc.key = LibUtils.keyForForkChoice(
                    evidence.parentHash, evidence.parentGasUsed
                );
            } else {
                state.forkChoiceIds[blk.blockId][evidence.parentHash][evidence
                    .parentGasUsed] = fcId;
            }
        } else if (evidence.prover == address(1)) {
            // This is the branch the oracle prover is trying to overwrite
            // We need to check the previous proof is not the same as the
            // new proof
            fc = blk.forkChoices[fcId];
            if (
                fc.blockHash == evidence.blockHash
                    && fc.signalRoot == evidence.signalRoot
                    && fc.gasUsed == evidence.gasUsed
            ) revert L1_SAME_PROOF();
        } else {
            // This is the branch provers trying to overwrite
            fc = blk.forkChoices[fcId];

            // Only oracle proof can be overwritten by regular proof
            if (fc.prover != address(1)) {
                revert L1_ALREADY_PROVEN();
            }

            // The regular proof must be the same as the oracle proof
            if (
                fc.blockHash != evidence.blockHash
                    || fc.signalRoot != evidence.signalRoot
                    || fc.gasUsed != evidence.gasUsed
            ) revert L1_INVALID_PROOF_OVERWRITE();
        }

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.prover = evidence.prover;
        fc.provenAt = uint64(block.timestamp);
        fc.gasUsed = evidence.gasUsed;

        // release the prover
        if (!blk.proverReleased && blk.assignedProver == fc.prover) {
            blk.proverReleased = true;
            IProverPool(resolver.resolve("prover_pool", false)).releaseProver(
                blk.assignedProver
            );
        }

        if (evidence.prover != address(1)) {
            bytes32 instance;
            {
                uint256[10] memory inputs;

                inputs[0] = uint256(
                    uint160(address(resolver.resolve("signal_service", false)))
                );
                inputs[1] = uint256(
                    uint160(
                        address(
                            resolver.resolve(
                                config.chainId, "signal_service", false
                            )
                        )
                    )
                );
                inputs[2] = uint256(
                    uint160(
                        address(
                            resolver.resolve(config.chainId, "taiko", false)
                        )
                    )
                );

                inputs[3] = uint256(evidence.metaHash);
                inputs[4] = uint256(evidence.parentHash);
                inputs[5] = uint256(evidence.blockHash);
                inputs[6] = uint256(evidence.signalRoot);
                inputs[7] = uint256(evidence.graffiti);
                inputs[8] = (uint256(uint160(evidence.prover)) << 96)
                    | (uint256(evidence.parentGasUsed) << 64)
                    | (uint256(evidence.gasUsed) << 32);

                // Also hash configs that will be used by circuits
                inputs[9] = uint256(config.blockMaxGasLimit) << 192
                    | uint256(config.blockMaxTransactions) << 128
                    | uint256(config.blockMaxTxListBytes) << 64;

                assembly {
                    instance := keccak256(inputs, mul(32, 10))
                }
            }

            (bool verified, bytes memory ret) = resolver.resolve(
                LibUtils.getVerifierName(evidence.verifierId), false
            ).staticcall(
                bytes.concat(
                    bytes16(0),
                    bytes16(instance), // left 16 bytes of the given instance
                    bytes16(0),
                    bytes16(uint128(uint256(instance))), // right 16 bytes of
                        // the given instance
                    evidence.proof
                )
            );

            if (
                !verified
                //
                || ret.length != 32
                //
                || bytes32(ret) != keccak256("taiko")
            ) {
                revert L1_INVALID_PROOF();
            }
        }

        emit BlockProven({
            id: blk.blockId,
            parentHash: evidence.parentHash,
            blockHash: evidence.blockHash,
            signalRoot: evidence.signalRoot,
            prover: evidence.prover,
            parentGasUsed: evidence.parentGasUsed
        });
    }

    function getForkChoice(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        internal
        view
        returns (TaikoData.ForkChoice storage fc)
    {
        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();

        uint256 fcId =
            LibUtils.getForkChoiceId(state, blk, parentHash, parentGasUsed);

        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();
        fc = blk.forkChoices[fcId];
    }
}
