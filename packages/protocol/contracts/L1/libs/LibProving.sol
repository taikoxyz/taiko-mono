// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibL1Tokenomics} from "./LibL1Tokenomics.sol";
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

    event ConflictingProof(
        uint64 blockId,
        bytes32 parentHash,
        bytes32 conflictingBlockHash,
        bytes32 conflictingSignalRoot,
        bytes32 blockHash,
        bytes32 signalRoot
    );

    error L1_ALREADY_PROVEN();
    error L1_BLOCK_ID();
    error L1_EVIDENCE_MISMATCH();
    error L1_FORK_CHOICE_NOT_FOUND();
    error L1_INVALID_PROOF();
    error L1_INVALID_EVIDENCE();
    error L1_NOT_ORACLE_PROVER();
    error L1_UNEXPECTED_FORK_CHOICE_ID();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence memory evidence
    ) internal {
        TaikoData.BlockMetadata memory meta = evidence.meta;
        if (
            meta.id != blockId ||
            meta.id <= state.lastVerifiedBlockId ||
            meta.id >= state.numBlocks
        ) revert L1_BLOCK_ID();

        if (
            evidence.parentHash == 0 ||
            evidence.blockHash == 0 ||
            // cannot be the same hash
            evidence.blockHash == evidence.parentHash ||
            evidence.signalRoot == 0 ||
            // prover must not be zero
            evidence.prover == address(0)
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.Block storage blk = state.blocks[
            meta.id % config.ringBufferSize
        ];

        if (blk.metaHash != LibUtils.hashMetadata(meta))
            revert L1_EVIDENCE_MISMATCH();

        TaikoData.ForkChoice storage fc;
        bool oracleProving;

        uint256 fcId = state.forkChoiceIds[blockId][evidence.parentHash];
        if (fcId == 0) {
            fcId = blk.nextForkChoiceId;
            unchecked {
                ++blk.nextForkChoiceId;
            }

            assert(fcId > 0);
            state.forkChoiceIds[blockId][evidence.parentHash] = fcId;
            fc = blk.forkChoices[fcId];
            fc.blockHash = evidence.blockHash;
            fc.signalRoot = evidence.signalRoot;

            if (config.enableOracleProver) {
                if (msg.sender != resolver.resolve("oracle_prover", false))
                    revert L1_NOT_ORACLE_PROVER();

                oracleProving = true;
                // we are reusing storage slots, still need to reset the
                // [provenAt+prover] slot.
                fc.provenAt = uint64(1);
                fc.prover = address(0);
            } else {
                fc.provenAt = uint64(block.timestamp);
                fc.prover = evidence.prover;
            }
        } else {
            assert(fcId < blk.nextForkChoiceId);
            fc = blk.forkChoices[fcId];

            if (
                fc.blockHash != evidence.blockHash ||
                fc.signalRoot != evidence.signalRoot
            ) {
                emit ConflictingProof({
                    blockId: meta.id,
                    parentHash: evidence.parentHash,
                    conflictingBlockHash: evidence.blockHash,
                    conflictingSignalRoot: evidence.signalRoot,
                    blockHash: fc.blockHash,
                    signalRoot: fc.signalRoot
                });
                return;
            }

            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();

            fc.provenAt = uint64(block.timestamp);
            fc.prover = evidence.prover;
        }

        if (!oracleProving && !config.skipZKPVerification) {
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

                uint256[8] memory inputs;
                inputs[0] = uint160(l1SignalService);
                inputs[1] = uint160(l2SignalService);
                inputs[2] = uint160(taikoL2);
                inputs[3] = uint256(evidence.parentHash);
                inputs[4] = uint256(evidence.blockHash);
                inputs[5] = uint256(evidence.signalRoot);
                inputs[6] = uint160(evidence.prover);
                inputs[7] = uint256(blk.metaHash);

                assembly {
                    instance := keccak256(inputs, mul(32, 8))
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
            id: blockId,
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
        bytes32 parentHash
    ) internal view returns (TaikoData.ForkChoice storage) {
        TaikoData.Block storage blk = state.blocks[
            blockId % config.ringBufferSize
        ];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();

        uint256 fcId = state.forkChoiceIds[blockId][parentHash];
        if (fcId == 0) revert L1_FORK_CHOICE_NOT_FOUND();

        assert(fcId < blk.nextForkChoiceId);

        return blk.forkChoices[fcId];
    }
}
