// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../IInbox.sol";
import "./LibValidate.sol";
import "./LibData.sol";
import "./LibProver.sol";

/// @title LibPropose
/// @notice Library for processing batch proposals and metadata generation in Taiko protocol
/// @dev Handles the complete batch proposal workflow including:
///      - Multi-batch proposal validation and processing
///      - Batch metadata population with build, propose, and prove sections
///      - Parent metadata hash verification against evidence
///      - Prover validation and authentication
///      - Batch limit enforcement and sequential processing
/// @custom:security-contact security@taiko.xyz
library LibPropose {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes multiple batches in a single transaction
    /// @param _bindings Library function binding
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batches Array of batches to propose
    /// @return The updated protocol summary
    function propose(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Summary memory _summary,
        IInbox.Batch[] memory _batches
    )
        internal
        returns (IInbox.Summary memory)
    {
        unchecked {
            if (_batches.length == 0) revert EmptyBatchArray();
            if (_batches.length > 7) revert BatchLimitExceeded();

            if (
                _summary.nextBatchId + _batches.length
                    > _summary.lastVerifiedBatchId + _config.batchRingBufferSize
            ) {
                revert BatchLimitExceeded();
            }

            for (uint256 i; i < _batches.length; ++i) {
                IInbox.BatchContext memory context =
                    LibValidate.validate(_bindings, _config, _batches[i]);
                context.prover = LibProver.validateProver(_bindings, _config, _summary, _batches[i]);

                // TODO: also emit these values as the new Context in event
                bytes32 batchMetaHash = keccak256(
                    abi.encode(
                        msg.sender,
                        block.timestamp,
                        context.txsHash,
                        context.blobHashes,
                        _summary.nextBatchId,
                        context.prover
                    )
                );
                _bindings.saveBatchMetaHash(_config, _summary.nextBatchId, batchMetaHash);
                _summary.nextBatchId += 1;
            }

            return _summary;
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BatchLimitExceeded();
    error BlobHashNotFound();
    error BlocksNotInCurrentFork();
    error EmptyBatchArray();
    error FirstBlockTimeShiftNotZero();
    error MetadataHashMismatch();
    error NoAnchorBlockIdWithinThisBatch();
    error RequiredSignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error ZeroAnchorBlockHash();
}
