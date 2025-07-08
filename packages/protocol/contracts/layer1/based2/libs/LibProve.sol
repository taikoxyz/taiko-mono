// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "src/shared/libs/LibMath.sol";
import "./LibData.sol";
import "./LibForks.sol";
import "./LibState.sol";

/// @title LibProve
/// @notice Library for batch proving operations and transition metadata management in Taiko
/// protocol
/// @dev Handles the complete batch proving workflow including:
///      - Multi-batch proof processing with metadata validation
///      - Proof timing determination (proving window, extended window, expired)
///      - Transition metadata creation and storage
///      - Bond management for first transitions and assigned provers
///      - Aggregated hash generation for batch verification
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
        LibState.ReadWrite memory _rw,
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
        LibState.ReadWrite memory _rw,
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

        _validateProveMeta(batchMetaHash, _input);

        bytes32 stateRoot = _input.tran.batchId % _conf.stateRootSyncInternal == 0
            ? _input.tran.stateRoot
            : bytes32(0);

        (I.ProofTiming proofTiming, address prover) = _determineProofTiming(
            _conf,
            _input.proveMeta.prover,
            uint256(_input.proveMeta.proposedAt).max(_summary.lastUnpausedAt)
        );

        // Create the transition metadata
        I.TransitionMeta memory tranMeta = I.TransitionMeta({
            blockHash: _input.tran.blockHash,
            stateRoot: stateRoot,
            proofTiming: proofTiming,
            prover: prover,
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _input.proveMeta.prover,
            lastBlockId: _input.proveMeta.lastBlockId,
            provabilityBond: _input.proveMeta.provabilityBond,
            livenessBond: _input.proveMeta.livenessBond
        });

        bool isFirstTransition = _rw.saveTransition(
            _conf, _input.tran.batchId, _input.tran.parentHash, keccak256(abi.encode(tranMeta))
        );

        if (
            isFirstTransition && tranMeta.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _input.proveMeta.proposer
        ) {
            _rw.debitBond(_conf, msg.sender, _input.proveMeta.provabilityBond);
            _rw.creditBond(_input.proveMeta.proposer, _input.proveMeta.provabilityBond);
        }

        I.TransitionMeta[] memory tranMetas = new I.TransitionMeta[](1);
        tranMetas[0] = tranMeta;
        emit I.Proved(_input.tran.batchId, LibData.packTransitionMeta(tranMetas));

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
    function _validateProveMeta(
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

    error BatchNotFound();
    error BlocksNotInCurrentFork();
    error InvalidTransitionParentHash();
    error MetaHashNotMatch();
    error NoBlocksToProve();
    error TooManyBatchesToProve();
}
