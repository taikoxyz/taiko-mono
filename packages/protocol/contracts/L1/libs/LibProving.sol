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
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibProving {
    using LibBlockHeader for BlockHeader;
    using LibUtils for TaikoData.State;

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        TaikoData.ForkChoice forkChoice
    );

    error L1_ALREADY_PROVEN();
    error L1_CONFLICT_PROOF();
    error L1_ID();
    error L1_INVALID_EVIDENCE();
    error L1_NOT_ORACLE_PROVER();
    error L1_TX_LIST_PROOF();
    error L1_BLOCK_PROOF();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes calldata evidenceBytes
    ) internal {
        TaikoData.ValidBlockEvidence memory evidence = abi.decode(
            evidenceBytes,
            (TaikoData.ValidBlockEvidence)
        );

        TaikoData.BlockMetadata memory meta = evidence.meta;
        _checkMetadata(state, config, meta, blockId);

        BlockHeader memory header = evidence.header;
        if (
            evidence.prover == address(0) ||
            header.parentHash == 0 ||
            header.beneficiary != meta.beneficiary ||
            header.difficulty != 0 ||
            header.gasLimit != meta.gasLimit + config.anchorTxGasLimit ||
            header.gasUsed == 0 ||
            header.timestamp != meta.timestamp ||
            header.extraData.length != meta.extraData.length ||
            keccak256(header.extraData) != keccak256(meta.extraData) ||
            header.mixHash != meta.mixHash
        ) revert L1_INVALID_EVIDENCE();

        bool oracleProving = _proveBlock({
            state: state,
            resolver: resolver,
            blockId: blockId,
            parentHash: header.parentHash,
            blockHash: header.hashBlockHeader(),
            prover: evidence.prover
        });

        if (oracleProving || config.skipZKPVerification) return;

        bool verified = _verifyZKProof(
            resolver,
            evidence.zkproof,
            _getInstance(evidence)
        );
        if (!verified) revert L1_BLOCK_PROOF();
    }

    function proveBlockInvalid(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes calldata evidenceBytes
    ) internal {
        TaikoData.InvalidBlockEvidence memory evidence = abi.decode(
            evidenceBytes,
            (TaikoData.InvalidBlockEvidence)
        );

        TaikoData.BlockMetadata memory meta = evidence.meta;
        _checkMetadata(state, config, meta, blockId);

        if (
            LibUtils.hashZKProof(abi.encode(evidence.zkproof)) !=
            meta.txListProofHash
        ) revert L1_TX_LIST_PROOF();

        bool oracleProving = _proveBlock({
            state: state,
            resolver: resolver,
            blockId: blockId,
            parentHash: evidence.parentHash,
            blockHash: LibUtils.BLOCK_DEADEND_HASH,
            prover: msg.sender
        });

        if (oracleProving || config.skipZKPVerification) return;

        bool verified = _verifyZKProof(
            resolver,
            evidence.zkproof,
            meta.txListHash
        );
        if (verified) revert L1_TX_LIST_PROOF();
    }

    function _proveBlock(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        address prover
    ) private returns (bool oracleProving) {
        TaikoData.ForkChoice storage fc = state.forkChoices[blockId][
            parentHash
        ];

        if (fc.blockHash == 0) {
            address oracleProver = resolver.resolve("oracle_prover", true);
            if (msg.sender == oracleProver) {
                oracleProving = true;
            } else {
                if (oracleProver != address(0)) revert L1_NOT_ORACLE_PROVER();
                fc.prover = prover;
                fc.provenAt = uint64(block.timestamp);
            }
            fc.blockHash = blockHash;
        } else {
            if (fc.blockHash != blockHash) revert L1_CONFLICT_PROOF();
            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();

            fc.prover = prover;
            fc.provenAt = uint64(block.timestamp);
        }

        emit BlockProven({id: blockId, parentHash: parentHash, forkChoice: fc});
    }

    function _checkMetadata(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.BlockMetadata memory meta,
        uint256 blockId
    ) private view {
        if (meta.id != blockId) revert L1_ID();

        if (meta.id <= state.latestVerifiedId || meta.id >= state.nextBlockId)
            revert L1_ID();
        if (
            state.getProposedBlock(config.maxNumBlocks, meta.id).metaHash !=
            LibUtils.hashMetadata(meta)
        ) revert L1_INVALID_EVIDENCE();
    }

    function _verifyZKProof(
        AddressResolver resolver,
        TaikoData.ZKProof memory zkproof,
        bytes32 instance
    ) private view returns (bool verified) {
        // Do not revert when circuitId is invalid.
        address verifier = resolver.resolve(
            string.concat("verifier_", Strings.toString(zkproof.circuitId)),
            true
        );
        if (verifier == address(0)) return false;

        (verified, ) = verifier.staticcall(
            bytes.concat(
                bytes16(0),
                bytes16(instance), // left 16 bytes of the given instance
                bytes16(0),
                bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                zkproof.data
            )
        );
    }

    function _getInstance(
        TaikoData.ValidBlockEvidence memory evidence
    ) private pure returns (bytes32) {
        bytes[] memory list = LibBlockHeader.getBlockHeaderRLPItemsList(
            evidence.header,
            5
        );

        uint256 i = list.length;
        list[--i] = LibRLPWriter.writeHash(evidence.meta.txListHash);
        list[--i] = LibRLPWriter.writeHash(evidence.meta.txListProofHash);
        list[--i] = LibRLPWriter.writeHash(evidence.meta.l1Hash);
        list[--i] = LibRLPWriter.writeHash(bytes32(evidence.meta.l1Height));
        list[--i] = LibRLPWriter.writeAddress(evidence.prover);
        return keccak256(LibRLPWriter.writeList(list));
    }
}
