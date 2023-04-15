// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibProving {
    using LibUtils for TaikoData.State;

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover
    );

    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_EVIDENCE_MISMATCH(bytes32 expected, bytes32 actual);
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INVALID_PROOF();
    error L1_INVALID_EVIDENCE();
    error L1_ORACLE_DISABLED();
    error L1_NOT_ORACLE_PROVER();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    ) internal {
        bool isOracleProof = evidence.prover == address(0);

        if (isOracleProof) {
            address oracleProver = resolver.resolve("oracle_prover", true);
            if (oracleProver == address(0)) revert L1_ORACLE_DISABLED();

            if (msg.sender == oracleProver) {
                // Do nothing
            } else if (evidence.zkproof.data.length != 64) {
                revert L1_NOT_ORACLE_PROVER();
            } else {
                uint8 v = uint8(evidence.zkproof.verifierId);
                bytes32 r;
                bytes32 s;
                bytes memory data = evidence.zkproof.data;
                assembly {
                    r := mload(add(data, 32))
                    s := mload(add(data, 64))
                }

                // clear the proof before hasing evidence
                evidence.zkproof.data = new bytes(0);
                evidence.zkproof.verifierId = 0;

                if (
                    oracleProver !=
                    ecrecover(keccak256(abi.encode(evidence)), v, r, s)
                ) revert L1_NOT_ORACLE_PROVER();
            }
        }

        if (
            evidence.meta.id != blockId ||
            evidence.meta.id <= state.lastVerifiedBlockId ||
            evidence.meta.id >= state.numBlocks
        ) revert L1_BLOCK_ID();

        if (
            evidence.parentHash == 0 ||
            evidence.blockHash == 0 ||
            evidence.blockHash == evidence.parentHash ||
            evidence.signalRoot == 0 ||
            evidence.gasUsed == 0
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.Block storage blk = state.blocks[
            evidence.meta.id % config.ringBufferSize
        ];

        {
            // Check the metadata matches the block's metadata. This is very
            // necessary even for the oracle-proof to handle chain reorgs.
            bytes32 _metaHash = LibUtils.hashMetadata(evidence.meta);
            if (blk.metaHash != _metaHash)
                revert L1_EVIDENCE_MISMATCH(blk.metaHash, _metaHash);
        }

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
        } else if (isOracleProof) {
            fc = blk.forkChoices[fcId];
        } else {
            revert L1_ALREADY_PROVEN();
        }

        fc.blockHash = evidence.blockHash;
        fc.signalRoot = evidence.signalRoot;
        fc.gasUsed = evidence.gasUsed;
        fc.provenAt = uint64(block.timestamp);
        fc.prover = evidence.prover;

        if (!isOracleProof && !config.skipZKPVerification) {
            bytes32 instance;
            {
                // otherwise: stack too deep
                address l1SignalService = resolver.resolve(
                    "signal_service",
                    false
                );
                address l2SignalService = resolver.resolve(
                    config.chainId,
                    "signal_service",
                    false
                );
                address taikoL2 = resolver.resolve(
                    config.chainId,
                    "taiko_l2",
                    false
                );

                uint256[9] memory inputs;
                inputs[0] = uint160(l1SignalService);
                inputs[1] = uint160(l2SignalService);
                inputs[2] = uint160(taikoL2);
                inputs[3] = uint256(evidence.parentHash);
                inputs[4] = uint256(evidence.blockHash);
                inputs[5] = uint256(evidence.signalRoot);
                inputs[6] = uint256(evidence.graffiti);
                inputs[7] =
                    (uint256(uint160(evidence.prover)) << 96) |
                    (uint256(evidence.parentGasUsed) << 64) |
                    (uint256(evidence.gasUsed) << 32);
                inputs[8] = uint256(blk.metaHash);

                assembly {
                    instance := keccak256(inputs, mul(32, 9))
                }
            }

            bytes memory verifierId = abi.encodePacked(
                "verifier_",
                evidence.zkproof.verifierId
            );

            (bool verified, bytes memory ret) = resolver
                .resolve(string(verifierId), false)
                .staticcall(bytes.concat(instance, evidence.zkproof.data));

            if (
                !verified ||
                ret.length != 32 ||
                bytes32(ret) != keccak256("taiko")
            ) revert L1_INVALID_PROOF();
        }

        emit BlockProven({
            id: blk.blockId,
            parentHash: evidence.parentHash,
            blockHash: evidence.blockHash,
            signalRoot: evidence.signalRoot,
            prover: evidence.prover
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
