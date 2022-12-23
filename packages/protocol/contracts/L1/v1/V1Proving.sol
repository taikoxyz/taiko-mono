// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../../common/ConfigManager.sol";
import "../../libs/LibAnchorSignature.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibReceiptDecoder.sol";
import "../../libs/LibTxDecoder.sol";
import "../../libs/LibTxUtils.sol";
import "../../libs/LibZKP.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../../thirdparty/LibMerkleTrie.sol";
import "../../thirdparty/LibRLPWriter.sol";
import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
/// @author david <david@taiko.xyz>
library V1Proving {
    using LibBlockHeader for BlockHeader;
    using V1Utils for LibData.BlockMetadata;
    using V1Utils for LibData.State;

    bytes32 public constant INVALIDATE_BLOCK_LOG_TOPIC =
        keccak256("BlockInvalidated(bytes32)");

    bytes4 public constant ANCHOR_TX_SELECTOR =
        bytes4(keccak256("anchor(uint256,bytes32)"));

    struct Evidence {
        LibData.BlockMetadata meta;
        BlockHeader header;
        address prover;
        bytes[] proofs; // The first zkProofsPerBlock are ZKPs
    }

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    modifier onlyWhitelistedProver(LibData.TentativeState storage tentative) {
        if (tentative.whitelistProvers) {
            require(tentative.provers[msg.sender], "L1:whitelist");
        }
        _;
    }

    function proveBlock(
        LibData.State storage state,
        LibData.TentativeState storage tentative,
        LibData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public onlyWhitelistedProver(tentative) {
        assert(!V1Utils.isHalted(state));

        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        bytes calldata anchorTx = inputs[1];
        bytes calldata anchorReceipt = inputs[2];

        // Check evidence
        require(evidence.meta.id == blockId, "L1:id");
        require(
            evidence.proofs.length == 2 + config.zkProofsPerBlock,
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
                _tx.destination == resolver.resolve(config.chainId, "taiko"),
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

        // Check anchor tx is the 1st tx in the block
        require(
            LibMerkleTrie.verifyInclusionProof({
                _key: LibRLPWriter.writeUint(0),
                _value: anchorTx,
                _proof: evidence.proofs[config.zkProofsPerBlock],
                _root: evidence.header.transactionsRoot
            }),
            "L1:tx:proof"
        );

        // Check anchor tx does not throw

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(
            LibMerkleTrie.verifyInclusionProof({
                _key: LibRLPWriter.writeUint(0),
                _value: anchorReceipt,
                _proof: evidence.proofs[config.zkProofsPerBlock + 1],
                _root: evidence.header.receiptsRoot
            }),
            "L1:receipt:proof"
        );

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
        LibData.State storage state,
        LibData.TentativeState storage tentative,
        LibData.Config memory config,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public onlyWhitelistedProver(tentative) {
        assert(!V1Utils.isHalted(state));

        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        LibData.BlockMetadata memory target = abi.decode(
            inputs[1],
            (LibData.BlockMetadata)
        );
        bytes calldata invalidateBlockReceipt = inputs[2];

        // Check evidence
        require(evidence.meta.id == blockId, "L1:id");
        require(
            evidence.proofs.length == 1 + config.zkProofsPerBlock,
            "L1:proof:size"
        );

        // Check the 1st receipt is for an InvalidateBlock tx with
        // a BlockInvalidated event
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);
        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        LibReceiptDecoder.Log memory log = receipt.logs[0];
        require(
            log.contractAddress == resolver.resolve(config.chainId, "taiko"),
            "L1:receipt:addr"
        );
        require(log.data.length == 0, "L1:receipt:data");
        require(
            log.topics.length == 2 &&
                log.topics[0] == INVALIDATE_BLOCK_LOG_TOPIC &&
                log.topics[1] == target.txListHash,
            "L1:receipt:topics"
        );

        // Check the event is the first one in the throw-away block
        require(
            LibMerkleTrie.verifyInclusionProof({
                _key: LibRLPWriter.writeUint(0),
                _value: invalidateBlockReceipt,
                _proof: evidence.proofs[config.zkProofsPerBlock],
                _root: evidence.header.receiptsRoot
            }),
            "L1:receipt:proof"
        );

        // ZK-prove block and mark block proven as invalid.
        _proveBlock({
            state: state,
            config: config,
            resolver: resolver,
            evidence: evidence,
            target: target,
            blockHashOverride: V1Utils.BLOCK_DEADEND_HASH
        });
    }

    function _proveBlock(
        LibData.State storage state,
        LibData.Config memory config,
        AddressResolver resolver,
        Evidence memory evidence,
        LibData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.meta.id == target.id, "L1:height");
        require(evidence.prover != address(0), "L1:prover");

        _checkMetadata(state, config, target);
        _validateHeaderForMetadata(config, evidence.header, evidence.meta);

        bytes32 blockHash = evidence.header.hashBlockHeader();

        for (uint256 i = 0; i < config.zkProofsPerBlock; i++) {
            LibZKP.verify({
                verificationKey: ConfigManager(
                    resolver.resolve("config_manager")
                ).getValue(string(abi.encodePacked("zk_vkey_", i))),
                zkproof: evidence.proofs[i],
                blockHash: blockHash,
                prover: evidence.prover,
                txListHash: evidence.meta.txListHash
            });
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
        LibData.State storage state,
        LibData.Config memory config,
        address prover,
        LibData.BlockMetadata memory target,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        LibData.ForkChoice storage fc = state.forkChoices[target.id][
            parentHash
        ];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
            fc.provenAt = uint64(block.timestamp);
        } else {
            if (fc.blockHash != blockHash) {
                // We have a problem here: two proofs are both valid but claims
                // the new block has different hashes.
                V1Utils.halt(state, true);
                return;
            }

            require(
                fc.provers.length < config.maxProofsPerForkChoice,
                "L1:proof:tooMany"
            );

            require(
                block.timestamp <
                    V1Utils.uncleProofDeadline(state, config, fc, target.id),
                "L1:tooLate"
            );

            for (uint256 i = 0; i < fc.provers.length; i++) {
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
        LibData.State storage state,
        LibData.Config memory config,
        LibData.BlockMetadata memory meta
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
        LibData.Config memory config,
        BlockHeader memory header,
        LibData.BlockMetadata memory meta
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
