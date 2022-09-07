// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../common/ConfigManager.sol";
import "../../L2/TaikoL2.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibConstants.sol";
import "../../libs/LibTxDecoder.sol";
import "../../libs/LibReceiptDecoder.sol";
import "../../libs/LibZKP.sol";
import "../../thirdparty/Lib_BytesUtils.sol";
import "../../thirdparty/Lib_MerkleTrie.sol";
import "../../thirdparty/Lib_RLPWriter.sol";
import "../LibData.sol";

library LibProve {
    using LibBlockHeader for BlockHeader;
    using LibData for LibData.State;

    struct Evidence {
        LibData.BlockContext context;
        BlockHeader header;
        address prover;
        bytes32 parentHash;
        bytes[] proofs;
    }

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 proposedAt,
        uint64 provenAt,
        address prover
    );

    function proveBlock(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        bytes calldata anchorTx = inputs[1];
        bytes calldata anchorReceipt = inputs[2];

        require(evidence.context.id == blockId, "L1:id");

        require(evidence.proofs.length == 3, "L1:proof:size");
        _proveBlock(s, resolver, evidence, evidence.context, 0);

        LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(anchorTx);

        require(_tx.txType == 0, "L1:anchor:type");
        require(
            _tx.destination == resolver.resolve("taiko_l2"),
            "L1:anchor:dest"
        );
        require(
            _tx.gasLimit == LibConstants.TAIKO_ANCHOR_TX_GAS_LIMIT,
            "L1:anchor:gasLimit"
        );
        require(
            Lib_BytesUtils.equal(
                _tx.data,
                bytes.concat(
                    TaikoL2.anchor.selector,
                    bytes32(evidence.context.anchorHeight),
                    evidence.context.anchorHash
                )
            ),
            "L1:anchor:calldata"
        );

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                anchorTx,
                evidence.proofs[1],
                evidence.header.transactionsRoot
            ),
            "L1:tx:proof"
        );

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);

        require(receipt.status == 1, "L1:receipt:status");

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                anchorReceipt,
                evidence.proofs[2],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );
    }

    function proveBlockInvalid(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 blockId,
        bytes[] calldata inputs
    ) public {
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        LibData.BlockContext memory target = abi.decode(
            inputs[1],
            (LibData.BlockContext)
        );
        bytes calldata invalidateBlockReceipt = inputs[2];

        require(evidence.context.id == blockId, "L1:id");

        require(evidence.proofs.length == 2, "L1:proof:size");
        _proveBlock(
            s,
            resolver,
            evidence,
            target,
            LibConstants.TAIKO_INVALID_BLOCK_DEADEND_HASH
        );

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        LibReceiptDecoder.Log memory log = receipt.logs[0];

        require(
            log.contractAddress == resolver.resolve("taiko_l2"),
            "L1:receipt:addr"
        );
        require(log.data.length == 0, "L1:receipt:data");
        require(
            log.topics.length == 2 &&
                log.topics[0] == LibConstants.TAIKO_INVALIDATE_BLOCK_EVENT &&
                log.topics[1] == target.txListHash,
            "L1:receipt:topics"
        );

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                invalidateBlockReceipt,
                evidence.proofs[1],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );
    }

    function _proveBlock(
        LibData.State storage s,
        AddressResolver resolver,
        Evidence memory evidence,
        LibData.BlockContext memory target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.context.id == target.id, "L1:height");
        require(evidence.prover != address(0), "L1:prover");

        _checkContextPending(s, target);
        _validateHeaderForContext(evidence.header, evidence.context);

        bytes32 blockHash = evidence.header.hashBlockHeader(
            evidence.parentHash
        );

        LibZKP.verify(
            ConfigManager(resolver.resolve("config_manager")).getValue(
                LibConstants.TAIKO_ZKP_VKEY
            ),
            evidence.proofs[0],
            blockHash,
            evidence.prover,
            evidence.context.txListHash
        );

        _markBlockProven(
            s,
            evidence.prover,
            evidence.context,
            evidence.parentHash,
            blockHashOverride == 0 ? blockHash : blockHashOverride
        );
    }

    function _markBlockProven(
        LibData.State storage s,
        address prover,
        LibData.BlockContext memory context,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        LibData.ForkChoice storage fc = s.forkChoices[context.id][parentHash];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
            fc.proposedAt = context.proposedAt;
            fc.provenAt = uint64(block.timestamp);
        } else {
            require(
                fc.blockHash == blockHash &&
                    fc.proposedAt == context.proposedAt,
                "L1:proof:conflict"
            );
            require(
                fc.provers.length <
                    LibConstants.TAIKO_MAX_PROOFS_PER_FORK_CHOICE,
                "L1:proof:tooMany"
            );

            // No uncle proof can take more than 1.5x time the first proof did.
            uint256 delay = fc.provenAt - fc.proposedAt;
            uint256 deadline = fc.provenAt + delay / 2;
            require(block.timestamp <= deadline, "L1:tooLate");

            for (uint256 i = 0; i < fc.provers.length; i++) {
                require(fc.provers[i] != prover, "L1:prover:dup");
            }
        }

        fc.provers.push(prover);

        LibData.PendingBlock storage blk = s.getPendingBlock(context.id);
        if (blk.everProven != uint8(LibData.EverProven.YES)) {
            blk.everProven = uint8(LibData.EverProven.YES);
            // s.numUnprovenBlocks -= 1;
        }

        emit BlockProven(
            context.id,
            parentHash,
            blockHash,
            fc.proposedAt,
            fc.provenAt,
            prover
        );
    }

    function _checkContextPending(
        LibData.State storage s,
        LibData.BlockContext memory context
    ) private view {
        require(
            context.id > s.lastFinalizedId && context.id < s.nextPendingId,
            "L1:ctx:id"
        );
        require(
            LibData.getPendingBlock(s, context.id).contextHash ==
                LibData.hashContext(context),
            "L1:contextHash"
        );
    }

    function _validateHeaderForContext(
        BlockHeader memory header,
        LibData.BlockContext memory context
    ) private pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit ==
                context.gasLimit + LibConstants.TAIKO_ANCHOR_TX_GAS_LIMIT &&
                header.gasUsed > 0 &&
                header.timestamp == context.proposedAt &&
                header.extraData.length == context.extraData.length &&
                keccak256(header.extraData) == keccak256(context.extraData) &&
                header.mixHash == context.mixHash,
            "L1:ctx:headerMismatch"
        );
    }
}
