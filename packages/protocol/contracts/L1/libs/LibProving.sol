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

    bool private constant FLAG_VALIDATE_ANCHOR_TX_SIGNATURE = true;
    bool private constant FLAG_CHECK_METADATA = true;
    bool private constant FLAG_VALIDATE_HEADER_FOR_METADATA = true;

    bytes32 public constant INVALIDATE_BLOCK_LOG_TOPIC =
        keccak256("BlockInvalidated(bytes32)");

    bytes4 public constant ANCHOR_TX_SELECTOR =
        bytes4(keccak256("anchor(uint256,bytes32)"));

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        address prover,
        uint64 provenAt
    );

    error L1_ALREADY_PROVEN();
    error L1_ANCHOR_CALLDATA();
    error L1_ANCHOR_DEST();
    error L1_ANCHOR_GAS_LIMIT();
    error L1_ANCHOR_RECEIPT_ADDR();
    error L1_ANCHOR_RECEIPT_DATA();
    error L1_ANCHOR_RECEIPT_LOGS();
    error L1_ANCHOR_RECEIPT_PROOF();
    error L1_ANCHOR_RECEIPT_STATUS();
    error L1_ANCHOR_RECEIPT_TOPICS();
    error L1_ANCHOR_SIG_R();
    error L1_ANCHOR_SIG_S();
    error L1_ANCHOR_TX_PROOF();
    error L1_ANCHOR_TYPE();
    error L1_CANNOT_BE_FIRST_PROVER();
    error L1_CONFLICT_PROOF();
    error L1_ID();
    error L1_INPUT_SIZE();
    error L1_META_MISMATCH();
    error L1_NOT_ORACLE_PROVER();
    error L1_PROOF_LENGTH();
    error L1_PROVER();
    error L1_ZKP();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        // Check and decode inputs
        if (inputs.length != 3) revert L1_INPUT_SIZE();
        TaikoData.Evidence memory evidence = abi.decode(
            inputs[0],
            (TaikoData.Evidence)
        );

        // Check evidence
        if (evidence.meta.id != blockId) revert L1_ID();

        if (evidence.proofs.length != 3) revert L1_PROOF_LENGTH();

        IProofVerifier proofVerifier = IProofVerifier(
            resolver.resolve("proof_verifier", false)
        );

        if (config.enableAnchorValidation) {
            _proveAnchorForValidBlock({
                config: config,
                resolver: resolver,
                proofVerifier: proofVerifier,
                evidence: evidence,
                anchorTx: inputs[1],
                anchorReceipt: inputs[2]
            });
        }

        // ZK-prove block and mark block proven to be valid.
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            proofVerifier: proofVerifier,
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
        // Check and decode inputs
        if (inputs.length != 3) revert L1_INPUT_SIZE();
        TaikoData.Evidence memory evidence = abi.decode(
            inputs[0],
            (TaikoData.Evidence)
        );
        TaikoData.BlockMetadata memory target = abi.decode(
            inputs[1],
            (TaikoData.BlockMetadata)
        );

        // Check evidence
        if (evidence.meta.id != blockId) revert L1_ID();
        if (evidence.proofs.length != 2) revert L1_PROOF_LENGTH();

        IProofVerifier proofVerifier = IProofVerifier(
            resolver.resolve("proof_verifier", false)
        );

        if (config.enableAnchorValidation) {
            _proveAnchorForInvalidBlock({
                config: config,
                resolver: resolver,
                target: target,
                proofVerifier: proofVerifier,
                evidence: evidence,
                invalidateBlockReceipt: inputs[2]
            });
        }

        // ZK-prove block and mark block proven as invalid.
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            proofVerifier: proofVerifier,
            evidence: evidence,
            target: target,
            blockHashOverride: LibUtils.BLOCK_DEADEND_HASH
        });
    }

    function _proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        IProofVerifier proofVerifier,
        TaikoData.Evidence memory evidence,
        TaikoData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        if (evidence.meta.id != target.id) revert L1_ID();
        if (evidence.prover == address(0)) revert L1_PROVER();

        if (FLAG_CHECK_METADATA) {
            if (
                target.id <= state.latestVerifiedId ||
                target.id >= state.nextBlockId
            ) revert L1_ID();
            if (
                state
                    .getProposedBlock(config.maxNumBlocks, target.id)
                    .metaHash != target.hashMetadata()
            ) revert L1_META_MISMATCH();
        }

        if (FLAG_VALIDATE_HEADER_FOR_METADATA) {
            if (
                evidence.header.parentHash == 0 ||
                evidence.header.beneficiary != evidence.meta.beneficiary ||
                evidence.header.difficulty != 0 ||
                evidence.header.gasLimit !=
                evidence.meta.gasLimit + config.anchorTxGasLimit ||
                evidence.header.gasUsed == 0 ||
                evidence.header.timestamp != evidence.meta.timestamp ||
                evidence.header.extraData.length !=
                evidence.meta.extraData.length ||
                keccak256(evidence.header.extraData) !=
                keccak256(evidence.meta.extraData) ||
                evidence.header.mixHash != evidence.meta.mixHash
            ) revert L1_META_MISMATCH();
        }

        // For alpha-2 testnet, the network allows any address to submit ZKP,
        // but a special prover can skip ZKP verification if the ZKP is empty.

        bool oracleProving;

        TaikoData.ForkChoice storage fc = state.forkChoices[target.id][
            evidence.header.parentHash
        ];

        bytes32 blockHash = evidence.header.hashBlockHeader();
        bytes32 _blockHash = blockHashOverride == 0
            ? blockHash
            : blockHashOverride;

        if (fc.blockHash == 0) {
            address oracleProver = resolver.resolve("oracle_prover", true);
            if (msg.sender == oracleProver) {
                oracleProving = true;
            } else {
                if (oracleProver != address(0)) revert L1_NOT_ORACLE_PROVER();
                fc.prover = evidence.prover;
                fc.provenAt = uint64(block.timestamp);
            }
            fc.blockHash = _blockHash;
        } else {
            if (fc.blockHash != _blockHash) revert L1_CONFLICT_PROOF();
            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();

            fc.prover = evidence.prover;
            fc.provenAt = uint64(block.timestamp);
        }

        if (oracleProving) {
            // do not verify zkp
        } else {
            bool verified = proofVerifier.verifyZKP({
                verifierId: string(
                    abi.encodePacked("plonk_verifier_", evidence.circuitId)
                ),
                zkproof: evidence.proofs[0],
                instance: _getInstance(evidence)
            });
            if (!verified) revert L1_ZKP();
        }

        emit BlockProven({
            id: target.id,
            parentHash: evidence.header.parentHash,
            blockHash: _blockHash,
            prover: fc.prover,
            provenAt: fc.provenAt
        });
    }

    function _proveAnchorForValidBlock(
        TaikoData.Config memory config,
        AddressResolver resolver,
        IProofVerifier proofVerifier,
        TaikoData.Evidence memory evidence,
        bytes calldata anchorTx,
        bytes calldata anchorReceipt
    ) private view {
        // Check anchor tx is valid
        LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(
            config.chainId,
            anchorTx
        );
        if (_tx.txType != 0) revert L1_ANCHOR_TYPE();
        if (_tx.destination != resolver.resolve(config.chainId, "taiko", false))
            revert L1_ANCHOR_DEST();
        if (_tx.gasLimit != config.anchorTxGasLimit)
            revert L1_ANCHOR_GAS_LIMIT();

        if (FLAG_VALIDATE_ANCHOR_TX_SIGNATURE) {
            // Check anchor tx's signature is valid and deterministic
            if (
                _tx.r != LibAnchorSignature.GX &&
                _tx.r != LibAnchorSignature.GX2
            ) revert L1_ANCHOR_SIG_R();

            if (_tx.r == LibAnchorSignature.GX2) {
                (, , uint256 s) = LibAnchorSignature.signTransaction(
                    LibTxUtils.hashUnsignedTx(config.chainId, _tx),
                    1
                );
                if (s != 0) revert L1_ANCHOR_SIG_S();
            }
        }

        // Check anchor tx's calldata is valid
        if (
            !LibBytesUtils.equal(
                _tx.data,
                bytes.concat(
                    ANCHOR_TX_SELECTOR,
                    bytes32(evidence.meta.l1Height),
                    evidence.meta.l1Hash
                )
            )
        ) revert L1_ANCHOR_CALLDATA();

        // Check anchor tx is the 1st tx in the block
        if (
            !proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: anchorTx,
                proof: evidence.proofs[1],
                root: evidence.header.transactionsRoot
            })
        ) revert L1_ANCHOR_TX_PROOF();
        // Check anchor tx does not throw
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);
        if (receipt.status != 1) revert L1_ANCHOR_RECEIPT_STATUS();
        if (
            !proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: anchorReceipt,
                proof: evidence.proofs[2],
                root: evidence.header.receiptsRoot
            })
        ) revert L1_ANCHOR_RECEIPT_PROOF();
    }

    function _proveAnchorForInvalidBlock(
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadata memory target,
        IProofVerifier proofVerifier,
        TaikoData.Evidence memory evidence,
        bytes calldata invalidateBlockReceipt
    ) private view {
        if (
            !proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: invalidateBlockReceipt,
                proof: evidence.proofs[1],
                root: evidence.header.receiptsRoot
            })
        ) revert L1_ANCHOR_RECEIPT_PROOF();
        // Check the 1st receipt is for an InvalidateBlock tx with
        // a BlockInvalidated event
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);
        if (receipt.status != 1) revert L1_ANCHOR_RECEIPT_STATUS();
        if (receipt.logs.length != 1) revert L1_ANCHOR_RECEIPT_LOGS();
        LibReceiptDecoder.Log memory log = receipt.logs[0];
        if (
            log.contractAddress !=
            resolver.resolve(config.chainId, "taiko", false)
        ) revert L1_ANCHOR_RECEIPT_ADDR();
        if (log.data.length != 0) revert L1_ANCHOR_RECEIPT_DATA();
        if (
            log.topics.length != 2 ||
            log.topics[0] != INVALIDATE_BLOCK_LOG_TOPIC ||
            log.topics[1] != target.txListHash
        ) revert L1_ANCHOR_RECEIPT_TOPICS();
    }

    function _getInstance(
        TaikoData.Evidence memory evidence
    ) internal pure returns (bytes32) {
        bytes[] memory list = LibBlockHeader.getBlockHeaderRLPItemsList(
            evidence.header,
            2
        );

        uint256 len = list.length;
        list[len - 2] = LibRLPWriter.writeAddress(evidence.prover);
        list[len - 1] = LibRLPWriter.writeHash(evidence.meta.txListHash);

        return keccak256(LibRLPWriter.writeList(list));
    }
}
