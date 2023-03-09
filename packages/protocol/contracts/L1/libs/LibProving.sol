// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {BlockHeader, LibBlockHeader} from "../../libs/LibBlockHeader.sol";
import {LibRLPWriter} from "../../thirdparty/LibRLPWriter.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {Snippet} from "../../common/IXchainSync.sol";
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
    error L1_CONFLICT_PROOF(Snippet snippet);
    error L1_EVIDENCE_MISMATCH();
    error L1_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_PROOF();
    error L1_NOT_ORACLE_PROVER();

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.ValidBlockEvidence calldata evidence
    ) internal {
        TaikoData.BlockMetadata calldata meta = evidence.meta;

        BlockHeader memory header = evidence.header;
        if (
            evidence.signalRoot == 0 ||
            evidence.prover == address(0) ||
            header.parentHash == 0 ||
            header.gasUsed == 0 ||
            header.beneficiary != meta.beneficiary ||
            header.difficulty != 0 ||
            header.gasLimit != meta.gasLimit + config.anchorTxGasLimit ||
            header.timestamp != meta.timestamp ||
            header.extraData.length != 0 ||
            header.mixHash != meta.mixHash
        ) revert L1_INVALID_EVIDENCE();

        bytes32 instance = _getInstance(
            evidence,
            resolver.resolve("signal_service", false),
            resolver.resolve(config.chainId, "signal_service", false)
        );

        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            blockId: blockId,
            meta: meta,
            parentHash: header.parentHash,
            snippet: Snippet(header.hashBlockHeader(), evidence.signalRoot),
            prover: evidence.prover,
            zkproof: evidence.zkproof,
            instance: instance
        });
    }

    function proveBlockInvalid(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.InvalidBlockEvidence calldata evidence
    ) internal {
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            blockId: blockId,
            meta: evidence.meta,
            parentHash: evidence.parentHash,
            snippet: Snippet(LibUtils.BLOCK_DEADEND_HASH, 0),
            prover: evidence.prover,
            zkproof: evidence.zkproof,
            instance: evidence.meta.txListHash
        });
    }

    function _proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        TaikoData.BlockMetadata calldata meta,
        bytes32 parentHash,
        Snippet memory snippet,
        address prover,
        TaikoData.ZKProof calldata zkproof,
        bytes32 instance
    ) private {
        if (meta.id != blockId) revert L1_ID();

        if (meta.id <= state.latestVerifiedId || meta.id >= state.nextBlockId)
            revert L1_ID();

        if (
            state.getProposedBlock(config.maxNumBlocks, meta.id).metaHash !=
            keccak256(abi.encode(meta))
        ) revert L1_EVIDENCE_MISMATCH();

        bool oracleProving;
        TaikoData.ForkChoice storage fc = state.forkChoices[blockId][
            parentHash
        ];

        if (fc.snippet.blockHash == 0) {
            if (config.enableOracleProver) {
                if (msg.sender != resolver.resolve("oracle_prover", false))
                    revert L1_NOT_ORACLE_PROVER();

                oracleProving = true;
            }

            fc.snippet = snippet;

            if (!oracleProving) {
                fc.prover = prover;
                fc.provenAt = uint64(block.timestamp);
            }
        } else {
            if (
                fc.snippet.blockHash != snippet.blockHash ||
                fc.snippet.signalRoot != snippet.signalRoot
            ) {
                // TODO(daniel): we may allow TaikoToken holders to stake
                // to build an insurance fund. Then once there is a conflicting
                // proof found, we lock the insurance fund, investigate the
                // issue, then decide through a DAO whether we need to use
                // the insurnace fund to cover any identified loss.
                revert L1_CONFLICT_PROOF(fc.snippet);
            }

            if (fc.prover != address(0)) revert L1_ALREADY_PROVEN();

            fc.prover = prover;
            fc.provenAt = uint64(block.timestamp);
        }

        if (!oracleProving && !config.skipZKPVerification) {
            // Do not revert when circuitId is invalid.
            string memory verifierName = string(
                abi.encodePacked(
                    snippet.blockHash == LibUtils.BLOCK_DEADEND_HASH
                        ? "vib_" // verifier for invalid blocks
                        : "vb_", // verifier for valid blocks
                    zkproof.circuitId
                )
            );

            (bool verified, ) = resolver
                .resolve(verifierName, false)
                .staticcall(
                    bytes.concat(
                        bytes16(0),
                        bytes16(instance), // left 16 bytes of the given instance
                        bytes16(0),
                        bytes16(uint128(uint256(instance))), // right 16 bytes of the given instance
                        zkproof.data
                    )
                );

            if (!verified) revert L1_INVALID_PROOF();
        }

        emit BlockProven({id: blockId, parentHash: parentHash, forkChoice: fc});
    }

    function _getInstance(
        TaikoData.ValidBlockEvidence calldata evidence,
        address l1SignalServiceAddress,
        address l2SignalServiceAddress
    ) private pure returns (bytes32) {
        bytes[] memory list = LibBlockHeader.getBlockHeaderRLPItemsList(
            evidence.header,
            7
        );

        uint256 i = list.length;

        unchecked {
            // All L2 related inputs
            list[--i] = LibRLPWriter.writeHash(evidence.meta.txListHash);
            list[--i] = LibRLPWriter.writeHash(
                bytes32(uint256(uint160(l2SignalServiceAddress)))
            );
            list[--i] = LibRLPWriter.writeHash(evidence.signalRoot);

            // All L1 related inputs
            list[--i] = LibRLPWriter.writeHash(bytes32(evidence.meta.l1Height));
            list[--i] = LibRLPWriter.writeHash(evidence.meta.l1Hash);
            list[--i] = LibRLPWriter.writeHash(
                bytes32(uint256(uint160(l1SignalServiceAddress)))
            );

            // Other inputs
            list[--i] = LibRLPWriter.writeAddress(evidence.prover);
        }

        return keccak256(LibRLPWriter.writeList(list));
    }
}
