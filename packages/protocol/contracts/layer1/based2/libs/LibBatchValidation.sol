// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibForks.sol";
import "./LibDataUtils.sol";

/// @title LibBatchValidation
/// @notice Library for comprehensive batch validation in Taiko's Layer 1 protocol
/// @dev This library provides validation functions for batch proposals, including:
///      - Proposer and coinbase validation
///      - Block structure and metadata validation
///      - Timestamp consistency checks
///      - Anchor block validation
///      - Blob data validation
///      - Signal validation
/// @custom:security-contact security@taiko.xyz
library LibBatchValidation {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Output structure containing validated batch information
    /// @dev This struct aggregates all validation results for efficient batch processing
    struct ValidationOutput {
        /// @notice Hash of all transactions in the batch
        bytes32 txsHash;
        /// @notice Array of blob hashes associated with the batch
        bytes32[] blobHashes;
        /// @notice ID of the last anchor block in the batch
        uint48 lastAnchorBlockId;
        /// @notice ID of the first block in the batch
        uint48 firstBlockId;
        /// @notice ID of the last block in the batch
        uint48 lastBlockId;
        /// @notice Array of anchor block hashes for validation
        bytes32[] anchorBlockHashes;
        /// @notice Array of validated blocks in the batch
        I.Block[] blocks;
        /// @notice Address of the batch proposer
        address proposer;
        /// @notice Address of the batch prover
        address prover;
        /// @notice Address of the coinbase for block rewards
        address coinbase;
        /// @notice Block number where blobs were created
        uint48 blobsCreatedIn;
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Validates a complete batch proposal
    /// @dev Performs comprehensive validation including proposer, blocks, timestamps,
    ///      signals, anchors, and blobs. This is the main entry point for batch validation.
    /// @param _conf Protocol configuration parameters
    /// @param _rw Read/write access functions for blockchain state
    /// @param _batch The batch to validate
    /// @param _parentProposeMeta Metadata from the parent batch proposal
    /// @return output_ Validated batch information and computed hashes
    function validateBatch(
        I.Config memory _conf,
        LibDataUtils.ReadWrite memory _rw,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentProposeMeta
    )
        internal
        view
        returns (ValidationOutput memory output_)
    {
        // Validate proposer and coinbase
        (output_.proposer, output_.coinbase) = _validateProposerCoinbase(_conf, _batch);

        // Validate and decode blocks
        I.Block[] memory blocks = _validateBlocks(_conf, _batch);

        // Validate timestamps
        _validateTimestamps(_conf, _batch, blocks, _parentProposeMeta.lastBlockTimestamp);

        // Validate signals
        _validateSignals(_conf, _rw, blocks, _batch.signalSlots);

        // Validate anchors
        (output_.anchorBlockHashes, output_.lastAnchorBlockId) =
            _validateAnchors(_conf, _rw, _batch, blocks, _parentProposeMeta.lastAnchorBlockId);

        // Validate block range
        (output_.firstBlockId, output_.lastBlockId) =
            _validateBlockRange(_conf, blocks.length, _parentProposeMeta.lastBlockId);

        // Validate blobs
        output_.blobsCreatedIn = _validateBlobs(_conf, _batch);

        // Calculate transaction hash
        (output_.txsHash, output_.blobHashes) = _calculateTxsHash(_rw, _batch.blobs);

        output_.blocks = blocks;
    }

    // -------------------------------------------------------------------------
    // Private Functions - Proposer & Coinbase Validation
    // -------------------------------------------------------------------------

    /// @notice Validates the proposer and coinbase addresses
    /// @dev Handles both direct proposing and inbox wrapper scenarios
    /// @param _conf Protocol configuration
    /// @param _batch The batch being validated
    /// @return proposer_ The validated proposer address
    /// @return coinbase_ The validated coinbase address
    function _validateProposerCoinbase(
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

    // -------------------------------------------------------------------------
    // Private Functions - Block Validation
    // -------------------------------------------------------------------------

    /// @notice Validates and decodes block data from the batch
    /// @dev Decodes packed block information and validates block count limits
    /// @param _conf Protocol configuration
    /// @param _batch The batch containing encoded blocks
    /// @return blocks_ Array of decoded and validated blocks
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
            uint256 encoded = uint256(_batch.encodedBlocks[i]);

            blocks_[i].numTransactions = uint16(encoded);
            blocks_[i].timeShift = uint8(encoded >> 16);
            blocks_[i].anchorBlockId = uint48(encoded >> 24);
            blocks_[i].numSignals = uint8(encoded >> 32 & 0xFF);
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions - Timestamp Validation
    // -------------------------------------------------------------------------

    /// @notice Validates timestamp consistency across the batch
    /// @dev Ensures timestamps are sequential, within bounds, and respect anchor constraints
    /// @param _conf Protocol configuration
    /// @param _batch The batch being validated
    /// @param _blocks Array of blocks in the batch
    /// @param _parentLastBlockTimestamp Timestamp of the last block in the parent batch
    function _validateTimestamps(
        I.Config memory _conf,
        I.Batch memory _batch,
        I.Block[] memory _blocks,
        uint48 _parentLastBlockTimestamp
    )
        internal
        view
    {
        unchecked {
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
    }

    // -------------------------------------------------------------------------
    // Private Functions - Signal Validation
    // -------------------------------------------------------------------------

    /// @notice Validates cross-chain signals in the batch
    /// @dev Verifies that all referenced signals have been properly sent
    /// @param _conf Protocol configuration
    /// @param _rw Read/write access functions
    /// @param _blocks Array of blocks containing signal references
    /// @param _signalSlots Array of signal slot identifiers to validate
    function _validateSignals(
        I.Config memory _conf,
        LibDataUtils.ReadWrite memory _rw,
        I.Block[] memory _blocks,
        bytes32[] memory _signalSlots
    )
        internal
        view
    {
        unchecked {
            uint256 k;

            for (uint256 i; i < _blocks.length; ++i) {
                if (_blocks[i].numSignals == 0) continue;

                require(_blocks[i].numSignals <= _conf.maxSignalsToReceive, TooManySignals());

                for (uint256 j; j < _blocks[i].numSignals; ++j) {
                    require(_rw.isSignalSent(_conf, _signalSlots[k++]), SignalNotSent());
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions - Anchor Block Validation
    // -------------------------------------------------------------------------

    /// @notice Validates anchor blocks used for L1-L2 synchronization
    /// @dev Ensures anchor blocks are properly ordered, within height limits, and have valid hashes
    /// @param _conf Protocol configuration
    /// @param _rw Read/write access functions
    /// @param _batch The batch being validated
    /// @param _blocks Array of blocks in the batch
    /// @param _parentLastAnchorBlockId Last anchor block ID from parent batch
    /// @return anchorBlockHashes_ Array of validated anchor block hashes
    /// @return lastAnchorBlockId_ ID of the last anchor block in this batch
    function _validateAnchors(
        I.Config memory _conf,
        LibDataUtils.ReadWrite memory _rw,
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
            if (!_blocks[i].hasAnchor) continue;

            require(k < _batch.anchorBlockIds.length, NotEnoughAnchorIds());

            uint48 anchorBlockId = _batch.anchorBlockIds[k];
            require(anchorBlockId != 0, AnchorIdZero());

            if (!anchorFound) {
                require(
                    anchorBlockId + _conf.maxAnchorHeightOffset >= uint48(block.number),
                    AnchorIdTooSmall()
                );
            }

            require(anchorBlockId > lastAnchorBlockId_, AnchorIdSmallerThanParent());

            anchorBlockHashes_[k] = _rw.getBlobHash(anchorBlockId);
            require(anchorBlockHashes_[k] != 0, ZeroAnchorBlockHash());

            anchorFound = true;
            lastAnchorBlockId_ = anchorBlockId;
            k++;
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id. Otherwise, delegate this validation to the
        // inboxWrapper contract.
        if (_conf.inboxWrapper != address(0)) {
            require(anchorFound, NoAnchorBlockIdWithinThisBatch());
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions - Block Range Validation
    // -------------------------------------------------------------------------

    /// @notice Validates the block ID range for the batch
    /// @dev Ensures blocks are sequential and within the current fork
    /// @param _conf Protocol configuration
    /// @param _numBlocks Number of blocks in the batch
    /// @param _parentLastBlockId Last block ID from the parent batch
    /// @return firstBlockId_ ID of the first block in this batch
    /// @return lastBlockId_ ID of the last block in this batch
    function _validateBlockRange(
        I.Config memory _conf,
        uint256 _numBlocks,
        uint48 _parentLastBlockId
    )
        internal
        pure
        returns (uint48 firstBlockId_, uint48 lastBlockId_)
    {
        firstBlockId_ = _parentLastBlockId + 1;
        lastBlockId_ = uint48(firstBlockId_ + _numBlocks);

        require(
            LibForks.isBlocksInCurrentFork(_conf, firstBlockId_, lastBlockId_),
            BlocksNotInCurrentFork()
        );
    }

    // -------------------------------------------------------------------------
    // Private Functions - Blob Validation
    // -------------------------------------------------------------------------

    /// @notice Validates blob data and forced inclusion parameters
    /// @dev Handles different blob scenarios: direct, normal batches, and forced inclusion
    /// @param _conf Protocol configuration
    /// @param _batch The batch containing blob information
    /// @return blobsCreatedIn_ Block number where blobs were created
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

    // -------------------------------------------------------------------------
    // Private Functions - Hash Calculation
    // -------------------------------------------------------------------------

    /// @notice Calculates the transaction hash from blob data
    /// @dev Retrieves blob hashes and computes the aggregate transaction hash
    /// @param _rw Read/write access functions
    /// @param _blobs Blob information containing hashes or indices
    /// @return txsHash_ Hash of all transactions in the batch
    /// @return blobHashes_ Array of individual blob hashes
    function _calculateTxsHash(
        LibDataUtils.ReadWrite memory _rw,
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

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    // Proposer and wrapper errors
    /// @notice Thrown when caller is not the configured inbox wrapper
    error NotInboxWrapper();
    /// @notice Thrown when custom proposer is required but not provided
    error CustomProposerMissing();
    /// @notice Thrown when custom proposer is not allowed in current configuration
    error CustomProposerNotAllowed();

    // Block validation errors
    /// @notice Thrown when no blocks are found in the batch
    error BlockNotFound();
    /// @notice Thrown when batch contains more blocks than allowed
    error TooManyBlocks();
    /// @notice Thrown when blocks are not within the current fork range
    error BlocksNotInCurrentFork();
    /// @notice Thrown when first block has non-zero time shift
    error FirstBlockTimeShiftNotZero();

    // Timestamp errors
    /// @notice Thrown when last block timestamp is not set
    error LastBlockTimestampNotSet();
    /// @notice Thrown when timestamp is smaller than parent batch
    error TimestampSmallerThanParent();
    /// @notice Thrown when timestamp is larger than current block timestamp
    error TimestampTooLarge();
    /// @notice Thrown when timestamp is too small relative to anchor constraints
    error TimestampTooSmall();

    // Anchor block errors
    /// @notice Thrown when anchor block ID is smaller than parent anchor
    error AnchorIdSmallerThanParent();
    /// @notice Thrown when anchor block ID is too small relative to current block
    error AnchorIdTooSmall();
    /// @notice Thrown when anchor block ID is zero
    error AnchorIdZero();
    /// @notice Thrown when not enough anchor IDs are provided
    error NotEnoughAnchorIds();
    /// @notice Thrown when no anchor block ID is found within the batch
    error NoAnchorBlockIdWithinThisBatch();
    /// @notice Thrown when anchor block hash is zero
    error ZeroAnchorBlockHash();

    // Blob errors
    /// @notice Thrown when blob is not found
    error BlobNotFound();
    /// @notice Thrown when blob is not specified but required
    error BlobNotSpecified();
    /// @notice Thrown when blob creation block is invalid
    error InvalidBlobCreatedIn();
    /// @notice Thrown when blob parameters are invalid
    error InvalidBlobParams();
    /// @notice Thrown when forced inclusion parameters are invalid
    error InvalidForcedInclusion();

    // Signal errors
    /// @notice Thrown when a required signal has not been sent
    error SignalNotSent();
    /// @notice Thrown when too many signals are referenced in a block
    error TooManySignals();
}
