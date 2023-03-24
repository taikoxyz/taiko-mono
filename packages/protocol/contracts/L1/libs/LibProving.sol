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
    error L1_CONFLICT_PROOF();
    error L1_EVIDENCE_MISMATCH();
    error L1_FORK_CHOICE_ID();
    error L1_ID();
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
        ) revert L1_ID();

        if (
            // 0 and 1 (placeholder) are not allowed
            uint256(evidence.parentHash) <= 1 ||
            // 0 and 1 (placeholder) are not allowed
            uint256(evidence.blockHash) <= 1 ||
            // cannot be the same hash
            evidence.blockHash == evidence.parentHash ||
            // 0 and 1 (placeholder) are not allowed
            uint256(evidence.signalRoot) <= 1 ||
            // prover must not be zero
            evidence.prover == address(0)
        ) revert L1_INVALID_EVIDENCE();

        TaikoData.ProposedBlock storage blk = state.proposedBlocks[
            meta.id % config.maxNumProposedBlocks
        ];

        if (blk.metaHash != LibUtils.hashMetadata(meta))
            revert L1_EVIDENCE_MISMATCH();

        uint256 fcId = state.forkChoiceIds[blockId][evidence.parentHash];
        if (fcId == 0) {
            fcId = blk.nextForkChoiceId;
            state.forkChoiceIds[blockId][evidence.parentHash] = fcId;

            unchecked {
                ++blk.nextForkChoiceId;
            }
        } else if (fcId >= blk.nextForkChoiceId) {
            revert L1_UNEXPECTED_FORK_CHOICE_ID(); // this shall not happen
        }

        TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

        bool oracleProving;
        if (uint256(fc.blockHash) <= 1) {
            // 0 or 1 (placeholder) indicate this block has not been proven
            if (config.enableOracleProver) {
                if (msg.sender != resolver.resolve("oracle_prover", false))
                    revert L1_NOT_ORACLE_PROVER();

                oracleProving = true;
            }

            fc.blockHash = evidence.blockHash;
            fc.signalRoot = evidence.signalRoot;

            if (oracleProving) {
                // make sure we reset the prover address to indicate it is
                // proven by the oracle prover
                fc.prover = address(0);
            } else {
                fc.prover = evidence.prover;
                fc.provenAt = uint64(block.timestamp);
            }
        } else {
            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();
            if (
                fc.blockHash != evidence.blockHash ||
                fc.signalRoot != evidence.signalRoot
            ) revert L1_CONFLICT_PROOF();

            fc.prover = evidence.prover;
            fc.provenAt = uint64(block.timestamp);
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

                bytes32[10] memory inputs;
                inputs[0] = bytes32(uint256(uint160(l1SignalService)));
                inputs[1] = bytes32(uint256(uint160(l2SignalService)));
                inputs[2] = bytes32(uint256(uint160(taikoL2)));
                inputs[3] = evidence.parentHash;
                inputs[4] = evidence.blockHash;
                inputs[5] = evidence.signalRoot;
                inputs[6] = bytes32(uint256(uint160(evidence.prover)));
                inputs[7] = bytes32(uint256(evidence.gasUsed)); // TODO(daniel): document this
                inputs[8] = blk.metaHash;

                // Circuits shall use this value to check anchor gas limit.
                // Note that this value is not necessary and can be hard-coded
                // in to the circuit code, but if we upgrade the protocol
                // and the gas limit changes, then having it here may be handy.
                inputs[9] = bytes32(config.anchorTxGasLimit);

                assembly {
                    instance := keccak256(inputs, mul(32, 10))
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
        uint256 maxNumProposedBlocks,
        uint256 id,
        bytes32 parentHash
    ) internal view returns (TaikoData.ForkChoice storage) {
        if (id <= state.lastVerifiedBlockId || id >= state.numBlocks) {
            revert L1_ID();
        }

        TaikoData.ProposedBlock storage blk = state.proposedBlocks[
            id % maxNumProposedBlocks
        ];
        uint256 fcId = state.forkChoiceIds[id][parentHash];
        if (fcId == 0 || fcId >= blk.nextForkChoiceId)
            revert L1_FORK_CHOICE_ID();

        return blk.forkChoices[fcId];
    }
}
