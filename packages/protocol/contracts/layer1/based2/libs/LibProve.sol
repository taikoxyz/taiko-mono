// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "src/shared/libs/LibMath.sol";
import "./LibData.sol";
import "./LibForks.sol";
import "./LibBinding.sol";

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
    /// @param _access Read/write function pointers for storage access
    /// @param _config The protocol configuration
    /// @param _evidences Array of batch prove inputs containing transition data
    /// @return _ The aggregated hash of all proven batches
    function prove(
        LibBinding.Bindings memory _access,
        I.Config memory _config,
        I.BatchProveInput[] memory _evidences
    )
        internal
        returns (bytes32)
    {
        uint256 nBatches = _evidences.length;
        require(nBatches != 0, NoBlocksToProve());
        require(nBatches <= type(uint8).max, TooManyBatchesToProve());

        bytes32[] memory ctxHashes = new bytes32[](nBatches);
        for (uint256 i; i < nBatches; ++i) {
            ctxHashes[i] = _proveBatch(_access, _config, _evidences[i]);
        }

        return keccak256(abi.encode(_config.chainId, msg.sender, _config.verifier, ctxHashes));
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proves a single batch by validating metadata and saving the transition
    /// @param _access Read/write function pointers for storage access
    /// @param _config The protocol configuration
    /// @param _input The batch prove input containing transition and metadata
    /// @return The context hash for this batch used in aggregation
    function _proveBatch(
        LibBinding.Bindings memory _access,
        I.Config memory _config,
        // I.Summary memory _summary,
        I.BatchProveInput memory _input
    )
        private
        returns (bytes32)
    {
        require(_input.tran.parentHash != 0, InvalidTransitionParentHash());

        // During batch proposal, we ensured that blocks won't cross fork boundaries.
        // Therefore, we only need to verify the firstBlockId in the following check.
        require(
            LibForks.isBlocksInCurrentFork(
                _config, _input.proveMeta.firstBlockId, _input.proveMeta.firstBlockId
            ),
            BlocksNotInCurrentFork()
        );

        // Load and verify the batch metadata
        bytes32 batchMetaHash = _access.loadBatchMetaHash(_config, _input.tran.batchId);

        require(batchMetaHash == LibData.hashBatch(_input), MetaHashNotMatch());

        bytes32 stateRoot = _input.tran.batchId % _config.stateRootSyncInternal == 0
            ? _input.tran.stateRoot
            : bytes32(0);

        (I.ProofTiming proofTiming, address prover) =
            _determineProofTiming(_config, _input.proveMeta.prover, _input.proveMeta.proposedAt);

        // Create the transition metadata
        I.TransitionMeta memory tranMeta = I.TransitionMeta({
            blockHash: _input.tran.blockHash,
            stateRoot: stateRoot,
            prover: prover,
            proofTiming: proofTiming,
            provedAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _input.proveMeta.prover,
            lastBlockId: _input.proveMeta.lastBlockId,
            provabilityBond: _input.proveMeta.provabilityBond,
            livenessBond: _input.proveMeta.livenessBond
        });

        bool isFirstTransition = _access.saveTransition(
            _config, _input.tran.batchId, _input.tran.parentHash, keccak256(abi.encode(tranMeta))
        );

        if (
            isFirstTransition && tranMeta.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _input.proveMeta.proposer
        ) {
            uint256 bondAmount = uint256(_input.proveMeta.provabilityBond) * 1 gwei;
            _access.debitBond(_config, msg.sender, bondAmount);
            _access.creditBond(_input.proveMeta.proposer, bondAmount);
        }

        I.TransitionMeta[] memory tranMetas = new I.TransitionMeta[](1);
        tranMetas[0] = tranMeta;
        emit I.Proved(_input.tran.batchId, _access.encodeTransitionMetas(tranMetas));

        return keccak256(abi.encode(batchMetaHash, _input.tran));
    }

    /// @notice Determines the proof timing and prover based on the current timestamp
    /// @param _config The configuration
    /// @param _assignedProver The originally assigned prover
    /// @param _proposedAt The timestamp when the batch was proposed
    /// @return timing_ The proof timing category
    /// @return prover_ The address to be recorded as the prover
    function _determineProofTiming(
        I.Config memory _config,
        address _assignedProver,
        uint256 _proposedAt
    )
        private
        view
        returns (I.ProofTiming timing_, address prover_)
    {
        unchecked {
            if (block.timestamp <= _proposedAt + _config.provingWindow) {
                return (I.ProofTiming.InProvingWindow, _assignedProver);
            } else if (block.timestamp <= _proposedAt + _config.extendedProvingWindow) {
                return (I.ProofTiming.InExtendedProvingWindow, msg.sender);
            } else {
                return (I.ProofTiming.OutOfExtendedProvingWindow, msg.sender);
            }
        }
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
