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
import "../../libs/LibConstants.sol";
import "../../libs/LibReceiptDecoder.sol";
import "../../libs/LibTxDecoder.sol";
import "../../libs/LibTxUtils.sol";
import "../../libs/LibZKP.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../../thirdparty/LibMerkleTrie.sol";
import "../../thirdparty/LibRLPWriter.sol";
import "../LibData.sol";
import "../TkoToken.sol";

/// @author dantaik <dan@taiko.xyz>
/// @author david <david@taiko.xyz>
library V1Proving {
    using LibBlockHeader for BlockHeader;
    using LibData for LibData.State;

    struct Evidence {
        LibData.BlockMetadata meta;
        BlockHeader header;
        address prover;
        bytes[] proofs;
    }

    event BlockAuctioned(uint256 indexed id, LibData.Auction auction);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    function getAuctionWindow(
        LibData.State storage s
    ) internal view returns (uint256) {
        if (s.avgProofTime == 0) {
            return LibConstants.K_PROVER_AUCTION_WINDOW_MAX;
        }

        uint256 window = (s.avgProofTime *
            LibConstants.K_PROVER_AUCTION_WINDOW) / 100;
        if (window > LibConstants.K_PROVER_AUCTION_WINDOW_MAX) {
            window = LibConstants.K_PROVER_AUCTION_WINDOW_MAX;
        }
        return window;
    }

    function auctionBlock(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 blockIndex,
        bytes[] calldata inputs,
        uint256 deposit
    ) public {
        require(inputs.length == 1, "L1:inputs:size");
        LibData.BlockMetadata memory meta = abi.decode(
            inputs[0],
            (LibData.BlockMetadata)
        );

        require(blockIndex == meta.id, "L1:blockIndex");
        _checkMetadata(s, meta);

        require(
            block.timestamp <= meta.timestamp + getAuctionWindow(s),
            "L1:auctionEnded"
        );

        LibData.Auction storage auction = s.auctions[blockIndex];

        // TODO(daniel): check the deposit is no smaller than an stats value.
        uint256 minDeposit;
        require(
            deposit >= minDeposit && deposit >= (auction.deposit * 150) / 100,
            "L1:tooSmall"
        );

        TkoToken(resolver.resolve("tko_token")).burn(msg.sender, deposit);

        if (auction.deposit > 0) {
            // Refund the previous winner's deposit
            TkoToken(resolver.resolve("tko_token")).mint(
                auction.prover,
                auction.deposit
            );
        }

        auction.deposit = deposit;
        auction.prover = msg.sender;

        if (auction.expiry == 0) {
            // The expiry is only set once
            uint64 expiry = 30 minutes; // TODO(daniel): use stats
            auction.expiry = expiry;
        }

        emit BlockAuctioned(blockIndex, auction);
    }

    function proveBlock(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 blockIndex,
        bytes[] calldata inputs
    ) public {
        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        bytes calldata anchorTx = inputs[1];
        bytes calldata anchorReceipt = inputs[2];

        LibData.Auction storage auction = s.auctions[blockIndex];

        if (
            auction.prover == address(0) || // not reserved
            auction.prover == msg.sender // reserved by msg.sender
        ) {
            // This block is not reserved or reserved by msg.sender, do nothing,
            // the auction record shall be kept as is.
            //
            // Auction deposit will be refunded when the block is finalized.
        } else if (
            block.timestamp < evidence.meta.timestamp + auction.expiry / 2
        ) {
            // reserved but this prove is very early
            auction.forceRefund = 0;
        } else if (block.timestamp > evidence.meta.timestamp + auction.expiry) {
            // Other prover's auction expired, we delete the auction
            // so refund of deposit is no longer possible.
            auction.deposit = 0;
            auction.prover = address(0);
            auction.expiry = 0;
            auction.forceRefund = 0;
        } else {
            revert("L1:reserved");
        }

        // Check evidence
        require(evidence.meta.id == blockIndex, "L1:id");
        require(evidence.proofs.length == 3, "L1:proof:size");

        // Check anchor tx is valid
        LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(anchorTx);
        require(_tx.txType == 0, "L1:anchor:type");
        require(
            _tx.destination ==
                resolver.resolve(LibConstants.K_CHAIN_ID, "taiko"),
            "L1:anchor:dest"
        );
        require(
            _tx.gasLimit == LibConstants.K_ANCHOR_TX_GAS_LIMIT,
            "L1:anchor:gasLimit"
        );

        // Check anchor tx's signature is valid and deterministic
        _validateAnchorTxSignature(_tx);

        // Check anchor tx's calldata is valid
        require(
            LibBytesUtils.equal(
                _tx.data,
                bytes.concat(
                    LibConstants.K_ANCHOR_TX_SELECTOR,
                    bytes32(evidence.meta.l1Height),
                    evidence.meta.l1Hash
                )
            ),
            "L1:anchor:calldata"
        );

        // Check anchor tx is the 1st tx in the block
        require(
            LibMerkleTrie.verifyInclusionProof(
                LibRLPWriter.writeUint(0),
                anchorTx,
                evidence.proofs[1],
                evidence.header.transactionsRoot
            ),
            "L1:tx:proof"
        );

        // Check anchor tx does not throw
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(
            LibMerkleTrie.verifyInclusionProof(
                LibRLPWriter.writeUint(0),
                anchorReceipt,
                evidence.proofs[2],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );

        // ZK-prove block and mark block proven to be valid.
        _proveBlock(s, resolver, evidence, evidence.meta, 0);
    }

    function proveBlockInvalid(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 blockIndex,
        bytes[] calldata inputs
    ) public {
        // Check and decode inputs
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        LibData.BlockMetadata memory target = abi.decode(
            inputs[1],
            (LibData.BlockMetadata)
        );
        bytes calldata invalidateBlockReceipt = inputs[2];

        // Check evidence
        require(evidence.meta.id == blockIndex, "L1:id");
        require(evidence.proofs.length == 2, "L1:proof:size");

        // Check the 1st receipt is for an InvalidateBlock tx with
        // a BlockInvalidated event
        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);
        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        LibReceiptDecoder.Log memory log = receipt.logs[0];
        require(
            log.contractAddress ==
                resolver.resolve(LibConstants.K_CHAIN_ID, "taiko"),
            "L1:receipt:addr"
        );
        require(log.data.length == 0, "L1:receipt:data");
        require(
            log.topics.length == 2 &&
                log.topics[0] == LibConstants.K_INVALIDATE_BLOCK_LOG_TOPIC &&
                log.topics[1] == target.txListHash,
            "L1:receipt:topics"
        );

        // Check the event is the first one in the throw-away block
        require(
            LibMerkleTrie.verifyInclusionProof(
                LibRLPWriter.writeUint(0),
                invalidateBlockReceipt,
                evidence.proofs[1],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );

        // ZK-prove block and mark block proven as invalid.
        _proveBlock(
            s,
            resolver,
            evidence,
            target,
            LibConstants.K_BLOCK_DEADEND_HASH
        );
    }

    function _proveBlock(
        LibData.State storage s,
        AddressResolver resolver,
        Evidence memory evidence,
        LibData.BlockMetadata memory target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.meta.id == target.id, "L1:height");
        require(evidence.prover != address(0), "L1:prover");

        _checkMetadata(s, target);
        _validateHeaderForMetadata(evidence.header, evidence.meta);

        bytes32 blockHash = evidence.header.hashBlockHeader();

        LibZKP.verify(
            ConfigManager(resolver.resolve("config_manager")).getValue(
                "zk_vkey"
            ),
            evidence.proofs[0],
            blockHash,
            evidence.prover,
            evidence.meta.txListHash
        );

        _markBlockProven(
            s,
            evidence.prover,
            target,
            evidence.header.parentHash,
            blockHashOverride == 0 ? blockHash : blockHashOverride
        );
    }

    function _markBlockProven(
        LibData.State storage s,
        address prover,
        LibData.BlockMetadata memory target,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        LibData.ForkChoice storage fc = s.forkChoices[target.id][parentHash];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
            fc.proposedAt = target.timestamp;
            fc.provenAt = uint64(block.timestamp);
        } else {
            require(
                fc.blockHash == blockHash && fc.proposedAt == target.timestamp,
                "L1:proof:conflict"
            );
            require(
                fc.provers.length < LibConstants.K_MAX_PROOFS_PER_FORK_CHOICE,
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

        emit BlockProven(
            target.id,
            parentHash,
            blockHash,
            fc.proposedAt,
            fc.provenAt,
            prover
        );
    }

    function _validateAnchorTxSignature(
        LibTxDecoder.Tx memory _tx
    ) private view {
        require(
            _tx.r == LibAnchorSignature.GX || _tx.r == LibAnchorSignature.GX2,
            "L1:sig:r"
        );

        if (_tx.r == LibAnchorSignature.GX2) {
            (, , uint256 s) = LibAnchorSignature.signTransaction(
                LibTxUtils.hashUnsignedTx(_tx),
                1
            );
            require(s == 0, "L1:sig:s");
        }
    }

    function _checkMetadata(
        LibData.State storage s,
        LibData.BlockMetadata memory meta
    ) private view {
        require(
            meta.id > s.latestFinalizedId && meta.id < s.nextBlockId,
            "L1:meta:id"
        );
        require(
            LibData.getProposedBlock(s, meta.id).metaHash ==
                LibData.hashMetadata(meta),
            "L1:metaHash"
        );
    }

    function _validateHeaderForMetadata(
        BlockHeader memory header,
        LibData.BlockMetadata memory meta
    ) private pure {
        require(
            header.parentHash != 0 &&
                header.beneficiary == meta.beneficiary &&
                header.difficulty == 0 &&
                header.gasLimit ==
                meta.gasLimit + LibConstants.K_ANCHOR_TX_GAS_LIMIT &&
                header.gasUsed > 0 &&
                header.timestamp == meta.timestamp &&
                header.extraData.length == meta.extraData.length &&
                keccak256(header.extraData) == keccak256(meta.extraData) &&
                header.mixHash == meta.mixHash,
            "L1:meta:headerMismatch"
        );
    }
}
