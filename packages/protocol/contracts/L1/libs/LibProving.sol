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
    error L1_CONFLICT_PROOF();
    error L1_EVIDENCE_MISMATCH();
    error L1_ID();
    error L1_INVALID_PROOF();
    error L1_NONZERO_SIGNAL_ROOT();
    error L1_NOT_ORACLE_PROVER();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockEvidence calldata evidence
    ) internal {
        TaikoData.BlockMetadata calldata meta = evidence.meta;
        if (
            meta.id != blockId ||
            meta.id <= state.latestVerifiedId ||
            meta.id >= state.nextBlockId
        ) revert L1_ID();

        if (
            state.getProposedBlock(config.maxNumBlocks, meta.id).metaHash !=
            keccak256(abi.encode(meta))
        ) revert L1_EVIDENCE_MISMATCH();

        bool oracleProving;
        TaikoData.ForkChoice storage fc = state.forkChoices[blockId][
            evidence.parentHash
        ];

        if (fc.chainData.blockHash == 0) {
            if (config.enableOracleProver) {
                if (msg.sender != resolver.resolve("oracle_prover", false))
                    revert L1_NOT_ORACLE_PROVER();

                oracleProving = true;
            }

            fc.chainData = ChainData(evidence.blockHash, evidence.signalRoot);

            if (!oracleProving) {
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
            if (evidence.blockHash == LibUtils.BLOCK_DEADEND_HASH) {
                if (evidence.signalRoot != 0) revert L1_NONZERO_SIGNAL_ROOT();
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

        emit BlockProven({id: blockId, parentHash: evidence.parentHash});
    }
}
