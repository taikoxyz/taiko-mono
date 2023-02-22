// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IProofVerifier} from "../ProofVerifier.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibAnchorSignature} from "../../libs/LibAnchorSignature.sol";
import {LibBlockHeader, BlockHeader} from "../../libs/LibBlockHeader.sol";
import {LibReceiptDecoder} from "../../libs/LibReceiptDecoder.sol";
import {LibTxDecoder} from "../../libs/LibTxDecoder.sol";
import {LibTxUtils} from "../../libs/LibTxUtils.sol";
import {LibBytesUtils} from "../../thirdparty/LibBytesUtils.sol";
import {LibRLPWriter} from "../../thirdparty/LibRLPWriter.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibProving {
    using LibBlockHeader for BlockHeader;
    using LibUtils for TaikoData.BlockMetadata;
    using LibUtils for TaikoData.State;

    struct Evidence {
        TaikoData.BlockMetadata meta;
        BlockHeader header;
        address prover;
        bytes[] proofs; // The first zkProofsPerBlock are ZKPs,
        // followed by MKPs.
        uint16[] circuits; // The circuits IDs (size === zkProofsPerBlock)
    }

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    error L1_ID();
    error L1_PROVER();
    error L1_TOO_LATE();
    error L1_INPUT_SIZE();
    error L1_PROOF_LENGTH();
    error L1_CONFLICT_PROOF();
    error L1_CIRCUIT_LENGTH();
    error L1_META_MISMATCH();
    error L1_ZKP();
    error L1_TOO_MANY_PROVERS();
    error L1_DUP_PROVERS();
    error L1_NOT_FIRST_PROVER();
    error L1_CANNOT_BE_FIRST_PROVER();
    error L1_HALTED();
    error L1_SIG_PROOF_MISMATCH();
    error L1_BLOCK_ACTUALLY_VALID();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        if (LibUtils.isHalted(state)) revert L1_HALTED();

        // Check and decode inputs
        if (inputs.length != 1) revert L1_INPUT_SIZE();
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));

        // Check evidence
        if (evidence.meta.id != blockId) revert L1_ID();

        if (evidence.proofs.length != 2 + config.zkProofsPerBlock)
            revert L1_PROOF_LENGTH();

        if (evidence.circuits.length != config.zkProofsPerBlock)
            revert L1_CIRCUIT_LENGTH();

        // ZK-prove block and mark block proven to be valid.
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            evidence: evidence,
            target: evidence.meta,
            blockHashOverride: 0
        });
    }

    function proveBlockInvalid(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        assert(!LibUtils.isHalted(state));

        // Check and decode inputs
        if (inputs.length != 4) revert L1_INPUT_SIZE();

        TaikoData.BlockMetadata memory target = abi.decode(
            inputs[0],
            (TaikoData.BlockMetadata)
        );
        if (target.id != blockId) revert L1_ID();
        _checkMetadata({state: state, config: config, meta: target});

        bytes32 circuit = bytes32(inputs[1]);
        bytes calldata zkproof = inputs[2];

        if (
            target.sigProofHash != keccak256(abi.encodePacked(circuit, zkproof))
        ) revert L1_SIG_PROOF_MISMATCH();

        IProofVerifier proofVerifier = IProofVerifier(
            resolver.resolve("proof_verifier", false)
        );
        string memory verifierId = string(
            abi.encodePacked("plonk_verifier_propose", circuit)
        );

        bytes32 parentHash = bytes32(inputs[3]);
        bool skipZKPVerification;

        if (config.enableOracleProver) {
            bytes32 _blockHash = state
            .forkChoices[target.id][parentHash].blockHash;

            if (msg.sender == resolver.resolve("oracle_prover", false)) {
                if (_blockHash != 0) revert L1_NOT_FIRST_PROVER();
                skipZKPVerification = true;
            } else {
                if (_blockHash == 0) revert L1_CANNOT_BE_FIRST_PROVER();
            }
        }

        if (skipZKPVerification) {
            try
                proofVerifier.verifyZKP({
                    verifierId: verifierId,
                    zkproof: zkproof,
                    instance: target.txListHash
                })
            returns (bool verified) {
                if (verified) revert L1_BLOCK_ACTUALLY_VALID();
            } catch {
                // bad proof
            }
        }

        _markBlockProven({
            state: state,
            config: config,
            prover: msg.sender,
            target: target,
            parentHash: parentHash,
            blockHash: LibUtils.BLOCK_DEADEND_HASH
        });
    }

    function _proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        Evidence memory evidence,
        TaikoData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        if (evidence.meta.id != target.id) revert L1_ID();
        if (evidence.prover == address(0)) revert L1_PROVER();

        _checkMetadata({state: state, config: config, meta: target});
        _validateHeaderForMetadata({
            config: config,
            header: evidence.header,
            meta: evidence.meta
        });

        // For alpha-2 testnet, the network allows any address to submit ZKP,
        // but a special prover can skip ZKP verification if the ZKP is empty.

        bool skipZKPVerification;

        // TODO(daniel): remove this special address.
        if (config.enableOracleProver) {
            bytes32 _blockHash = state
            .forkChoices[target.id][evidence.header.parentHash].blockHash;

            if (msg.sender == resolver.resolve("oracle_prover", false)) {
                if (_blockHash != 0) revert L1_NOT_FIRST_PROVER();
                skipZKPVerification = true;
            } else {
                if (_blockHash == 0) revert L1_CANNOT_BE_FIRST_PROVER();
            }
        }

        bytes32 blockHash = evidence.header.hashBlockHeader();

        if (!skipZKPVerification) {
            IProofVerifier proofVerifier = IProofVerifier(
                resolver.resolve("proof_verifier", false)
            );

            for (uint256 i; i < config.zkProofsPerBlock; ++i) {
                bytes32 instance = keccak256(
                    abi.encode(
                        blockHash,
                        evidence.prover,
                        evidence.meta.txListHash
                    )
                );

                bool verified = proofVerifier.verifyZKP({
                    verifierId: string(
                        abi.encodePacked(
                            "plonk_verifier_",
                            i,
                            "_prove_",
                            evidence.circuits[i]
                        )
                    ),
                    zkproof: evidence.proofs[i],
                    instance: instance
                });
                if (!verified) revert L1_ZKP();
            }
        }

        _markBlockProven({
            state: state,
            config: config,
            prover: evidence.prover,
            target: target,
            parentHash: evidence.header.parentHash,
            blockHash: blockHashOverride == 0 ? blockHash : blockHashOverride
        });
    }

    function _markBlockProven(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address prover,
        TaikoData.BlockMetadata memory target,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        TaikoData.ForkChoice storage fc = state.forkChoices[target.id][
            parentHash
        ];

        if (fc.blockHash == 0) {
            // This is the first proof for this block.
            fc.blockHash = blockHash;

            if (config.enableOracleProver) {
                // We keep fc.provenAt as 0 and do NOT
                // push the prover into the prover list.
            } else {
                // If the oracle prover is not enabled
                // we use the first proof's timestamp
                // as the block's provenAt timestamp
                fc.provenAt = uint64(block.timestamp);
                fc.provers.push(prover);
            }
        } else {
            // The block has been proven at least once.
            if (fc.provers.length >= config.maxProofsPerForkChoice)
                revert L1_TOO_MANY_PROVERS();

            if (
                fc.provenAt != 0 &&
                block.timestamp >=
                LibUtils.getUncleProofDeadline({
                    state: state,
                    config: config,
                    fc: fc,
                    blockId: target.id
                })
            ) revert L1_TOO_LATE();

            for (uint256 i; i < fc.provers.length; ++i) {
                if (fc.provers[i] == prover) revert L1_DUP_PROVERS();
            }

            if (fc.blockHash != blockHash) {
                // We have a problem here: two proofs are both valid but claims
                // the new block has different hashes.
                if (config.enableOracleProver) {
                    // We trust the oracle prover so we revert this transaction.
                    revert L1_CONFLICT_PROOF();
                } else {
                    // We do not know which prover to trust so we have to put
                    // the blockchain to a halt.
                    LibUtils.halt(state, true);
                    return;
                }
            }

            if (fc.provenAt == 0) {
                fc.provenAt = uint64(block.timestamp);
            }
            fc.provers.push(prover);
        }

        emit BlockProven({
            id: target.id,
            parentHash: parentHash,
            blockHash: blockHash,
            timestamp: target.timestamp,
            provenAt: fc.provenAt,
            prover: prover
        });
    }

    function _checkMetadata(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.BlockMetadata memory meta
    ) private view {
        if (meta.id <= state.latestVerifiedId || meta.id >= state.nextBlockId)
            revert L1_ID();
        if (
            state.getProposedBlock(config.maxNumBlocks, meta.id).metaHash !=
            meta.hashMetadata()
        ) revert L1_META_MISMATCH();
    }

    function _validateHeaderForMetadata(
        TaikoData.Config memory config,
        BlockHeader memory header,
        TaikoData.BlockMetadata memory meta
    ) private pure {
        if (
            header.parentHash == 0 ||
            header.beneficiary != meta.beneficiary ||
            header.difficulty != 0 ||
            header.gasLimit != meta.gasLimit + config.anchorTxGasLimit ||
            header.gasUsed == 0 ||
            header.timestamp != meta.timestamp ||
            header.extraData.length != meta.extraData.length ||
            keccak256(header.extraData) != keccak256(meta.extraData) ||
            header.mixHash != meta.mixHash
        ) revert L1_META_MISMATCH();
    }
}
