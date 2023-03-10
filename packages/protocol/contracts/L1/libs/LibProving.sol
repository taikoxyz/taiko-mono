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

    // keccak256("taiko")
    bytes32 public constant VERIFIER_OK =
        0x93ac8fdbfc0b0608f9195474a0dd6242f019f5abc3c4e26ad51fefb059cc0177;

    event BlockProven(uint256 indexed id, bytes32 parentHash);

    error L1_ALREADY_PROVEN();
    error L1_BLOCK_HASH();
    error L1_CONFLICT_PROOF();
    error L1_EVIDENCE_MISMATCH();
    error L1_FORK_CHOICE_ID();
    error L1_ID();
    error L1_INVALID_PROOF();
    error L1_NONZERO_SIGNAL_ROOT();
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
            meta.id <= state.latestVerifiedId ||
            meta.id >= state.nextBlockId
        ) revert L1_ID();

        // 0 and 1 (placeholder) are not allowed
        if (
            uint256(evidence.parentHash) <= 1 ||
            uint256(evidence.blockHash) <= 1
        ) revert L1_BLOCK_HASH();

        if (
            evidence.blockHash == evidence.parentHash &&
            evidence.signalRoot != bytes32(uint256(1))
        ) revert L1_NONZERO_SIGNAL_ROOT();

        TaikoData.ProposedBlock storage proposal = state.proposedBlocks[
            meta.id % config.maxNumBlocks
        ];

        if (proposal.metaHash != keccak256(abi.encode(meta)))
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
            address verifier = resolver.resolve(
                string(
                    abi.encodePacked("verifier_", evidence.zkproof.circuitId)
                ),
                false
            );

            bytes32 instance;
            if (evidence.blockHash == evidence.parentHash) {
                instance = evidence.meta.txListHash;
            } else {
                address l1SignalService = resolver.resolve(
                    "signal_service",
                    false
                );
                address l2SignalService = resolver.resolve(
                    config.chainId,
                    "signal_service",
                    false
                );

                bytes memory buffer = bytes.concat(
                    // for checking anchor tx
                    bytes32(uint256(uint160(l1SignalService))),
                    // for checking signalRoot
                    bytes32(uint256(uint160(l2SignalService))),
                    evidence.parentHash,
                    evidence.blockHash,
                    evidence.signalRoot
                );
                buffer = bytes.concat(
                    buffer,
                    bytes32(uint256(uint160(evidence.prover))),
                    bytes32(uint256(evidence.meta.id)),
                    bytes32(evidence.meta.l1Height),
                    evidence.meta.l1Hash,
                    evidence.meta.txListHash
                );

                instance = keccak256(buffer);
            }

            (bool verified, bytes memory ret) = verifier.staticcall(
                bytes.concat(
                    bytes16(0),
                    bytes16(instance), // left 16 bytes of the given instance
                    bytes16(0),
                    bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                    evidence.zkproof.data
                )
            );

            if (!verified || ret.length != 32 || bytes32(ret) != VERIFIER_OK)
                revert L1_INVALID_PROOF();
        }

        state.forkChoiceIds[blockId][evidence.parentHash] = proposal
            .nextForkChoiceId;
        unchecked {
            ++proposal.nextForkChoiceId;
        }
        emit BlockProven({id: blockId, parentHash: evidence.parentHash});
    }

    function getForkChoice(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id,
        bytes32 parentHash
    ) internal view returns (TaikoData.ForkChoice storage) {
        if (id <= state.latestVerifiedId || id >= state.nextBlockId) {
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
