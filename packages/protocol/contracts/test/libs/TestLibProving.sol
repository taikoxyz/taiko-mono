// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

// This file is an exact copy of LibProving.sol except the implementation of the following methods are empty:

// _checkMetadata
// _validateHeaderForMetadata

// @dev we need to update this when we update LibProving.sol

pragma solidity ^0.8.18;

import "../../L1/libs/LibProving.sol";
import "../../common/AddressResolver.sol";
import "../../libs/LibAnchorSignature.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibReceiptDecoder.sol";
import "../../libs/LibTxUtils.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../../thirdparty/LibRLPWriter.sol";
import "../../L1/libs/LibUtils.sol";

library TestLibProving {
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

            if (!config.enableOracleProver) {
                // If the oracle prover is not enabled
                // we use the first prover's timestamp
                fc.provenAt = uint64(block.timestamp);
            } else {
                // We keep fc.provenAt as 0.
            }
        } else {
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
                    revert L1_CONFLICT_PROOF();
                } else {
                    LibUtils.halt(state, true);
                    return;
                }
            }

            if (config.enableOracleProver && fc.provenAt == 0) {
                // If the oracle prover is enabled, we
                // use the second prover's timestamp.
                fc.provenAt = uint64(block.timestamp);
            }
        }

        fc.provers.push(prover);

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
    ) private view {}

    function _validateHeaderForMetadata(
        TaikoData.Config memory config,
        BlockHeader memory header,
        TaikoData.BlockMetadata memory meta
    ) private pure {}
}
