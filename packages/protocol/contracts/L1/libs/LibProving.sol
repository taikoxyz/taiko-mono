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
        address prover,
        uint32 parentGasUsed
    );

    error L1_ALREADY_PROVEN();
    error L1_INVALID_BLOCK_ID();
    error L1_EVIDENCE_MISMATCH();
    error L1_FORK_CHOICE_NOT_FOUND();
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
                || evidence.blockHash == 0
                || evidence.blockHash == evidence.parentHash
                || evidence.signalRoot == 0 || evidence.gasUsed == 0
        ) revert L1_INVALID_EVIDENCE();

        LibUtils.checkBlockId(state, blockId);

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash) {
            revert L1_EVIDENCE_MISMATCH();
        }

        if (evidence.prover == address(1)) {
            // Oracle prover
            if (msg.sender != resolver.resolve("oracle_prover", false)) {
                revert L1_INVALID_ORACLE_PROVER();
            }
        } else {
            // Regular prover
            if (
                evidence.prover != blk.prover
                    && block.timestamp <= blk.proposedAt + config.proofWindow
            ) revert L1_NOT_PROVEABLE();
        }

        TaikoData.ForkChoice storage fc;
        uint16 fcId = LibUtils.getForkChoiceId(
            state, blk, blockId, evidence.parentHash, evidence.parentGasUsed
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
                state.forkChoiceIds[blockId][evidence.parentHash][evidence
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
            revert L1_ALREADY_PROVEN();
        }

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.prover = evidence.prover;
        fc.provenAt = uint64(block.timestamp);
        fc.gasUsed = evidence.gasUsed;

        IProofVerifier(resolver.resolve("proof_verifier", false)).verifyProofs({
            blockId: blockId,
            blockProofs: evidence.proofs,
            instance: getInstance(config, resolver, evidence)
        });

        emit BlockProven({
            blockId: blockId,
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
        uint64 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        internal
        view
        returns (TaikoData.ForkChoice storage fc)
    {
        LibUtils.checkBlockId(state, blockId);

        TaikoData.Block storage blk =
            state.blocks[blockId % config.blockRingBufferSize];

        uint16 fcId = LibUtils.getForkChoiceId(
            state, blk, blockId, parentHash, parentGasUsed
        );
        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();

        fc = blk.forkChoices[fcId];
    }

    function getInstance(
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockEvidence memory evidence
    )
        internal
        view
        returns (bytes32 instance)
    {
        if (evidence.prover != address(1)) return 0;

        uint256[10] memory inputs;

        inputs[0] =
            uint256(uint160(address(resolver.resolve("signal_service", false))));
        inputs[1] = uint256(
            uint160(
                address(
                    resolver.resolve(config.chainId, "signal_service", false)
                )
            )
        );
        inputs[2] = uint256(
            uint160(address(resolver.resolve(config.chainId, "taiko", false)))
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
        assert(instance != 0);
    }
}
