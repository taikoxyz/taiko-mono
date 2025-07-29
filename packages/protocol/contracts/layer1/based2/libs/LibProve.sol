// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";
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
    /// @param _bindings Library function binding
    /// @param _config The protocol configuration
    /// @param _inputs Array of batch prove inputs containing transition data
    /// @return _ The aggregated hash of all proven batches
    function prove(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.ProveBatchInput[] memory _inputs
    )
        internal
        returns (bytes32)
    {
        if (_inputs.length == 0) revert NoBlocksToProve();
        if (_inputs.length > type(uint8).max) revert TooManyBatchesToProve();

        bytes32[] memory ctxHashes = new bytes32[](_inputs.length);

        for (uint256 i; i < _inputs.length; ++i) {
            IInbox.ProveBatchInput memory input = _inputs[i];

            if (input.tran.parentHash == 0) revert InvalidTransitionParentHash();

            // During batch proposal, we ensured that blocks won't cross fork boundaries.
            // Therefore, we only need to verify the firstBlockId in the following check.
            if (!LibForks.isBlocksInCurrentFork(_config, input.proveMeta.firstBlockId)) {
                revert BlocksNotInCurrentFork();
            }

            // Load and verify the batch metadata
            bytes32 batchMetaHash = _bindings.loadBatchMetaHash(_config, input.tran.batchId);

            if (batchMetaHash != LibData.hashBatch(input)) revert MetaHashNotMatch();

            bytes32 stateRoot = input.tran.batchId % _config.stateRootSyncInternal == 0
                ? input.tran.stateRoot
                : bytes32(0);

            (IInbox.ProofTiming proofTiming, address prover) = _determineProofTimingAndProver(
                _config, input.proveMeta.prover, input.proveMeta.proposedAt
            );

            // Create the transition metadata
            IInbox.TransitionMeta memory tranMeta = IInbox.TransitionMeta({
                span: 1,
                lastBlockId: input.proveMeta.lastBlockId,
                prover: prover,
                provedAt: uint48(block.timestamp),
                blockHash: input.tran.blockHash,
                stateRoot: stateRoot,
                proofTiming: proofTiming,
                byAssignedProver: msg.sender == input.proveMeta.prover,
                provabilityBond: input.proveMeta.provabilityBond,
                livenessBond: input.proveMeta.livenessBond
            });

            bool isFirstTransition = _bindings.saveTransition(
                _config, input.tran.batchId, input.tran.parentHash, keccak256(abi.encode(tranMeta))
            );

            if (
                isFirstTransition
                    && tranMeta.proofTiming != IInbox.ProofTiming.OutOfExtendedProvingWindow
                    && msg.sender != input.proveMeta.proposer
            ) {
                uint256 bondAmount = uint256(input.proveMeta.provabilityBond) * 1 gwei;
                _bindings.debitBond(_config, msg.sender, bondAmount);
                _bindings.creditBond(input.proveMeta.proposer, bondAmount);
            }

            IInbox.TransitionMeta[] memory tranMetas = new IInbox.TransitionMeta[](1);
            tranMetas[0] = tranMeta;
            emit IInbox.Proved(input.tran.batchId, _bindings.encodeTransitionMetas(tranMetas));

            ctxHashes[i] = keccak256(abi.encode(batchMetaHash, input.tran));
        }

        return keccak256(abi.encode(_config.chainId, msg.sender, _config.verifier, ctxHashes));
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Determines the proof timing and prover based on the current timestamp
    /// @param _config The configuration
    /// @param _assignedProver The originally assigned prover
    /// @param _proposedAt The timestamp when the batch was proposed
    /// @return timing_ The proof timing category
    /// @return prover_ The address to be recorded as the prover
    function _determineProofTimingAndProver(
        IInbox.Config memory _config,
        address _assignedProver,
        uint256 _proposedAt
    )
        private
        view
        returns (IInbox.ProofTiming timing_, address prover_)
    {
        unchecked {
            if (block.timestamp <= _proposedAt + _config.provingWindow) {
                return (IInbox.ProofTiming.InProvingWindow, _assignedProver);
            } else if (block.timestamp <= _proposedAt + _config.extendedProvingWindow) {
                return (IInbox.ProofTiming.InExtendedProvingWindow, msg.sender);
            } else {
                return (IInbox.ProofTiming.OutOfExtendedProvingWindow, msg.sender);
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
