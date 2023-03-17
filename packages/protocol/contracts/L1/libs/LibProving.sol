// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ChainData} from "../../common/IXchainSync.sol";
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
            meta.id <= state.lastBlockId ||
            meta.id >= state.nextBlockId
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

        TaikoData.ProposedBlock storage proposal = state.proposedBlocks[
            meta.id % config.maxNumBlocks
        ];

        if (proposal.metaHash != LibUtils.hashMetadata(meta))
            revert L1_EVIDENCE_MISMATCH();

        TaikoData.ForkChoice storage fc = state.forkChoices[
            blockId % config.maxNumBlocks
        ][proposal.nextForkChoiceId];

        bool oracleProving;
        if (uint256(fc.chainData.blockHash) <= 1) {
            // 0 or 1 (placeholder) indicate this block has not been proven
            if (config.enableOracleProver) {
                if (msg.sender != resolver.resolve("oracle_prover", false))
                    revert L1_NOT_ORACLE_PROVER();

                oracleProving = true;
            }

            fc.chainData = ChainData(evidence.blockHash, evidence.signalRoot);

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
                fc.chainData.blockHash != evidence.blockHash ||
                fc.chainData.signalRoot != evidence.signalRoot
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

                bytes32[8] memory inputs;
                // for checking anchor tx
                inputs[0] = bytes32(uint256(uint160(l1SignalService)));
                // for checking signalRoot
                inputs[1] = bytes32(uint256(uint160(l2SignalService)));
                inputs[2] = evidence.parentHash;
                inputs[3] = evidence.blockHash;
                inputs[4] = evidence.signalRoot;
                inputs[5] = bytes32(uint256(uint160(evidence.prover)));
                inputs[6] = proposal.metaHash;

                // Circuits shall use this value to check anchor gas limit.
                // Note that this value is not necessary and can be hard-coded
                // in to the circuit code, but if we upgrade the protocol
                // and the gas limit changes, then having it here may be handy.
                inputs[7] = bytes32(config.anchorTxGasLimit);

                assembly {
                    instance := keccak256(inputs, mul(32, 8))
                }
            }

            bytes memory verifierId = abi.encodePacked(
                "verifier_",
                evidence.zkproof.circuitId
            );

            (bool verified, bytes memory ret) = resolver
                .resolve(string(verifierId), false)
                .staticcall(
                    bytes.concat(
                        bytes16(0),
                        bytes16(instance), // left 16 bytes of the given instance
                        bytes16(0),
                        bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                        evidence.zkproof.data
                    )
                );

            if (
                !verified ||
                ret.length != 32 ||
                bytes32(ret) != keccak256("taiko")
            ) revert L1_INVALID_PROOF();
        }

        state.forkChoiceIds[blockId][evidence.parentHash] = proposal
            .nextForkChoiceId;

        unchecked {
            ++proposal.nextForkChoiceId;
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
        uint256 maxNumBlocks,
        uint256 id,
        bytes32 parentHash
    ) internal view returns (TaikoData.ForkChoice storage) {
        if (id <= state.lastBlockId || id >= state.nextBlockId) {
            revert L1_ID();
        }

        TaikoData.ProposedBlock storage proposal = state.proposedBlocks[
            id % maxNumBlocks
        ];
        uint256 fcId = state.forkChoiceIds[id][parentHash];
        if (fcId >= proposal.nextForkChoiceId) revert L1_FORK_CHOICE_ID();

        return state.forkChoices[id % maxNumBlocks][fcId];
    }
}
