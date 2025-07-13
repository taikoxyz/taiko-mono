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
    /// @param _config Protocol configuration parameters
    /// @param _stateAccess Read/write access functions for blockchain state
    /// @param _summary Current protocol summary state
    /// @param _batch The batch to validate
    /// @param _parentProposeMeta Metadata from the parent batch proposal
    /// @return context_ Validated batch information and computed hashes
    function validate(
        I.Config memory _config,
        LibState.StateAccess memory _stateAccess,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentProposeMeta
    )
        internal
        view
        returns (I.BatchContext memory context_)
    {
        // We do not check the coinbase address -- if _batch.coinbase is address(0), the driver
        // shall use the proposer as the coinbase address.

        // Validate proposer
        _validateProposer(_config, _batch);

        // Validate new gas issuance per second
        _validateGasIssuance(_config, _summary, _batch);

        // Validate and decode blocks
        _validateBlocks(_config, _batch);

        // Validate timestamps
        _validateTimestamps(_config, _batch, _parentProposeMeta.lastBlockTimestamp);

        // Validate signals
        _validateSignals(_config, _stateAccess, _batch);

        // Validate anchors
        (bytes32[] memory anchorBlockHashes, uint48 lastAnchorBlockId) =
            _validateAnchors(_config, _stateAccess, _batch, _parentProposeMeta.lastAnchorBlockId);

        // Validate block range
        uint48 lastBlockId =
            _validateBlockRange(_config, _batch.blocks.length, _parentProposeMeta.lastBlockId);

        // Validate blobs
        uint48 blobsCreatedIn = _validateBlobs(_config, _batch);

        // Calculate transaction hash
        (bytes32 txsHash, bytes32[] memory blobHashes) =
            _calculateTxsHash(_stateAccess, _batch.blobs);

        // Initialize context
        context_ = I.BatchContext({
            prover: address(0), // Will be set later in LibProver.validateProver
            txsHash: txsHash,
            blobHashes: blobHashes,
            lastAnchorBlockId: lastAnchorBlockId,
            lastBlockId: lastBlockId,
            anchorBlockHashes: anchorBlockHashes,
            blobsCreatedIn: blobsCreatedIn,
            blockMaxGasLimit: _config.blockMaxGasLimit,
            livenessBond: _config.livenessBond,
            provabilityBond: _config.provabilityBond,
            baseFeeSharingPctg: _config.baseFeeSharingPctg
        });
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Validates the proposer
    /// @dev Handles both direct proposing and inbox wrapper scenarios
    /// @param _config Protocol configuration
    /// @param _batch The batch being validated
    function _validateProposer(I.Config memory _config, I.Batch memory _batch) internal view {
        if (_config.inboxWrapper == address(0)) {
            require(_batch.proposer == msg.sender, ProposerNotMsgSender());
        } else {
            require(msg.sender == _config.inboxWrapper, NotInboxWrapper());
            require(_batch.proposer != address(0), CustomProposerMissing());
        }
    }

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
    /// @param _config Protocol configuration
    /// @param _stateAccess Read/write access functions
    /// @param _batch The batch containing signal references
    function _validateSignals(
        I.Config memory _config,
        LibState.StateAccess memory _stateAccess,
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
                        _stateAccess.isSignalSent(_config, _batch.signalSlots[signalIndex++]),
                        RequiredSignalNotSent()
                    );
                }
            }
        }
    }

    /// @notice Validates anchor blocks used for L1-L2 synchronization
    /// @dev Ensures anchor blocks are properly ordered, within height limits, and have valid hashes
    /// @param _config Protocol configuration
    /// @param _stateAccess Read/write access functions
    /// @param _batch The batch being validated
    /// @param _parentLastAnchorBlockId Last anchor block ID from parent batch
    /// @return anchorBlockHashes_ Array of validated anchor block hashes
    /// @return lastAnchorBlockId_ ID of the last anchor block in this batch
    function _validateAnchors(
        I.Config memory _config,
        LibState.StateAccess memory _stateAccess,
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

            anchorBlockHashes_[anchorIndex] = _stateAccess.getBlockHash(anchorBlockId);
            require(anchorBlockHashes_[anchorIndex] != 0, ZeroAnchorBlockHash());

            hasAnchorBlock = true;
            lastAnchorBlockId_ = anchorBlockId;
            anchorIndex++;
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id.
        if (_config.inboxWrapper != address(0)) {
            require(hasAnchorBlock, NoAnchorBlockIdWithinThisBatch());
        }
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

    /// @notice Validates blob data and forced inclusion parameters
    /// @dev Handles different blob scenarios: direct proposing, normal batches, and forced
    /// inclusion
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

    /// @notice Calculates the transaction hash from blob data
    /// @dev Retrieves blob hashes and computes the aggregate transaction hash
    /// @param _stateAccess Read/write access functions
    /// @param _blobs Blob information containing hashes or indices
    /// @return txsHash_ Hash of all transactions in the batch
    /// @return blobHashes_ Array of individual blob hashes
    function _calculateTxsHash(
        LibState.StateAccess memory _stateAccess,
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
                    blobHashes_[i] = _stateAccess.getBlobHash(_blobs.firstBlobIndex + i);
                }
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
