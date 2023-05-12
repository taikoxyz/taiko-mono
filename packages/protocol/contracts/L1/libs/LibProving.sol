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
    error L1_INVALID_SGX_SIGNATURE();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    ) internal {
        if (
            evidence.parentHash == 0 ||
            evidence.blockHash == 0 ||
            evidence.blockHash == evidence.parentHash ||
            evidence.signalRoot == 0 ||
            evidence.gasUsed == 0
        ) revert L1_INVALID_EVIDENCE();

        if (blockId <= state.lastVerifiedBlockId || blockId >= state.numBlocks)
            revert L1_BLOCK_ID();

        TaikoData.Block storage blk = state.blocks[
            blockId % config.ringBufferSize
        ];

        // Check the metadata hash matches the proposed block's. This is
        // necessary to handle chain reorgs.
        if (blk.metaHash != evidence.metaHash)
            revert L1_EVIDENCE_MISMATCH(blk.metaHash, evidence.metaHash);

        TaikoData.ForkChoice storage fc;

        uint256 fcId = LibUtils.getForkChoiceId(
            state,
            blk,
            evidence.parentHash,
            evidence.parentGasUsed
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
                    evidence.parentHash,
                    evidence.parentGasUsed
                );
            } else {
                state.forkChoiceIds[blk.blockId][evidence.parentHash][
                    evidence.parentGasUsed
                ] = fcId;
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

        inputs[3] = uint256(blk.metaHash);
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

        // config.proofTypeEnabled can support 8 different proofs on 8 bits
        for (uint8 index; index < 8; ) {
            if (index == 0 && ((config.proofTypeEnabled >> index) & 1) == 1) {
                // This is the regular ZK proof and required based on the flag
                // in config.proofTypeEnabled
                (bool verified, bytes memory ret) = resolver
                    .resolve(
                        LibUtils.getVerifierName(
                            evidence.blockProofs[index].verifierId
                        ),
                        false
                    )
                    .staticcall(
                        bytes.concat(
                            instance,
                            evidence.blockProofs[index].proof
                        )
                    );

                if (
                    !verified ||
                    ret.length != 32 ||
                    bytes32(ret) != keccak256("taiko")
                ) revert L1_INVALID_PROOF();
            } else if (
                index == 1 && ((config.proofTypeEnabled >> index) & 1) == 1
            ) {
                // This is the SGX signature proof and required based on the flag
                // in config.proofTypeEnabled
                address trustedVerifier = resolver.resolve(
                    LibUtils.getVerifierName(
                        evidence.blockProofs[index].verifierId
                    ),
                    false
                );

                // The signature proof
                bytes memory data = evidence.blockProofs[index].proof;
                uint8 v;
                bytes32 r;
                bytes32 s;
                assembly {
                    // Extract a uint8
                    v := byte(0, mload(add(data, 32)))

                    // Extract the first 32-byte chunk (after the uint8)
                    r := mload(add(data, 33))

                    // Extract the second 32-byte chunk
                    r := mload(add(data, 65))
                }
                if (ecrecover(instance, v, r, s) != trustedVerifier)
                    revert L1_INVALID_SGX_SIGNATURE();
            }

            unchecked {
                ++index;
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
        TaikoData.Block storage blk = state.blocks[
            blockId % config.ringBufferSize
        ];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();

        uint256 fcId = LibUtils.getForkChoiceId(
            state,
            blk,
            parentHash,
            parentGasUsed
        );
        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();
        fc = blk.forkChoices[fcId];
    }
}
