// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import {IProofVerifier} from "../ProofVerifier.sol";
import "../../common/AddressResolver.sol";
import "../../libs/LibAnchorSignature.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibReceiptDecoder.sol";
import "../../libs/LibTxDecoder.sol";
import "../../libs/LibTxUtils.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../../thirdparty/LibRLPWriter.sol";
import "./LibUtils.sol";

/// @author dantaik <dan@taiko.xyz>
/// @author david <david@taiko.xyz>
library LibProving {
    using LibBlockHeader for BlockHeader;
    using LibUtils for TaikoData.BlockMetadata;
    using LibUtils for TaikoData.State;

    struct Evidence {
        TaikoData.BlockMetadata meta;
        BlockHeader header;
        address prover;
        bytes[] proofs; // The first zkProofsPerBlock are ZKPs
    }

    bytes32 public constant INVALIDATE_BLOCK_LOG_TOPIC =
        keccak256("BlockInvalidated(bytes32)");

    bytes4 public constant ANCHOR_TX_SELECTOR =
        bytes4(keccak256("anchor(uint256,bytes32)"));

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        assert(!LibUtils.isHalted(state));

        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        bytes calldata anchorTx = inputs[1];
        bytes calldata anchorReceipt = inputs[2];

        // Check evidence
        require(evidence.meta.id == blockId, "L1:id");

        uint256 zkProofsPerBlock = config.zkProofsPerBlock;
        require(
            evidence.proofs.length == 2 + zkProofsPerBlock,
            "L1:proof:size"
        );

        {
            // Check anchor tx is valid
            LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(
                config.chainId,
                anchorTx
            );
            require(_tx.txType == 0, "L1:anchor:type");
            require(
                _tx.destination ==
                    resolver.resolve(config.chainId, "taiko", false),
                "L1:anchor:dest"
            );
            require(
                _tx.gasLimit == config.anchorTxGasLimit,
                "L1:anchor:gasLimit"
            );

            // Check anchor tx's signature is valid and deterministic
            _validateAnchorTxSignature(config.chainId, _tx);

            // Check anchor tx's calldata is valid
            require(
                LibBytesUtils.equal(
                    _tx.data,
                    bytes.concat(
                        ANCHOR_TX_SELECTOR,
                        bytes32(evidence.meta.l1Height),
                        evidence.meta.l1Hash
                    )
                ),
                "L1:anchor:calldata"
            );
        }

        IProofVerifier proofVerifier = IProofVerifier(
            resolver.resolve("proof_verifier", false)
        );

        // Check anchor tx is the 1st tx in the block
        require(
            proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: anchorTx,
                proof: evidence.proofs[zkProofsPerBlock],
                root: evidence.header.transactionsRoot
            }),
            "L1:tx:proof"
        );

        // Check anchor tx does not throw

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(
            proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: anchorReceipt,
                proof: evidence.proofs[zkProofsPerBlock + 1],
                root: evidence.header.receiptsRoot
            }),
            "L1:receipt:proof"
        );

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
        assert(!LibUtils.isHalted(state));

        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        TaikoData.BlockMetadata memory target = abi.decode(
            inputs[1],
            (TaikoData.BlockMetadata)
        );
        bytes calldata invalidateBlockReceipt = inputs[2];

        // Check evidence
        require(evidence.meta.id == blockId, "L1:id");
        require(
            evidence.proofs.length == 1 + config.zkProofsPerBlock,
            "L1:proof:size"
        );

        IProofVerifier proofVerifier = IProofVerifier(
            resolver.resolve("proof_verifier", false)
        );

        // Check the event is the first one in the throw-away block
        require(
            proofVerifier.verifyMKP({
                key: LibRLPWriter.writeUint(0),
                value: invalidateBlockReceipt,
                proof: evidence.proofs[config.zkProofsPerBlock],
                root: evidence.header.receiptsRoot
            }),
            "L1:receipt:proof"
        );

        // Check the 1st receipt is for an InvalidateBlock tx with
        // a BlockInvalidated event
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);
        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        {
            LibReceiptDecoder.Log memory log = receipt.logs[0];
            require(
                log.contractAddress ==
                    resolver.resolve(config.chainId, "taiko", false),
                "L1:receipt:addr"
            );
            require(log.data.length == 0, "L1:receipt:data");
            require(
                log.topics.length == 2 &&
                    log.topics[0] == INVALIDATE_BLOCK_LOG_TOPIC &&
                    log.topics[1] == target.txListHash,
                "L1:receipt:topics"
            );
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
        Evidence memory evidence,
        TaikoData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.meta.id == target.id, "L1:height");
        require(evidence.prover != address(0), "L1:prover");

        _checkMetadata({state: state, config: config, meta: target});
        _validateHeaderForMetadata({
            config: config,
            header: evidence.header,
            meta: evidence.meta
        });

        bytes32 blockHash = evidence.header.hashBlockHeader();

        // For alpha-2 testnet, the network allows any address to submit ZKP,
        // but a special prover can skip ZKP verification if the ZKP is empty.

        // TODO(daniel): remove this special address.
        address specialProver = resolver.resolve("special_prover", true);

        for (uint256 i = 0; i < config.zkProofsPerBlock; ++i) {
            if (msg.sender == specialProver && evidence.proofs[i].length == 0) {
                // Skip ZKP verification
            } else {
                require(
                    proofVerifier.verifyZKP({
                        verifierId: string(
                            abi.encodePacked("plonk_verifier_", i)
                        ),
                        zkproof: evidence.proofs[i],
                        blockHash: blockHash,
                        prover: evidence.prover,
                        txListHash: evidence.meta.txListHash
                    }),
                    "L1:zkp"
                );
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
            fc.blockHash = blockHash;
            fc.provenAt = uint64(block.timestamp);
        } else {
            if (fc.blockHash != blockHash) {
                // We have a problem here: two proofs are both valid but claims
                // the new block has different hashes.
                LibUtils.halt(state, true);
                return;
            }

            require(
                fc.provers.length < config.maxProofsPerForkChoice,
                "L1:proof:tooMany"
            );

            require(
                block.timestamp <
                    LibUtils.getUncleProofDeadline({
                        state: state,
                        config: config,
                        fc: fc,
                        blockId: target.id
                    }),
                "L1:tooLate"
            );

            for (uint256 i = 0; i < fc.provers.length; ++i) {
                require(fc.provers[i] != prover, "L1:prover:dup");
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

    function _validateAnchorTxSignature(
        uint256 chainId,
        LibTxDecoder.Tx memory _tx
    ) private view {
        require(
            _tx.r == LibAnchorSignature.GX || _tx.r == LibAnchorSignature.GX2,
            "L1:sig:r"
        );

        if (_tx.r == LibAnchorSignature.GX2) {
            (, , uint256 s) = LibAnchorSignature.signTransaction(
                LibTxUtils.hashUnsignedTx(chainId, _tx),
                1
            );
            require(s == 0, "L1:sig:s");
        }
    }

    function _checkMetadata(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.BlockMetadata memory meta
    ) private view {
        require(
            meta.id > state.latestVerifiedId && meta.id < state.nextBlockId,
            "L1:meta:id"
        );
        require(
            state.getProposedBlock(config.maxNumBlocks, meta.id).metaHash ==
                meta.hashMetadata(),
            "L1:metaHash"
        );
    }

    function _validateHeaderForMetadata(
        TaikoData.Config memory config,
        BlockHeader memory header,
        TaikoData.BlockMetadata memory meta
    ) private pure {
        require(
            header.parentHash != 0 &&
                header.beneficiary == meta.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit == meta.gasLimit + config.anchorTxGasLimit &&
                header.gasUsed > 0 &&
                header.timestamp == meta.timestamp &&
                header.extraData.length == meta.extraData.length &&
                keccak256(header.extraData) == keccak256(meta.extraData) &&
                header.mixHash == meta.mixHash,
            "L1:meta:headerMismatch"
        );
    }
}
