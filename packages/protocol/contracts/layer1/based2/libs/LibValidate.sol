// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
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
    /// @param _batch The batch to validate
    /// @return _ Validated batch information and computed hashes
    function validate(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Batch memory _batch
    )
        internal
        view
        returns (IInbox.BatchContext memory)
    {
        // If a block's coinbase is address(0), _batch.coinbase will be used, if _batch.coinbase
        // is address(0), the driver shall use the proposer address as the coinbase address.

        _validateProposer(_config);

        // Validate blobs
        uint48 blobsCreatedIn = _validateBlobs(_config, _batch);

        // Calculate transaction hash
        (bytes32[] memory blobHashes, bytes32 txsHash) = _calculateTxsHash(_bindings, _batch.blobs);

        // Initialize context
        return IInbox.BatchContext({
            prover: address(0), // Will be set later in LibProver.validateProver
            txsHash: txsHash,
            blobHashes: blobHashes,
            blobsCreatedIn: blobsCreatedIn,
            livenessBond: _config.livenessBond,
            provabilityBond: _config.provabilityBond
        });
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Validates the proposer of the current transaction.
    /// @dev Checks if the sender is the operator for the current epoch.
    ///      If the preconfWhitelist address is zero, the function returns without validation.
    /// @param _config The configuration containing the preconfWhitelist address.
    /// @custom:reverts ProposerNotOperator if the sender is not the operator for the current epoch.
    function _validateProposer(IInbox.Config memory _config) private view {
        if (_config.preconfWhitelist == address(0)) return;
        address operator = IPreconfWhitelist(_config.preconfWhitelist).getOperatorForCurrentEpoch();
        if (msg.sender != operator) revert ProposerNotOperator();
    }

    /// @notice Validates blob data and forced inclusion parameters
    /// @dev Handles different blob scenarios: direct proposing, normal batches, and forced
    /// inclusion
    /// @param _conf Protocol configuration
    /// @param _batch The batch containing blob information
    /// @return blobsCreatedIn_ Block number where blobs were created
    function _validateBlobs(
        IInbox.Config memory _conf,
        IInbox.Batch memory _batch
    )
        private
        view
        returns (uint48 blobsCreatedIn_)
    {
        if (_conf.forcedInclusionStore == address(0)) {
            // blob hashes are only accepted if the caller is trusted.
            if (_batch.blobs.hashes.length != 0) revert InvalidBlobParams();
            if (_batch.blobs.createdIn != 0) revert InvalidBlobCreatedIn();
            if (_batch.isForcedInclusion) revert InvalidForcedInclusion();
            return uint48(block.number);
        }

        if (_batch.blobs.hashes.length == 0) {
            // this is a normal batch, blobs are created and used in the current batches.
            // firstBlobIndex can be non-zero.
            if (_batch.blobs.numBlobs == 0) revert BlobNotSpecified();
            if (_batch.blobs.createdIn != 0) revert InvalidBlobCreatedIn();
            return uint48(block.number);
        }
        // this is a forced-inclusion batch, blobs were created in early blocks and are used
        // in the current batches
        if (_batch.blobs.createdIn == 0) revert InvalidBlobCreatedIn();
        if (_batch.blobs.numBlobs != 0) revert InvalidBlobParams();
        if (_batch.blobs.firstBlobIndex != 0) revert InvalidBlobParams();
        return _batch.blobs.createdIn;
    }

    /// @notice Calculates the transaction hash from blob data
    /// @dev Retrieves blob hashes and computes the aggregate transaction hash
    /// @param _bindings Read/write bindings functions
    /// @param _blobs Blob information containing hashes or indices
    /// @return blobHashes_ Array of individual blob hashes
    /// @return txsHash_ Hash of all transactions in the batch
    function _calculateTxsHash(
        LibBinding.Bindings memory _bindings,
        IInbox.Blobs memory _blobs
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
    error ProposerNotOperator();
    error RequiredSignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error ZeroAnchorBlockHash();
}
