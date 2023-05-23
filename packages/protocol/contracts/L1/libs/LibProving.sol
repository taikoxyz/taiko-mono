// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

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
    error L1_INVALID_PROOF_TYPE();
    error L1_ORACLE_PROVER_DISABLED();
    error L1_SAME_PROOF();
    error L1_SYSTEM_PROVER_DISABLED();
    error L1_SYSTEM_PROVER_PROHIBITED();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence,
        TaikoData.Proof memory proof
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

        // Separate between oracle proof (which needs to be overwritten)
        // and non-oracle but system proofs
        address specialProver;
        if (evidence.prover == address(0)) {
            specialProver = resolver.resolve("oracle_prover", true);
            if (specialProver == address(0)) {
                revert L1_ORACLE_PROVER_DISABLED();
            }
        } else if (evidence.prover == address(1)) {
            specialProver = resolver.resolve("system_prover", true);
            if (specialProver == address(0)) {
                revert L1_SYSTEM_PROVER_DISABLED();
            }

            if (
                config.realProofSkipSize <= 1 //
                    || blockId % config.realProofSkipSize == 0
            ) {
                revert L1_SYSTEM_PROVER_PROHIBITED();
            }
        }

        if (specialProver != address(0) && msg.sender != specialProver) {
            if (proof.proofType != TaikoData.ProofType.EOA_SIGNATURE) {
                revert L1_INVALID_PROOF_TYPE();
            } else {
                TaikoData.ProofDataEOASignature memory data =
                    abi.decode(proof.proofData, (TaikoData.ProofDataEOASignature));

                if (
                    specialProver
                        != ecrecover(keccak256(abi.encode(evidence)), data.v, data.r, data.s)
                ) {
                    revert L1_INVALID_PROOF_TYPE();
                }
            }
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
                // solhint-disable-next-line max-line-length
                state.forkChoiceIds[blk.blockId][evidence.parentHash][evidence.parentGasUsed] = fcId;
            }
        } else if (evidence.prover == address(0)) {
            // This is the branch the oracle prover is trying to overwrite
            fc = blk.forkChoices[fcId];
            if (
                fc.blockHash == evidence.blockHash && fc.signalRoot == evidence.signalRoot
                    && fc.gasUsed == evidence.gasUsed
            ) revert L1_SAME_PROOF();
        } else {
            // This is the branch provers trying to overwrite
            fc = blk.forkChoices[fcId];
            if (fc.prover != address(0) && fc.prover != address(1)) {
                revert L1_ALREADY_PROVEN();
            }

            if (
                fc.blockHash != evidence.blockHash || fc.signalRoot != evidence.signalRoot
                    || fc.gasUsed != evidence.gasUsed
            ) revert L1_INVALID_PROOF_OVERWRITE();
        }

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.gasUsed = evidence.gasUsed;
        fc.prover = evidence.prover;

        if (evidence.prover == address(1)) {
            fc.provenAt = uint64(block.timestamp.max(blk.proposedAt + state.proofTimeTarget));
        } else {
            fc.provenAt = uint64(block.timestamp);
        }

        if (evidence.prover != address(0) && evidence.prover != address(1)) {
            uint256[10] memory inputs;

            inputs[0] = uint256(uint160(address(resolver.resolve("signal_service", false))));
            inputs[1] =
            // solhint-disable-next-line max-line-length
             uint256(uint160(address(resolver.resolve(config.chainId, "signal_service", false))));
            inputs[2] = uint256(uint160(address(resolver.resolve(config.chainId, "taiko", false))));

            inputs[3] = uint256(evidence.metaHash);
            inputs[4] = uint256(evidence.parentHash);
            inputs[5] = uint256(evidence.blockHash);
            inputs[6] = uint256(evidence.signalRoot);
            inputs[7] = uint256(evidence.graffiti);
            inputs[8] = (uint256(uint160(evidence.prover)) << 96)
                | (uint256(evidence.parentGasUsed) << 64) | (uint256(evidence.gasUsed) << 32);

            // Also hash configs that will be used by circuits
            inputs[9] = uint256(config.blockMaxGasLimit) << 192
                | uint256(config.maxTransactionsPerBlock) << 128
                | uint256(config.maxBytesPerTxList) << 64;

            bytes32 instance;
            assembly {
                instance := keccak256(inputs, mul(32, 10))
            }

            TaikoData.ProofDataZKP memory data = abi.decode( //
            proof.proofData, (TaikoData.ProofDataZKP));

            (bool verified, bytes memory ret) = resolver.resolve(
                LibUtils.getVerifierName(data.circuitId), false
            ).staticcall(
                bytes.concat(
                    bytes16(0),
                    bytes16(instance), // left 16 bytes of the given instance
                    bytes16(0),
                    bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                    data.zkp
                )
            );

            if (!verified || ret.length != 32 || bytes32(ret) != keccak256("taiko")) {
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
    ) internal view returns (TaikoData.ForkChoice storage fc) {
        TaikoData.Block storage blk = state.blocks[blockId % config.ringBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();

        uint256 fcId = LibUtils.getForkChoiceId(state, blk, parentHash, parentGasUsed);
        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();
        fc = blk.forkChoices[fcId];
    }
}
