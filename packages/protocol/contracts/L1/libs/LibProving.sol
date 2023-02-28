// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {BlockHeader, LibBlockHeader} from "../../libs/LibBlockHeader.sol";
import {LibRLPWriter} from "../../thirdparty/LibRLPWriter.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibProving {
    using LibBlockHeader for BlockHeader;
    using LibUtils for TaikoData.BlockMetadata;
    using LibUtils for TaikoData.State;

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        address prover,
        uint64 provenAt
    );

    error L1_ALREADY_PROVEN();
    error L1_CANNOT_BE_FIRST_PROVER();
    error L1_CONFLICT_PROOF();
    error L1_ID();
    error L1_INPUT_SIZE();
    error L1_META_MISMATCH();
    error L1_NOT_ORACLE_PROVER();
    error L1_NO_ZK_VERIFIER();
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
        if (inputs.length != 1) revert L1_INPUT_SIZE();
        TaikoData.Evidence memory evidence = abi.decode(
            inputs[0],
            (TaikoData.Evidence)
        );

        // Check evidence
        if (evidence.meta.id != blockId) revert L1_ID();
        if (evidence.zkproof.length == 0) revert L1_PROOF_LENGTH();

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
        // Check and decode inputs
        if (inputs.length != 2) revert L1_INPUT_SIZE();
        TaikoData.Evidence memory evidence = abi.decode(
            inputs[0],
            (TaikoData.Evidence)
        );

        // Check evidence
        if (evidence.meta.id != blockId) revert L1_ID();
        if (evidence.zkproof.length == 0) revert L1_PROOF_LENGTH();

        // ZK-prove block and mark block proven as invalid.
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            evidence: evidence,
            target: abi.decode(inputs[1], (TaikoData.BlockMetadata)),
            blockHashOverride: LibUtils.BLOCK_DEADEND_HASH
        });
    }

    function _proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.Evidence memory evidence,
        TaikoData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        if (evidence.meta.id != target.id) revert L1_ID();
        if (evidence.prover == address(0)) revert L1_PROVER();

        if (!config.skipCheckingMetadata) {
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

        if (!config.skipValidatingHeaderForMetadata) {
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
            bytes32 instance = _getInstance(evidence, blockHashOverride == 0);
            address verifier = resolver.resolve(
                string(abi.encodePacked("verifier_", evidence.circuitId)),
                true
            );
            if (!config.skipZKPVerification) {
                if (verifier == address(0)) revert L1_NO_ZK_VERIFIER();
                (bool verified, ) = verifier.staticcall(
                    bytes.concat(
                        bytes16(0),
                        bytes16(instance), // left 16 bytes of the given instance
                        bytes16(0),
                        bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                        evidence.zkproof
                    )
                );
                if (!verified) revert L1_ZKP();
            }
        }

        emit BlockProven({
            id: target.id,
            parentHash: evidence.header.parentHash,
            blockHash: _blockHash,
            prover: fc.prover,
            provenAt: fc.provenAt
        });
    }

    function _getInstance(
        TaikoData.Evidence memory evidence,
        bool provingValidBlock
    ) internal pure returns (bytes32) {
        bytes[] memory list = LibBlockHeader.getBlockHeaderRLPItemsList(
            evidence.header,
            4
        );

        uint256 len = list.length;
        if (provingValidBlock) {
            // Only zk-proof anchor tx for valid blocks
            list[len - 4] = LibRLPWriter.writeHash(
                bytes32(evidence.meta.l1Height)
            );
            list[len - 3] = LibRLPWriter.writeHash(evidence.meta.l1Hash);
        }
        list[len - 2] = LibRLPWriter.writeAddress(evidence.prover);
        list[len - 1] = LibRLPWriter.writeHash(evidence.meta.txListHash);

        return keccak256(LibRLPWriter.writeList(list));
    }
}
