// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibForks.sol";
import "./LibBinding.sol";

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
    uint32 internal constant MIN_GAS_ISSUANCE_PER_SECOND = 100_000;
    uint32 internal constant MAX_GAS_ISSUANCE_PER_SECOND = 100_000_000;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Validates a complete batch proposal
    /// @dev Performs comprehensive validation including proposer, blocks, timestamps,
    ///      signals, anchors, and blobs. This is the main entry point for batch validation.
    /// @dev The prover field of the returned context object will not be initialized.
    /// @param _bindings Library function binding
    /// @param _config Protocol configuration parameters
    /// @param _summary Current protocol summary state
    /// @param _batch The batch to validate
    /// @param _parentBatch Metadata from the parent batch proposal
    /// @return _ Validated batch information and computed hashes
    function validate(
        LibBinding.Bindings memory _bindings,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentBatch
    )
        internal
        view
        returns (I.BatchContext memory)
    {
        // If a block's coinbase is address(0), _batch.coinbase will be used, if _batch.coinbase
        // is address(0), the driver shall use the proposer address as the coinbase address.

        // Validate proposer
        _validateProposer(_config, _batch);

        // Validate new gas issuance per second
        _validateGasIssuance(_config, _summary, _batch);

        // Validate timestamps
        _validateTimestamps(_config, _batch, _parentBatch.lastBlockTimestamp);

        // Validate signals
        _validateSignals(_bindings, _config, _batch);

        // Validate anchors
        (bytes32[] memory anchorBlockHashes, uint48 lastAnchorBlockId) =
            _validateAnchors(_bindings, _config, _batch, _parentBatch.lastAnchorBlockId);

        // Validate block range
        uint48 lastBlockId =
            _validateBlockRange(_config, _batch.blocks.length, _parentBatch.lastBlockId);

        // Validate blobs
        uint48 blobsCreatedIn = _validateBlobs(_config, _batch);

        // Calculate transaction hash
        (bytes32[] memory blobHashes, bytes32 txsHash) = _calculateTxsHash(_bindings, _batch.blobs);

        // Initialize context
        return I.BatchContext({
            prover: address(0), // Will be set later in LibProver.validateProver
            txsHash: txsHash,
            blobHashes: blobHashes,
            lastAnchorBlockId: lastAnchorBlockId,
            lastBlockId: lastBlockId,
            anchorBlockHashes: anchorBlockHashes,
            blobsCreatedIn: blobsCreatedIn,
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
            if (_batch.proposer != msg.sender) revert ProposerNotMsgSender();
        } else {
            if (msg.sender != _config.inboxWrapper) revert NotInboxWrapper();
            if (_batch.proposer == address(0)) revert CustomProposerMissing();
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
        unchecked {
            if (_batch.gasIssuancePerSecond == _summary.gasIssuancePerSecond) return;

            if (
                _batch.gasIssuancePerSecond > MAX_GAS_ISSUANCE_PER_SECOND
                    || _batch.gasIssuancePerSecond > _summary.gasIssuancePerSecond * 101 / 100
            ) {
                revert GasIssuanceTooHigh();
            }
            if (
                _batch.gasIssuancePerSecond < MIN_GAS_ISSUANCE_PER_SECOND
                    || _batch.gasIssuancePerSecond < _summary.gasIssuancePerSecond * 99 / 100
            ) {
                revert GasIssuanceTooLow();
            }
            if (block.timestamp < _summary.gasIssuanceUpdatedAt + _config.gasIssuanceUpdateDelay) {
                revert GasIssuanceTooEarlyToChange();
            }
        }
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
            if (_batch.lastBlockTimestamp == 0) revert LastBlockTimestampNotSet();
            if (_batch.lastBlockTimestamp > block.timestamp) revert TimestampTooLarge();
            if (_batch.blocks[0].timeShift != 0) revert FirstBlockTimeShiftNotZero();

            uint64 totalShift;
            for (uint256 i; i < _batch.blocks.length; ++i) {
                totalShift += _batch.blocks[i].timeShift;
            }
            if (_batch.lastBlockTimestamp < totalShift) revert TimestampTooSmall();

            uint256 firstBlockTimestamp_ = _batch.lastBlockTimestamp - totalShift;
            if (
                firstBlockTimestamp_
                    + _config.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME < block.timestamp
            ) {
                revert TimestampTooSmall();
            }
            if (firstBlockTimestamp_ < _parentLastBlockTimestamp) {
                revert TimestampSmallerThanParent();
            }
        }
    }

    /// @notice Validates cross-chain signals in the batch
    /// @dev Verifies that all referenced signals have been properly sent
    /// @param _bindings Read/write bindings functions
    /// @param _config Protocol configuration
    /// @param _batch The batch containing signal references
    function _validateSignals(
        LibBinding.Bindings memory _bindings,
        I.Config memory _config,
        I.Batch memory _batch
    )
        internal
        view
    {
        for (uint256 i; i < _batch.blocks.length; ++i) {
            for (uint256 j; j < _batch.blocks[i].signalSlots.length; ++j) {
                if (!_bindings.isSignalSent(_config, _batch.blocks[i].signalSlots[j])) {
                    revert RequiredSignalNotSent();
                }
            }
        }
    }

    /// @notice Validates anchor blocks used for L1-L2 synchronization
    /// @dev Ensures anchor blocks are properly ordered, within height limits, and have valid hashes
    /// @param _bindings Read/write bindings functions
    /// @param _config Protocol configuration
    /// @param _batch The batch being validated
    /// @param _parentLastAnchorBlockId Last anchor block ID from parent batch
    /// @return anchorBlockHashes_ Array of validated anchor block hashes
    /// @return lastAnchorBlockId_ ID of the last anchor block in this batch
    function _validateAnchors(
        LibBinding.Bindings memory _bindings,
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
            if (_batch.blocks[i].anchorBlockId == 0) continue;

            uint48 anchorBlockId = _batch.blocks[i].anchorBlockId;
            if (anchorBlockId == 0) revert AnchorIdZero();

            if (
                !hasAnchorBlock
                    && anchorBlockId + _config.maxAnchorHeightOffset < uint48(block.number)
            ) {
                revert AnchorIdTooSmall();
            }

            if (anchorBlockId <= lastAnchorBlockId_) revert AnchorIdSmallerThanParent();

            anchorBlockHashes_[anchorIndex] = _bindings.getBlockHash(anchorBlockId);
            if (anchorBlockHashes_[anchorIndex] == 0) revert ZeroAnchorBlockHash();

            hasAnchorBlock = true;
            lastAnchorBlockId_ = anchorBlockId;
            anchorIndex++;
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id.
        if (_config.inboxWrapper != address(0)) {
            if (!hasAnchorBlock) revert NoAnchorBlockIdWithinThisBatch();
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
            // Validate and decode blocks
            if (_numBlocks == 0) revert BlockNotFound();
            uint48 firstBlockId = _parentLastBlockId + 1;
            uint48 lastBlockId = uint48(_parentLastBlockId + _numBlocks);
            if (!LibForks.isBlocksInCurrentFork(_conf, firstBlockId, lastBlockId)) {
                revert BlocksNotInCurrentFork();
            }
            return lastBlockId;
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
            if (_batch.blobs.hashes.length != 0) revert InvalidBlobParams();
            if (_batch.blobs.createdIn != 0) revert InvalidBlobCreatedIn();
            if (_batch.isForcedInclusion) revert InvalidForcedInclusion();
            return uint48(block.number);
        } else if (_batch.blobs.hashes.length == 0) {
            // this is a normal batch, blobs are created and used in the current batches.
            // firstBlobIndex can be non-zero.
            if (_batch.blobs.numBlobs == 0) revert BlobNotSpecified();
            if (_batch.blobs.createdIn != 0) revert InvalidBlobCreatedIn();
            return uint48(block.number);
        } else {
            // this is a forced-inclusion batch, blobs were created in early blocks and are used
            // in the current batches
            require(_batch.blobs.createdIn != 0, InvalidBlobCreatedIn());
            if (_batch.blobs.numBlobs != 0) revert InvalidBlobParams();
            if (_batch.blobs.firstBlobIndex != 0) revert InvalidBlobParams();
            return _batch.blobs.createdIn;
        }
    }

    /// @notice Calculates the transaction hash from blob data
    /// @dev Retrieves blob hashes and computes the aggregate transaction hash
    /// @param _bindings Read/write bindings functions
    /// @param _blobs Blob information containing hashes or indices
    /// @return blobHashes_ Array of individual blob hashes
    /// @return txsHash_ Hash of all transactions in the batch
    function _calculateTxsHash(
        LibBinding.Bindings memory _bindings,
        I.Blobs memory _blobs
    )
        private
        view
        returns (bytes32[] memory blobHashes_, bytes32 txsHash_)
    {
        unchecked {
            if (_blobs.hashes.length != 0) {
                blobHashes_ = _blobs.hashes;
            } else {
                blobHashes_ = new bytes32[](_blobs.numBlobs);
                for (uint256 i; i < _blobs.numBlobs; ++i) {
                    blobHashes_[i] = _bindings.getBlobHash(_blobs.firstBlobIndex + i);
                }
            }

            for (uint256 i; i < blobHashes_.length; ++i) {
                if (blobHashes_[i] == 0) revert BlobHashNotFound();
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
    error NotEnoughSignals();
    error NotInboxWrapper();
    error ProposerNotMsgSender();
    error RequiredSignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error ZeroAnchorBlockHash();
}
