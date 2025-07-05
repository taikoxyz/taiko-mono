// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "./LibForks.sol";
import "./LibData.sol";

/// @title LibProve
/// @notice Library for handling batch proving operations in the Taiko protocol
/// @dev This library manages the proof submission and validation process for batches
/// @custom:security-contact security@taiko.xyz
library LibProve {
    using LibMath for uint256;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Proves multiple batches and returns an aggregated hash for verification
    /// @param _conf The protocol configuration
    /// @param _rw Read/write function pointers for storage access
    /// @param _summary The current protocol summary
    /// @param _evidences Array of batch prove inputs containing transition data
    /// @return The updated protocol summary and aggregated batch hash for proof verification
    function prove(
        I.Config memory _conf,
        LibData.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _evidences
    )
        internal
        returns (I.Summary memory, bytes32)
    {
        uint256 nBatches = _evidences.length;
        require(nBatches != 0, NoBlocksToProve());
        require(nBatches <= type(uint8).max, TooManyBatchesToProve());

        bytes32[] memory ctxHashes = new bytes32[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            ctxHashes[i] = _proveBatch(_conf, _rw, _summary, _evidences[i]);
        }

        bytes32 aggregatedBatchHash =
            keccak256(abi.encode(_conf.chainId, msg.sender, _conf.verifier, ctxHashes));

        return (_summary, aggregatedBatchHash);
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proves a single batch by validating metadata and saving the transition
    /// @param _conf The protocol configuration
    /// @param _rw Read/write function pointers for storage access
    /// @param _summary The current protocol summary
    /// @param _input The batch prove input containing transition and metadata
    /// @return The context hash for this batch used in aggregation
    function _proveBatch(
        I.Config memory _conf,
        LibData.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.BatchProveInput calldata _input
    )
        private
        returns (bytes32)
    {
        require(_input.tran.batchId > _summary.lastVerifiedBatchId, BatchNotFound());
        require(_input.tran.batchId < _summary.numBatches, BatchNotFound());
        require(_input.tran.parentHash != 0, InvalidTransitionParentHash());

        // During batch proposal, we ensured that blocks won't cross fork boundaries.
        // Therefore, we only need to verify the firstBlockId in the following check.
        require(
            LibForks.isBlocksInCurrentFork(
                _conf, _input.proveMeta.firstBlockId, _input.proveMeta.firstBlockId
            ),
            BlocksNotInCurrentFork()
        );

        // Load and verify the batch metadata
        bytes32 batchMetaHash = _rw.loadBatchMetaHash(_conf, _input.tran.batchId);

        _validateBatchProveMeta(batchMetaHash, _input);

        I.TransitionMeta memory tranMeta = I.TransitionMeta({
            parentHash: _input.tran.parentHash,
            blockHash: _input.tran.blockHash,
            stateRoot: _input.tran.batchId % _conf.stateRootSyncInternal == 0
                ? _input.tran.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // Updated below based on timing
            prover: address(0), // Updated below based on timing
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _input.proveMeta.prover,
            lastBlockId: _input.proveMeta.lastBlockId,
            provabilityBond: _input.proveMeta.provabilityBond,
            livenessBond: _input.proveMeta.livenessBond
        });

        (tranMeta.proofTiming, tranMeta.prover) = _determineProofTiming(
            _conf,
            _input.proveMeta.prover,
            uint256(_input.proveMeta.proposedAt).max(_summary.lastUnpausedAt)
        );

        bytes32 tranMetaHash = keccak256(abi.encode(tranMeta));

        bool isFirstTransition =
            _rw.saveTransition(_conf, _input.tran.batchId, _input.tran.parentHash, tranMetaHash);
        if (
            isFirstTransition && tranMeta.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _input.proveMeta.proposer
        ) {
            _rw.debitBond(_conf, msg.sender, _input.proveMeta.provabilityBond);
            _rw.creditBond(_input.proveMeta.proposer, _input.proveMeta.provabilityBond);
        }

        emit I.BatchProved(_input.tran.batchId, isFirstTransition, tranMeta);

        return keccak256(abi.encode(batchMetaHash, _input.tran));
    }

    /// @notice Determines the proof timing and prover based on the current timestamp
    /// @param _conf The configuration
    /// @param _assignedProver The originally assigned prover
    /// @param _proposedAt The timestamp when the batch was proposed
    /// @return timing_ The proof timing category
    /// @return prover_ The address to be recorded as the prover
    function _determineProofTiming(
        I.Config memory _conf,
        address _assignedProver,
        uint256 _proposedAt
    )
        private
        view
        returns (I.ProofTiming timing_, address prover_)
    {
        unchecked {
            if (block.timestamp <= _proposedAt + _conf.provingWindow) {
                return (I.ProofTiming.InProvingWindow, _assignedProver);
            } else if (block.timestamp <= _proposedAt + _conf.extendedProvingWindow) {
                return (I.ProofTiming.InExtendedProvingWindow, msg.sender);
            } else {
                return (I.ProofTiming.OutOfExtendedProvingWindow, msg.sender);
            }
        }
    }

    /// @notice Validates the batch prove metadata against the stored hash
    /// @param _batchMetaHash The stored batch metadata hash
    /// @param _input The batch prove input containing metadata to validate
    function _validateBatchProveMeta(
        bytes32 _batchMetaHash,
        I.BatchProveInput calldata _input
    )
        private
        pure
    {
        bytes32 proveMetaHash = keccak256(abi.encode(_input.proveMeta));
        bytes32 rightHash = keccak256(abi.encode(_input.proposeMetaHash, proveMetaHash));
        bytes32 metaHash = keccak256(abi.encode(_input.idAndBuildHash, rightHash));

        require(_batchMetaHash == metaHash, MetaHashNotMatch());
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the batch is not found
    error BatchNotFound();

    /// @notice Thrown when blocks are not in the current fork
    error BlocksNotInCurrentFork();

    /// @notice Thrown when the transition parent hash is invalid (zero)
    error InvalidTransitionParentHash();

    /// @notice Thrown when the metadata hash doesn't match
    error MetaHashNotMatch();

    /// @notice Thrown when there are no blocks to prove
    error NoBlocksToProve();

    /// @notice Thrown when too many batches are being proved at once
    error TooManyBatchesToProve();
}
