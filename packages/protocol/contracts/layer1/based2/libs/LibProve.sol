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
        IInbox.TransitionMeta[] memory tranMetas = new IInbox.TransitionMeta[](_inputs.length);

        IInbox.TransitionMeta memory aggregatedTranMeta;
        IInbox.ProveBatchInput memory input;

        for (uint256 i; i < _inputs.length; ++i) {
            input = _inputs[i];

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

            IInbox.TransitionMeta memory newTranMeta = IInbox.TransitionMeta({
                provedAt: uint48(block.timestamp),
                prover: prover,
                proofTiming: proofTiming,
                blockHash: input.tran.blockHash,
                stateRoot: stateRoot,
                lastBlockId: input.proveMeta.lastBlockId,
                span: 1,
                provabilityBond: input.proveMeta.provabilityBond,
                livenessBond: input.proveMeta.livenessBond
            });

            _provePaysProvabilityBond(_bindings, _config, input, newTranMeta);

            bool canAggregate = _canAggregateTransitions(aggregatedTranMeta, newTranMeta);

            if (canAggregate) {
                aggregatedTranMeta = _aggregateTransitions(aggregatedTranMeta, newTranMeta);
            } else if (aggregatedTranMeta.span != 0) {
                _bindings.saveTransition(
                    _config,
                    input.tran.batchId,
                    input.tran.parentHash,
                    keccak256(abi.encode(aggregatedTranMeta))
                );
                aggregatedTranMeta = newTranMeta;
            }

            ctxHashes[i] = keccak256(abi.encode(batchMetaHash, input.tran));
        }

        if (aggregatedTranMeta.span != 0) {
            _bindings.saveTransition(
                _config,
                input.tran.batchId,
                input.tran.parentHash,
                keccak256(abi.encode(aggregatedTranMeta))
            );
        }

        //   IInbox.TransitionMeta[] memory tranMetas = new IInbox.TransitionMeta[](1);
        //     tranMetas[0] = tranMeta;
        // emit IInbox.Proved(input.tran.batchId, _bindings.encodeTransitionMetas(tranMetas));

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

    /// @notice Upon proving a batch, the prover is expected to trust that the transition will
    /// eventually be used for batch verification. As a result, the prover should be willing to pay
    /// the provability bond on their behalf. Once the transition is used to verify the batch, the
    /// provability bond is returned to the prover, not the proposer.
    function _provePaysProvabilityBond(
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

    function _canAggregateTransitions(
        IInbox.TransitionMeta memory _tranMeta,
        IInbox.TransitionMeta memory _newTranMeta
    )
        private
        pure
        returns (bool)
    { }

    function _aggregateTransitions(
        IInbox.TransitionMeta memory _tranMeta,
        IInbox.TransitionMeta memory _newTranMeta
    )
        private
        pure
        returns (IInbox.TransitionMeta memory)
    { }

    // if (tranMeta.span == 0) {
    //     tranMeta = IInbox.TransitionMeta({
    //         provedAt: uint48(block.timestamp),
    //         prover: prover,
    //         proofTiming: proofTiming,
    //         blockHash: input.tran.blockHash,
    //         stateRoot: stateRoot,
    //         lastBlockId: input.proveMeta.lastBlockId,
    //         span: 1,
    //         provabilityBond: input.proveMeta.provabilityBond,
    //         livenessBond: input.proveMeta.livenessBond
    //     });
    // } else if (tranMeta.prover == prover && tranMeta.proofTiming == proofTiming) {
    //     tranMeta.blockHash = input.tran.blockHash;
    //     tranMeta.stateRoot = stateRoot;
    //     tranMeta.lastBlockId = input.proveMeta.lastBlockId;
    //     tranMeta.span += 1;
    //     tranMeta.provabilityBond +=input.proveMeta.provabilityBond;
    //     tranMeta.livenessBond += input.proveMeta.livenessBond;
    // } else {
    //       _bindings.saveTransition(
    //     _config, input.tran.batchId, input.tran.parentHash,
    // keccak256(abi.encode(tranMeta))
    // );

    // }

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
