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
        uint48 blobsCreatedIn;
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
        (output.proposer, output.coinbase) = validateProposerCoinbase(_conf, _batch);

        output.blocks = _validateBlocks(_conf, _batch);

        _validateTimestamps(_conf, _batch, output.blocks, _parentProposeMeta.lastBlockTimestamp);
        _validateSignals(_conf, _rw, output.blocks, _batch.signalSlots);

        (output.anchorBlockHashes, output.lastAnchorBlockId) = _validateAnchors(
            _conf, _rw, _batch, output.blocks, _parentProposeMeta.lastAnchorBlockId
        );

        output.blobsCreatedIn = _validateBlobs(_conf, _batch);
        (output.txsHash, output.blobHashes) = _calculateTxsHash(_rw, _batch.blobs);

        (output.firstBlockId, output.lastBlockId) =
            _validateBlockRange(_conf, _batch, _parentProposeMeta.lastBlockId);

        return (_batch, output);
    }

    function validateProposerCoinbase(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        internal
        view
        returns (address proposer_, address coinbase_)
    {
        if (_conf.inboxWrapper == address(0)) {
            proposer_ = msg.sender;
        } else {
            require(msg.sender == _conf.inboxWrapper, NotInboxWrapper());
            require(_batch.proposer != address(0), CustomProposerMissing());
            proposer_ = _batch.proposer;
        }

        coinbase_ = _batch.coinbase == address(0) ? proposer_ : _batch.coinbase;
    }

    function _validateBlocks(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        internal
        pure
        returns (I.Block[] memory blocks_)
    {
        uint256 nBlocks_ = _batch.encodedBlocks.length;

        require(nBlocks_ != 0, BlockNotFound());
        require(nBlocks_ <= _conf.maxBlocksPerBatch, TooManyBlocks());

        blocks_ = new I.Block[](nBlocks_);

        for (uint256 i; i < nBlocks_; ++i) {
            blocks_[i].numTransactions = uint16(uint256(_batch.encodedBlocks[i]));
            blocks_[i].timeShift = uint8(uint256(_batch.encodedBlocks[i]) >> 16);
            blocks_[i].anchorBlockId = uint48(uint256(_batch.encodedBlocks[i]) >> 24);
            blocks_[i].numSignals = uint8(uint256(_batch.encodedBlocks[i]) >> 32 & 0xFF);
        }
    }

    function _validateTimestamps(
        I.Config memory _conf,
        I.Batch memory _batch,
        I.Block[] memory _blocks,
        uint48 _parentLastBlockTimestamp
    )
        internal
        view
    {
        require(_batch.lastBlockTimestamp != 0, LastBlockTimestampNotSet());
        require(_batch.lastBlockTimestamp <= block.timestamp, TimestampTooLarge());

        require(_blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

        uint64 totalShift;

        for (uint256 i; i < _blocks.length; ++i) {
            totalShift += _blocks[i].timeShift;
        }

        require(_batch.lastBlockTimestamp >= totalShift, TimestampTooSmall());
        uint256 firstBlockTimestamp_ = _batch.lastBlockTimestamp - totalShift;

        require(
            firstBlockTimestamp_ + _conf.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                >= block.timestamp,
            TimestampTooSmall()
        );

        require(firstBlockTimestamp_ >= _parentLastBlockTimestamp, TimestampSmallerThanParent());
    }

    function _validateSignals(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Block[] memory _blocks,
        bytes32[] memory _signalSlots
    )
        internal
        view
    {
        uint256 k;
        for (uint256 i; i < _blocks.length; ++i) {
            if (_blocks[i].numSignals == 0) continue;

            require(_blocks[i].numSignals <= _conf.maxSignalsToReceive, TooManySignals());

            for (uint256 j; j < _blocks[i].numSignals; ++j) {
                require(_rw.isSignalSent(_conf, _signalSlots[k++]), SignalNotSent());
            }
        }
    }

    function _validateAnchors(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Batch memory _batch,
        I.Block[] memory _blocks,
        uint48 _parentLastAnchorBlockId
    )
        internal
        view
        returns (bytes32[] memory anchorBlockHashes_, uint48 lastAnchorBlockId_)
    {
        anchorBlockHashes_ = new bytes32[](_blocks.length);
        lastAnchorBlockId_ = _parentLastAnchorBlockId;
        uint256 k;

        bool anchorFound;
        for (uint256 i; i < _blocks.length; ++i) {
            if (_blocks[i].hasAnchor) {
                require(k < _batch.anchorBlockIds.length, NotEnoughAnchorIds());

                uint48 anchorBlockId = _batch.anchorBlockIds[k];
                require(anchorBlockId != 0, AnchorIdZero());

                require(
                    anchorFound
                        || anchorBlockId + _conf.maxAnchorHeightOffset >= uint48(block.number),
                    AnchorIdTooSmall()
                );

                require(anchorBlockId > lastAnchorBlockId_, AnchorIdSmallerThanParent());

                anchorBlockHashes_[k] = _rw.getBlobHash(anchorBlockId);
                require(anchorBlockHashes_[k] != 0, ZeroAnchorBlockHash());

                anchorFound = true;
                lastAnchorBlockId_ = anchorBlockId;
                k++;
            }
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id. Otherwise, delegate this validation to the
        // inboxWrapper contract.
        if (_conf.inboxWrapper != address(0)) {
            require(anchorFound, NoAnchorBlockIdWithinThisBatch());
        }
    }

    function _validateBlockRange(
        I.Config memory _conf,
        I.Batch memory _batch,
        uint48 _parentLastBlockId
    )
        internal
        pure
        returns (uint48 firstBlockId_, uint48 lastBlockId_)
    {
        firstBlockId_ = _parentLastBlockId + 1;
        lastBlockId_ = uint48(firstBlockId_ + _batch.encodedBlocks.length);

        require(
            LibFork2.isBlocksInCurrentFork(_conf, firstBlockId_, lastBlockId_),
            BlocksNotInCurrentFork()
        );
    }

    // TODO: redefine blobs related parameters
    function _validateBlobs(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        private
        view
        returns (uint48 blobsCreatedIn_)
    {
        if (_conf.inboxWrapper == address(0)) {
            // blob hashes are only accepted if the caller is trusted.
            require(_batch.blobs.hashes.length == 0, InvalidBlobParams());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            require(_batch.isForcedInclusion == false, InvalidForcedInclusion());
            return uint48(block.number);
        } else if (_batch.blobs.hashes.length == 0) {
            // this is a normal batch, blobs are created and used in the current batches.
            // firstBlobIndex can be non-zero.
            require(_batch.blobs.numBlobs != 0, BlobNotSpecified());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            return uint48(block.number);
        } else {
            // this is a forced-inclusion batch, blobs were created in early blocks and are used
            // in the current batches
            require(_batch.blobs.createdIn != 0, InvalidBlobCreatedIn());
            require(_batch.blobs.numBlobs == 0, InvalidBlobParams());
            require(_batch.blobs.firstBlobIndex == 0, InvalidBlobParams());
            return _batch.blobs.createdIn;
        }
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
    error LastBlockTimestampNotSet();
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
