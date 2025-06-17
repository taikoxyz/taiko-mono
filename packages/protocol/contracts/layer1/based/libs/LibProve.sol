// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox as I } from "../ITaikoInbox.sol";
import "src/shared/libs/LibMath.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./LibBonds.sol";

/// @title LibProve
/// @custom:security-contact security@taiko.xyz
library LibProve {
    using LibMath for uint256;

    // The struct is introdueced to avoid stack too deep error.
    struct Input {
        I.Config config;
        address bondToken;
        address verifier;
    }

    // The struct is introdueced to avoid stack too deep error.
    struct Output {
        bool hasConflictingProof;
        I.Stats2 stats2;
        I.BatchMetadata[] metas;
        IVerifier.Context[] ctxs;
    }

    function proveBatches(
        I.State storage $,
        Input memory _input,
        bytes calldata _params,
        bytes calldata _proof
    )
        internal
        returns (Output memory output_)
    {
        I.Transition[] memory trans;
        (output_.metas, trans) = abi.decode(_params, (I.BatchMetadata[], I.Transition[]));

        require(output_.metas.length != 0, I.NoBlocksToProve());
        require(output_.metas.length <= type(uint8).max, I.TooManyBatchesToProve());
        require(output_.metas.length == trans.length, I.ArraySizesMismatch());

        output_.stats2 = $.stats2;
        require(!output_.stats2.paused, I.ContractPaused());

        output_.ctxs = new IVerifier.Context[](output_.metas.length);

        for (uint256 i; i < output_.metas.length; ++i) {
            // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
            // Hence, we only need to verify the firstBlockId of the block in the following check.
            _checkBatchInForkRange(
                _input.config, output_.metas[i].firstBlockId, output_.metas[i].firstBlockId
            );

            require(
                output_.metas[i].batchId > output_.stats2.lastVerifiedBatchId, I.BatchNotFound()
            );
            require(output_.metas[i].batchId < output_.stats2.numBatches, I.BatchNotFound());

            require(trans[i].parentHash != 0, I.InvalidTransitionParentHash());
            require(trans[i].blockHash != 0, I.InvalidTransitionBlockHash());
            require(trans[i].stateRoot != 0, I.InvalidTransitionStateRoot());

            output_.ctxs[i].batchId = output_.metas[i].batchId;
            output_.ctxs[i].metaHash = keccak256(abi.encode(output_.metas[i]));
            output_.ctxs[i].transition = trans[i];
            output_.ctxs[i].prover = msg.sender;

            // Verify the batch's metadata.
            uint256 slot = output_.metas[i].batchId % _input.config.batchRingBufferSize;
            I.Batch storage batch = $.batches[slot];
            require(output_.ctxs[i].metaHash == batch.metaHash, I.MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;
            uint24 nextTransitionId = batch.nextTransitionId;
            if (nextTransitionId > 1) {
                // This batch has at least one transition.
                if ($.transitions[slot][1].parentHash == trans[i].parentHash) {
                    // Overwrite the first transition.
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    // Retrieve the transition ID using the parent hash from the mapping. If the ID
                    // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                    // existing transition.
                    tid = $.transitionIds[output_.metas[i].batchId][trans[i].parentHash];
                }
            }

            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                unchecked {
                    tid = batch.nextTransitionId++;
                }
            } else {
                I.TransitionState memory _ts = $.transitions[slot][tid];
                if (_ts.blockHash == 0) {
                    // This transition has been invalidated due to a conflicting proof.
                    // So we can reuse the transition ID.
                } else {
                    bool isSameTransition = _ts.blockHash == trans[i].blockHash
                        && (_ts.stateRoot == 0 || _ts.stateRoot == trans[i].stateRoot);

                    if (isSameTransition) {
                        // Re-approving the same transition is allowed, but we will not change the
                        // existing one.
                    } else {
                        // A conflict is detected with the new transition. Pause the contract and
                        // invalidate the existing transition by setting its blockHash to 0.
                        $.transitions[slot][tid].blockHash = 0;
                        emit I.ConflictingProof(output_.metas[i].batchId, _ts, trans[i]);
                        output_.hasConflictingProof = true;
                    }

                    // Proceed with other transitions.
                    continue;
                }
            }

            I.TransitionState storage ts = $.transitions[slot][tid];

            ts.blockHash = trans[i].blockHash;
            ts.stateRoot = output_.metas[i].batchId % _input.config.stateRootSyncInternal == 0
                ? trans[i].stateRoot
                : bytes32(0);

            (ts.proofTiming, ts.prover) = _determineProofTiming(
                uint256(output_.metas[i].proposedAt).max(output_.stats2.lastUnpausedAt),
                _input.config,
                output_.metas[i].prover
            );

            ts.createdAt = uint48(block.timestamp);
            ts.byAssignedProver = msg.sender == output_.metas[i].prover;

            if (tid == 1) {
                ts.parentHash = trans[i].parentHash;

                // The prover for the first transition is responsible for placing the provability
                // if the transition is within extended proving window.
                if (
                    ts.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                        && msg.sender != output_.metas[i].proposer
                ) {
                    // Ensure msg.sender pays the provability bond to prevent malicious forfeiture
                    // of the proposer's bond through an invalid first transition.
                    uint96 provabilityBond = batch.provabilityBond;
                    LibBonds.debitBond($, _input.bondToken, msg.sender, provabilityBond);
                    LibBonds.creditBond($, output_.metas[i].proposer, provabilityBond);
                }
            } else {
                $.transitionIds[output_.metas[i].batchId][trans[i].parentHash] = tid;
            }
        }

        IVerifier(_input.verifier).verifyProof(output_.ctxs, _proof);

        // Emit the event
        uint64[] memory batchIds = new uint64[](output_.metas.length);
        for (uint256 i; i < output_.metas.length; ++i) {
            batchIds[i] = output_.metas[i].batchId;
        }

        emit I.BatchesProved(_input.verifier, batchIds, trans);
    }

    /// @dev Decides which time window we are in and who should be recorded as the prover.
    function _determineProofTiming(
        uint256 _proposedAt,
        I.Config memory _config,
        address _assignedProver
    )
        private
        view
        returns (I.ProofTiming timing_, address prover_)
    {
        if (block.timestamp <= _proposedAt + _config.provingWindow) {
            return (I.ProofTiming.InProvingWindow, _assignedProver);
        } else if (block.timestamp <= _proposedAt + _config.extendedProvingWindow) {
            return (I.ProofTiming.InExtendedProvingWindow, msg.sender);
        } else {
            return (I.ProofTiming.OutOfExtendedProvingWindow, msg.sender);
        }
    }

    /// @dev Check this batch is between current fork height (inclusive) and next fork height
    /// (exclusive)
    function _checkBatchInForkRange(
        I.Config memory _config,
        uint64 _firstBlockId,
        uint64 _lastBlockId
    )
        internal
        pure
    {
        require(_firstBlockId >= _config.forkHeights.shasta, I.ForkNotActivated());
        require(
            _config.forkHeights.unzen == 0 || _lastBlockId < _config.forkHeights.unzen,
            I.BeyondCurrentFork()
        );
    }
}
