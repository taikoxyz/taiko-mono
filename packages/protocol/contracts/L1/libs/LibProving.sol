// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {IProofVerifier} from "../IProofVerifier.sol";

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
    error L1_INVALID_PROOFTYPE();
    error L1_NO_AUTH_TO_OVERWRITE_FK();
    error L1_NOT_ALL_REQ_PROOF_VERIFIED();
    error L1_NOT_ENABLED_PROOFTYPE();
    error L1_NOTHING_TO_OVERWRITE();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    ) internal {
        if (
            evidence.parentHash == 0 || evidence.blockHash == 0
                || evidence.blockHash == evidence.parentHash || evidence.signalRoot == 0
                || evidence.gasUsed == 0
        ) revert L1_INVALID_EVIDENCE();

        if (blockId <= state.lastVerifiedBlockId || blockId >= state.numBlocks) {
            revert L1_BLOCK_ID();
        }

        TaikoData.Block storage blk = state.blocks[blockId % config.ringBufferSize];

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash) {
            revert L1_EVIDENCE_MISMATCH(blk.metaHash, evidence.metaHash);
        }

        TaikoData.ForkChoice storage fc;

        uint256 fcId =
            LibUtils.getForkChoiceId(state, blk, evidence.parentHash, evidence.parentGasUsed);

        if (fcId == 0) {
            fcId = blk.nextForkChoiceId;

            unchecked {
                ++blk.nextForkChoiceId;
            }

            fc = blk.forkChoices[fcId];

            if (fcId == 1) {
                // We only write the key when fcId is 1.
                fc.key = LibUtils.keyForForkChoice(evidence.parentHash, evidence.parentGasUsed);
            } else {
                state.forkChoiceIds[blk.blockId][evidence.parentHash][evidence.parentGasUsed] = fcId;
            }
        } else {
            revert L1_ALREADY_PROVEN();
        }

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.gasUsed = evidence.gasUsed;
        fc.prover = evidence.prover;
        fc.provenAt = uint64(block.timestamp);

        // Put together the input for proof and signature verification
        uint256[9] memory inputs;

        inputs[0] = uint256(
            uint160(address(resolver.resolve("signal_service", false)))
        );
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
        inputs[8] =
            (uint256(uint160(evidence.prover)) << 96) |
            (uint256(evidence.parentGasUsed) << 64) |
            (uint256(evidence.gasUsed) << 32);

        bytes32 instance;
        assembly {
            instance := keccak256(inputs, mul(32, 9))
        }

        // Reverts if unsuccessful
        IProofVerifier(resolver.resolve("proof_verifier", false)).verifyProofs(instance, evidence.blockProofs, resolver);

        emit BlockProven({
            id: blk.blockId,
            parentHash: evidence.parentHash,
            blockHash: evidence.blockHash,
            signalRoot: evidence.signalRoot,
            prover: evidence.prover,
            parentGasUsed: evidence.parentGasUsed
        });
    }

    function setForkChoice(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    ) internal {
        if (msg.sender != resolver.resolve("forkchoice_failsafe", false)) {
            revert L1_NO_AUTH_TO_OVERWRITE_FK();
        }

        if (blockId <= state.lastVerifiedBlockId || blockId >= state.numBlocks) {
            revert L1_BLOCK_ID();
        }

        TaikoData.Block storage blk = state.blocks[blockId % config.ringBufferSize];

        // We make it so this will always be the first fork choice
        TaikoData.ForkChoice storage fc = blk.forkChoices[1];

        // In case it was 0 (unproven) - it's fine we prove it here otherwise
        // it does not matter if 2 or 3, only fk idx 1 is valid.
        unchecked {
            ++blk.nextForkChoiceId;
        }

        fc.key = LibUtils.keyForForkChoice(evidence.parentHash, evidence.parentGasUsed);

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.gasUsed = evidence.gasUsed;
        fc.prover = msg.sender; // "special" prover, the failsafe one
        fc.provenAt = blk.proposedAt + state.proofTimeTarget;
    }

    function getForkChoice(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    ) internal view returns (TaikoData.ForkChoice storage fc) {
        TaikoData.Block storage blk = state.blocks[blockId % config.ringBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();

        uint256 fcId = LibUtils.getForkChoiceId(state, blk, parentHash, parentGasUsed);
        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();
        fc = blk.forkChoices[fcId];
    }


}
