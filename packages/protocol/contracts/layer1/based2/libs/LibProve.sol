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
    /// @return aggregatedProvingHash_ The aggregated hash of all proven batches
    function prove(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.ProveBatchInput[] memory _inputs
    )
        internal
        returns (bytes32 aggregatedProvingHash_)
    {
        if (_inputs.length == 0) revert NoBlocksToProve();
        if (_inputs.length >= type(uint8).max) revert TooManyBatchesToProve();

        IInbox.TransitionMeta[] memory tranMetas = new IInbox.TransitionMeta[](_inputs.length);
        bytes32[] memory ctxHashes = new bytes32[](_inputs.length);

        IInbox.TransitionMeta memory tranMeta; // The aggregated transition metadata.
        uint256 i;
        for (; i < _inputs.length; ++i) {
            if (_inputs[i].tran.parentHash == 0) revert InvalidTransitionParentHash();

            // During batch proposal, we ensured that blocks won't cross fork boundaries.
            // Therefore, we only need to verify the firstBlockId in the following check.
            if (!LibForks.isBlocksInCurrentFork(_config, _inputs[i].proveMeta.firstBlockId)) {
                revert BlocksNotInCurrentFork();
            }

            // Load and verify the batch metadata
            bytes32 batchMetaHash = _bindings.loadBatchMetaHash(_config, _inputs[i].tran.batchId);
            if (batchMetaHash != LibData.hashBatch(_inputs[i])) revert MetaHashNotMatch();

            bytes32 stateRoot = _inputs[i].tran.batchId % _config.stateRootSyncInternal == 0
                ? _inputs[i].tran.stateRoot
                : bytes32(0);

            (IInbox.ProofTiming proofTiming, address prover) = _determineProofTimingAndProver(
                _config, _inputs[i].proveMeta.prover, _inputs[i].proveMeta.proposedAt
            );

            tranMetas[i] = IInbox.TransitionMeta({
                batchId: _inputs[i].tran.batchId,
                provedAt: uint48(block.timestamp),
                prover: prover,
                proofTiming: proofTiming,
                blockHash: _inputs[i].tran.blockHash,
                stateRoot: stateRoot,
                lastBlockId: _inputs[i].proveMeta.lastBlockId,
                provabilityBond: _inputs[i].proveMeta.provabilityBond,
                livenessBond: _inputs[i].proveMeta.livenessBond
            });

            ctxHashes[i] = keccak256(abi.encode(batchMetaHash, _inputs[i].tran));

            _proverPaysProvabilityBond(_bindings, _config, _inputs[i], tranMetas[i]);

            if (_canAggregateTransitions(tranMeta, tranMetas[i])) {
                tranMeta = _aggregateTransitions(tranMeta, tranMetas[i]);
            } else {
                if (tranMeta.batchId != 0) {
                    // Save the previous aggregated transition if it is valid.
                    _bindings.saveTransition(
                        _config,
                        _inputs[i].tran.batchId, // same as tranMeta.batchId
                        _inputs[i].tran.parentHash,
                        keccak256(abi.encode(tranMeta))
                    );
                }
                // Set the aggregated transition metadata to the current one.
                tranMeta = tranMetas[i];
            }
        } // end of for-loop

        assert(tranMeta.batchId != 0);
        _bindings.saveTransition(
            _config,
            tranMeta.batchId,
            _inputs[i - 1].tran.parentHash,
            keccak256(abi.encode(tranMeta))
        );

        aggregatedProvingHash_ =
            keccak256(abi.encode(_config.chainId, msg.sender, _config.verifier, ctxHashes));

        emit IInbox.Proved(aggregatedProvingHash_, _bindings.encodeTransitionMetas(tranMetas));
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

    /// @notice Upon proving a batch, the prover is expected to trust that the transition will
    /// eventually be used for batch verification. As a result, the prover should be willing to pay
    /// the provability bond on their behalf. Once the transition is used to verify the batch, the
    /// provability bond is returned to the prover, not the proposer.
    function _proverPaysProvabilityBond(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.ProveBatchInput memory _input,
        IInbox.TransitionMeta memory _tranMeta
    )
        private
    {
        // If the batch is proved beyond the extended proving window, the provability bond of the
        // proposer is not refunded. Hence, there is no need for the prover to make a payment on
        // behalf of the proposer.
        if (_tranMeta.proofTiming == IInbox.ProofTiming.OutOfExtendedProvingWindow) return;

        // They are the same party, no need to waste gas.
        if (msg.sender == _input.proveMeta.proposer) return;

        uint256 provabilityBond = uint256(_input.proveMeta.provabilityBond) * 1 gwei;
        _bindings.debitBond(_config, msg.sender, provabilityBond);
        _bindings.creditBond(_input.proveMeta.proposer, provabilityBond);
    }

    /// @notice Checks if transitions can be aggregated
    /// @param _tranMeta The aggregated transition metadata
    /// @param _newTranMeta The new transition metadata
    /// @return True if transitions can be aggregated, false otherwise
    function _canAggregateTransitions(
        IInbox.TransitionMeta memory _tranMeta,
        IInbox.TransitionMeta memory _newTranMeta
    )
        private
        pure
        returns (bool)
    {
        if (_tranMeta.batchId == 0) return true;
        return _tranMeta.batchId + 1 == _newTranMeta.batchId
            && _tranMeta.prover == _newTranMeta.prover
            && _tranMeta.proofTiming == _newTranMeta.proofTiming;
    }

    /// @notice Aggregates transitions
    /// @param _tranMeta The aggregated transition metadata
    /// @param _newTranMeta The new transition metadata
    /// @return The aggregated transition metadata
    function _aggregateTransitions(
        IInbox.TransitionMeta memory _tranMeta,
        IInbox.TransitionMeta memory _newTranMeta
    )
        private
        pure
        returns (IInbox.TransitionMeta memory)
    {
        if (_tranMeta.batchId == 0) {
            return _newTranMeta;
        } else {
            _tranMeta.batchId = _newTranMeta.batchId;
            _tranMeta.blockHash = _newTranMeta.blockHash;
            _tranMeta.stateRoot = _newTranMeta.stateRoot;
            _tranMeta.lastBlockId = _newTranMeta.lastBlockId;
            _tranMeta.provabilityBond += _newTranMeta.provabilityBond;
            _tranMeta.livenessBond += _newTranMeta.livenessBond;
            return _tranMeta;
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BlocksNotInCurrentFork();
    error InvalidTransitionParentHash();
    error MetaHashNotMatch();
    error NoBlocksToProve();
    error TooManyBatchesToProve();
}
