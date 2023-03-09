// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {Snippet} from "../../common/IXchainSync.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibProving {
    using LibUtils for TaikoData.State;

    // keccak256("taiko")
    bytes32 public constant VERIFIER_OK =
        0x93ac8fdbfc0b0608f9195474a0dd6242f019f5abc3c4e26ad51fefb059cc0177;

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        TaikoData.ForkChoice forkChoice
    );

    error L1_ALREADY_PROVEN();
    error L1_CONFLICT_PROOF(Snippet snippet);
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

        if (fc.snippet.blockHash == 0) {
            address oracleProver = resolver.resolve("oracle_prover", true);
            if (msg.sender == oracleProver) {
                oracleProving = true;
            } else {
                if (oracleProver != address(0)) revert L1_NOT_ORACLE_PROVER();
                fc.prover = evidence.prover;
                fc.provenAt = uint64(block.timestamp);
            }
            fc.snippet = Snippet(evidence.blockHash, evidence.signalRoot);
        } else {
            if (
                fc.snippet.blockHash != evidence.blockHash ||
                fc.snippet.signalRoot != evidence.signalRoot
            ) {
                // TODO(daniel): we may allow TaikoToken holders to stake
                // to build an insurance fund. Then once there is a conflicting
                // proof found, we lock the insurance fund, investigate the
                // issue, then decide through a DAO whether we need to use
                // the insurnace fund to cover any identified loss.
                revert L1_CONFLICT_PROOF(fc.snippet);
            }

            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();

            fc.prover = evidence.prover;
            fc.provenAt = uint64(block.timestamp);
        }

        if (!oracleProving && !config.skipZKPVerification) {
            // Do not revert when circuitId is invalid.
            address verifier = resolver.resolve(
                string.concat(
                    "plonk_verifier",
                    Strings.toString(evidence.zkproof.circuitId)
                ),
                true
            );
            if (verifier == address(0)) revert L1_INVALID_PROOF();

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

                instance = keccak256(
                    bytes.concat(
                        // for checking anchor tx
                        bytes32(uint256(uint160(l1SignalService))),
                        // for checking signalRoot
                        bytes32(uint256(uint160(l2SignalService))),
                        evidence.blockHash,
                        evidence.signalRoot,
                        bytes32(uint256(uint160(evidence.prover))),
                        bytes32(uint256(evidence.meta.id)),
                        bytes32(evidence.meta.l1Height),
                        evidence.meta.l1Hash,
                        evidence.meta.txListHash
                    )
                );
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

        emit BlockProven({
            id: blockId,
            parentHash: evidence.parentHash,
            forkChoice: fc
        });
    }
}
