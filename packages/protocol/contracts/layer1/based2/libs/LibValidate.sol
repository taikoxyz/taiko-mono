// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibForks.sol";
import "./LibState.sol";
import "./LibCodec.sol";

/// @title LibValidate
/// @notice Library for comprehensive batch validation in Taiko protocol
/// @dev This library provides validation functions for batch proposals, including:
///      - Proposer and coinbase validation
///      - Block structure and metadata validation
///      - Timestamp consistency checks
///      - Anchor block validation
///      - Blob data validation
///      - Signal validation
/// @custom:security-contact security@taiko.xyz
library LibValidate {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Validates a complete batch proposal
    /// @dev Performs comprehensive validation including proposer, blocks, timestamps,
    ///      signals, anchors, and blobs. This is the main entry point for batch validation.
    /// @dev The prover field of the returned context object will not be initialized.
    /// @param _access Read/write access functions for blockchain state
    /// @param _config Protocol configuration parameters
    /// @param _summary Current protocol summary state
    /// @param _batch The batch to validate
    /// @param _parentBatch Metadata from the parent batch proposal
    /// @return context_ Validated batch information and computed hashes
    function validate(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentBatch
    )
        internal
        view
        returns (I.BatchContext memory context_)
    {
        // We do not check the coinbase address -- if _batch.coinbase is address(0), the driver
        // shall use the proposer as the coinbase address.

        // Validate new gas issuance per second
        _validateGasIssuance(_config, _summary, _batch);

        // Validate and decode blocks
        _validateBlocks(_config, _batch);

        // Validate timestamps
        _validateTimestamps(_config, _batch, _parentBatch.lastBlockTimestamp);

        // Validate signals
        _validateSignals(_access, _config, _batch);

        // Validate anchors
        (bytes32[] memory anchorBlockHashes, uint48 lastAnchorBlockId) =
            _validateAnchors(_access, _config, _batch, _parentBatch.lastAnchorBlockId);

        // Validate block range
        uint48 lastBlockId =
            _validateBlockRange(_config, _batch.blocks.length, _parentBatch.lastBlockId);

        // Validate blobs
        _validateBlobs(_config, _batch);

        // Calculate transaction hash
        (bytes32 txsHash, bytes32[] memory blobHashes) = _calculateTxsHash(_access, _batch.blobs);

        // Initialize context
        context_ = I.BatchContext({
            proposer: msg.sender,
            prover: address(0), // Will be set later in LibProver.validateProver
            txsHash: txsHash,
            blobHashes: blobHashes,
            lastAnchorBlockId: lastAnchorBlockId,
            lastBlockId: lastBlockId,
            anchorBlockHashes: anchorBlockHashes,
            blockMaxGasLimit: _config.blockMaxGasLimit,
            livenessBond: _config.livenessBond,
            provabilityBond: _config.provabilityBond,
            baseFeeSharingPctg: _config.baseFeeSharingPctg
        });
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Validates the gas issuance per second for a batch
    /// @dev Ensures that the gas issuance per second is within a 1% range of the last recorded
    ///      value
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batch The batch being validated, which includes the gas issuance per second
    function _validateGasIssuance(
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch
    )
        internal
        view
    {
        if (_batch.gasIssuancePerSecond == _summary.gasIssuancePerSecond) return;

        require(
            _batch.gasIssuancePerSecond <= _summary.gasIssuancePerSecond * 101 / 100,
            GasIssuanceTooHigh()
        );
        require(
            _batch.gasIssuancePerSecond >= _summary.gasIssuancePerSecond * 100 / 101,
            GasIssuanceTooLow()
        );
        require(
            block.timestamp >= _summary.gasIssuanceUpdatedAt + _config.gasIssuanceUpdateDelay,
            GasIssuanceTooEarlyToChange()
        );
    }

    /// @notice Validates and decodes block data from the batch
    /// @dev Decodes packed block information and validates block count limits
    /// @param _config Protocol configuration
    /// @param _batch The batch containing encoded blocks
    function _validateBlocks(I.Config memory _config, I.Batch memory _batch) internal pure {
        uint256 blockCount_ = _batch.blocks.length;

        require(blockCount_ != 0, BlockNotFound());
        require(blockCount_ <= _config.maxBlocksPerBatch, BlockLimitExceeded());
    }

    /// @notice Validates timestamp consistency across the batch
    /// @dev Ensures timestamps are sequential, within bounds, and respect anchor constraints
    /// @param _config Protocol configuration
    /// @param _batch The batch being validated
    /// @param _parentLastBlockTimestamp Timestamp of the last block in the parent batch
    function _validateTimestamps(
        I.Config memory _config,
        I.Batch memory _batch,
        uint48 _parentLastBlockTimestamp
    )
        internal
        view
    {
        unchecked {
            require(_batch.lastBlockTimestamp != 0, LastBlockTimestampNotSet());
            require(_batch.lastBlockTimestamp <= block.timestamp, TimestampTooLarge());
            require(_batch.blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < _batch.blocks.length; ++i) {
                totalShift += _batch.blocks[i].timeShift;
            }

            require(_batch.lastBlockTimestamp >= totalShift, TimestampTooSmall());
            uint256 firstBlockTimestamp_ = _batch.lastBlockTimestamp - totalShift;

            require(
                firstBlockTimestamp_
                    + _config.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME >= block.timestamp,
                TimestampTooSmall()
            );

            require(firstBlockTimestamp_ >= _parentLastBlockTimestamp, TimestampSmallerThanParent());
        }
    }

    /// @notice Validates cross-chain signals in the batch
    /// @dev Verifies that all referenced signals have been properly sent
    /// @param _access Read/write access functions
    /// @param _config Protocol configuration
    /// @param _batch The batch containing signal references
    function _validateSignals(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Batch memory _batch
    )
        internal
        view
    {
        unchecked {
            uint256 signalIndex;

            for (uint256 i; i < _batch.blocks.length; ++i) {
                if (_batch.blocks[i].numSignals == 0) continue;

                require(
                    _batch.blocks[i].numSignals <= _config.maxSignalsToReceive,
                    SignalLimitExceeded()
                );

                for (uint256 j; j < _batch.blocks[i].numSignals; ++j) {
                    require(
                        _access.isSignalSent(_config, _batch.signalSlots[signalIndex++]),
                        RequiredSignalNotSent()
                    );
                }
            }
        }
    }

    /// @notice Validates anchor blocks used for L1-L2 synchronization
    /// @dev Ensures anchor blocks are properly ordered, within height limits, and have valid hashes
    /// @param _access Read/write access functions
    /// @param _config Protocol configuration
    /// @param _batch The batch being validated
    /// @param _parentLastAnchorBlockId Last anchor block ID from parent batch
    /// @return anchorBlockHashes_ Array of validated anchor block hashes
    /// @return lastAnchorBlockId_ ID of the last anchor block in this batch
    function _validateAnchors(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Batch memory _batch,
        uint48 _parentLastAnchorBlockId
    )
        internal
        view
        returns (bytes32[] memory anchorBlockHashes_, uint48 lastAnchorBlockId_)
    {
        anchorBlockHashes_ = new bytes32[](_batch.blocks.length);
        lastAnchorBlockId_ = _parentLastAnchorBlockId;

        uint256 anchorIndex;
        bool hasAnchorBlock;

        for (uint256 i; i < _batch.blocks.length; ++i) {
            if (!_batch.blocks[i].hasAnchor) continue;

            require(anchorIndex < _batch.anchorBlockIds.length, NotEnoughAnchorIds());

            uint48 anchorBlockId = _batch.anchorBlockIds[anchorIndex];
            require(anchorBlockId != 0, AnchorIdZero());

            if (!hasAnchorBlock) {
                require(
                    anchorBlockId + _config.maxAnchorHeightOffset >= uint48(block.number),
                    AnchorIdTooSmall()
                );
            }

            require(anchorBlockId > lastAnchorBlockId_, AnchorIdSmallerThanParent());

            anchorBlockHashes_[anchorIndex] = _access.getBlockHash(anchorBlockId);
            require(anchorBlockHashes_[anchorIndex] != 0, ZeroAnchorBlockHash());

            hasAnchorBlock = true;
            lastAnchorBlockId_ = anchorBlockId;
            anchorIndex++;
        }

        // Ensure  at least one block must have a non-zero anchor block id.
        require(hasAnchorBlock, NoAnchorBlockIdWithinThisBatch());
    }

    /// @notice Validates the block ID range for the batch
    /// @dev Ensures blocks are sequential and within the current fork
    /// @param _conf Protocol configuration
    /// @param _numBlocks Number of blocks in the batch
    /// @param _parentLastBlockId Last block ID from the parent batch
    /// @return The ID of the last block in this batch
    function _validateBlockRange(
        I.Config memory _conf,
        uint256 _numBlocks,
        uint48 _parentLastBlockId
    )
        internal
        pure
        returns (uint48)
    {
        unchecked {
            uint256 firstBlockId = _parentLastBlockId + 1;
            uint256 lastBlockId = uint48(firstBlockId + _numBlocks);
            require(
                LibForks.isBlocksInCurrentFork(_conf, firstBlockId, lastBlockId),
                BlocksNotInCurrentFork()
            );
            return uint48(lastBlockId);
        }
    }

    /// @notice Validates blob data
    /// @dev Simplified blob validation - ensures blobs are specified
    /// @param _batch The batch containing blob information
    function _validateBlobs(I.Config memory, I.Batch memory _batch) private pure {
        // Blobs must be specified
        require(_batch.blobs.numBlobs != 0, BlobNotSpecified());
    }

    /// @notice Calculates the transaction hash from blob data
    /// @dev Retrieves blob hashes and computes the aggregate transaction hash
    /// @param _access Read/write access functions
    /// @param _blobs Blob information containing hashes or indices
    /// @return txsHash_ Hash of all transactions in the batch
    /// @return blobHashes_ Array of individual blob hashes
    function _calculateTxsHash(
        LibState.Access memory _access,
        I.Blobs memory _blobs
    )
        private
        view
        returns (bytes32 txsHash_, bytes32[] memory blobHashes_)
    {
        unchecked {
            // Always use blob indices now, direct hashes no longer supported
            blobHashes_ = new bytes32[](_blobs.numBlobs);
            for (uint256 i; i < _blobs.numBlobs; ++i) {
                blobHashes_[i] = _access.getBlobHash(_blobs.firstBlobIndex + i);
            }

            for (uint256 i; i < blobHashes_.length; ++i) {
                require(blobHashes_[i] != 0, BlobHashNotFound());
            }

            txsHash_ = keccak256(abi.encode(blobHashes_));
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BlobHashNotFound();
    error BlobNotSpecified();
    error BlockLimitExceeded();
    error BlockNotFound();
    error BlocksNotInCurrentFork();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error FirstBlockTimeShiftNotZero();
    error GasIssuanceTooEarlyToChange();
    error GasIssuanceTooHigh();
    error GasIssuanceTooLow();
    error InvalidBlobCreatedIn();
    error InvalidBlobParams();
    error InvalidForcedInclusion();
    error LastBlockTimestampNotSet();
    error NoAnchorBlockIdWithinThisBatch();
    error NotEnoughAnchorIds();
    error NotInboxWrapper();
    error ProposerNotMsgSender();
    error RequiredSignalNotSent();
    error SignalLimitExceeded();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error ZeroAnchorBlockHash();
}
