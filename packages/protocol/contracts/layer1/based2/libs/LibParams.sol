// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibFork2.sol";

library LibParams {
    struct ReadWrite {
        // reads
        function(I.Config memory, uint256) returns (bytes32) getBatchMetaHash;
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        function(I.Config memory, bytes32, uint256) view returns (bytes32, bool)
            loadTransitionMetaHash;
        function(uint64, uint64, bytes32,  bytes memory) view returns (address, address, uint96)
            validateProverAuth;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(address, address, address, uint256) transferFee;
        function(address, uint256) creditBond;
        function(I.Config memory, address, uint256) debitBond;
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
    }

    struct ValidationOutput {
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint48 lastAnchorBlockId;
        uint48 firstBlockId;
        uint48 lastBlockId;
        bytes32[] anchorBlockHashes;
        I.Block[] blocks;
        address proposer; // TODO
        address prover;
        address coinbase; // TODO
    }

    function validateBatch(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentProposeMeta
    )
        internal
        view
        returns (I.Batch memory, ValidationOutput memory)
    {
        ValidationOutput memory output;

        if (_conf.inboxWrapper == address(0)) {
            if (_batch.proposer == address(0)) {
                _batch.proposer = msg.sender;
            } else {
                require(_batch.proposer == msg.sender, CustomProposerNotAllowed());
            }

            // blob hashes are only accepted if the caller is trusted.
            require(_batch.blobs.hashes.length == 0, InvalidBlobParams());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            require(_batch.isForcedInclusion == false, InvalidForcedInclusion());
        } else {
            require(_batch.proposer != address(0), CustomProposerMissing());
            require(msg.sender == _conf.inboxWrapper, NotInboxWrapper());
        }

        // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
        // preconfer address. This will allow us to implement preconfirmation features in L2
        // anchor transactions.
        if (_batch.coinbase == address(0)) {
            _batch.coinbase = _batch.proposer;
        }

        if (_batch.blobs.hashes.length == 0) {
            // this is a normal batch, blobs are created and used in the current batches.
            // firstBlobIndex can be non-zero.
            require(_batch.blobs.numBlobs != 0, BlobNotSpecified());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            _batch.blobs.createdIn = uint48(block.number);
        } else {
            // this is a forced-inclusion batch, blobs were created in early blocks and are used
            // in the current batches
            require(_batch.blobs.createdIn != 0, InvalidBlobCreatedIn());
            require(_batch.blobs.numBlobs == 0, InvalidBlobParams());
            require(_batch.blobs.firstBlobIndex == 0, InvalidBlobParams());
        }
        uint256 nBlocks = _batch.encodedBlocks.length;

        require(nBlocks != 0, BlockNotFound());
        require(nBlocks <= _conf.maxBlocksPerBatch, TooManyBlocks());

        output.blocks = new I.Block[](nBlocks);

        for (uint256 i; i < nBlocks; ++i) {
            output.blocks[i].numTransactions = uint16(uint256(_batch.encodedBlocks[i]));
            output.blocks[i].timeShift = uint8(uint256(_batch.encodedBlocks[i]) >> 16);
            output.blocks[i].anchorBlockId = uint48(uint256(_batch.encodedBlocks[i]) >> 24);
            output.blocks[i].numSignals = uint8(uint256(_batch.encodedBlocks[i]) >> 32 & 0xFF);
        }

        if (_batch.lastBlockTimestamp == 0) {
            _batch.lastBlockTimestamp = uint48(block.timestamp);
        } else {
            require(_batch.lastBlockTimestamp <= block.timestamp, TimestampTooLarge());
        }

        require(output.blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

        uint64 totalShift;
        uint256 signalSlotsIdx;

        for (uint256 i; i < nBlocks; ++i) {
            totalShift += output.blocks[i].timeShift;

            if (output.blocks[i].numSignals == 0) continue;

            require(output.blocks[i].numSignals <= _conf.maxSignalsToReceive, TooManySignals());

            for (uint256 j; j < output.blocks[i].numSignals; ++j) {
                require(
                    _rw.isSignalSent(_conf, _batch.signalSlots[signalSlotsIdx]), SignalNotSent()
                );
                signalSlotsIdx++;
            }
        }

        require(_batch.lastBlockTimestamp >= totalShift, TimestampTooSmall());

        uint256 firstBlockTimestamp = _batch.lastBlockTimestamp - totalShift;

        require(
            firstBlockTimestamp + _conf.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                >= block.timestamp,
            TimestampTooSmall()
        );

        require(
            firstBlockTimestamp >= _parentProposeMeta.lastBlockTimestamp,
            TimestampSmallerThanParent()
        );

        output.anchorBlockHashes = new bytes32[](nBlocks);
        output.lastAnchorBlockId = _parentProposeMeta.lastAnchorBlockId;
        uint256 k;

        bool foundNoneZeroAnchorBlockId;
        for (uint256 i; i < nBlocks; ++i) {
            if (output.blocks[i].hasAnchorBlock) {
                require(k < _batch.anchorBlockIds.length, NotEnoughAnchorIds());
                uint48 anchorBlockId = _batch.anchorBlockIds[k];

                require(anchorBlockId != 0, AnchorIdZero());

                require(
                    foundNoneZeroAnchorBlockId
                        || anchorBlockId + _conf.maxAnchorHeightOffset >= uint48(block.number),
                    AnchorIdTooSmall()
                );

                require(anchorBlockId > output.lastAnchorBlockId, AnchorIdSmallerThanParent());
                output.anchorBlockHashes[k] = _rw.getBlobHash(anchorBlockId);
                require(output.anchorBlockHashes[k] != 0, ZeroAnchorBlockHash());

                foundNoneZeroAnchorBlockId = true;
                output.lastAnchorBlockId = anchorBlockId;
                k++;
            }
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id. Otherwise, delegate this validation to the
        // inboxWrapper contract.
        require(
            msg.sender == _conf.inboxWrapper || foundNoneZeroAnchorBlockId,
            NoAnchorBlockIdWithinThisBatch()
        );

        (output.txsHash, output.blobHashes) = _calculateTxsHash(_rw, _batch.blobs);

        output.firstBlockId = _parentProposeMeta.lastBlockId + 1;
        output.lastBlockId = uint48(output.firstBlockId + nBlocks);

        require(
            LibFork2.isBlocksInCurrentFork(_conf, output.firstBlockId, output.lastBlockId),
            BlocksNotInCurrentFork()
        );
        return (_batch, output);
    }

    function _calculateTxsHash(
        ReadWrite memory _rw,
        I.Blobs memory _blobs
    )
        private
        view
        returns (bytes32 txsHash_, bytes32[] memory blobHashes_)
    {
        unchecked {
            if (_blobs.hashes.length != 0) {
                blobHashes_ = _blobs.hashes;
            } else {
                blobHashes_ = new bytes32[](_blobs.numBlobs);
                for (uint256 i; i < _blobs.numBlobs; ++i) {
                    blobHashes_[i] = _rw.getBlobHash(_blobs.firstBlobIndex + i);
                }
            }

            for (uint256 i; i < blobHashes_.length; ++i) {
                require(blobHashes_[i] != 0, BlobNotFound());
            }
            txsHash_ = keccak256(abi.encode(blobHashes_));
        }
    }
    // --- ERRORs --------------------------------------------------------------------------------

    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BlobNotFound();
    error BlobNotSpecified();
    error BlockNotFound();
    error BlocksNotInCurrentFork();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error FirstBlockTimeShiftNotZero();
    error InvalidBlobCreatedIn();
    error InvalidBlobParams();
    error InvalidForcedInclusion();
    error NotEnoughAnchorIds();
    error NotInboxWrapper();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBlocks();
    error TooManySignals();
    error ZeroAnchorBlockHash();
    error NoAnchorBlockIdWithinThisBatch();
}
