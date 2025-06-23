// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./LibBonds2.sol";
import "./LibFork.sol";

/// @title LibProve
/// @custom:security-contact security@taiko.xyz
library LibProve {
    using LibMath for uint256;

    // The struct is introdueced to avoid stack too deep error.
    struct Context {
        I.Config config;
        address bondToken;
        address verifier;
    }

    function proveBatches(
        I.State storage $,
        Context memory _ctx,
        bytes calldata _proof,
        I.BatchProveMetadata[] calldata _proveMetas,
        I.Transition[] calldata _trans
    )
        public // reduce code size
        returns (I.Stats2 memory stats2_, bool hasConflictingProof_)
    {
        uint256 nBatches = _proveMetas.length;
        require(nBatches != 0, I.NoBlocksToProve());
        require(nBatches <= type(uint8).max, I.TooManyBatchesToProve());
        require(nBatches == _trans.length, I.ArraySizesMismatch());

        stats2_ = $.stats2;
        require(!stats2_.paused, I.ContractPaused());

        IVerifier2.Context[] memory verifierCtxs = new IVerifier2.Context[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            bool hasConflictingProof;
            (hasConflictingProof, verifierCtxs[i]) =
                _proveBatch($, _ctx, stats2_, _proveMetas[i], _trans[i]);
            hasConflictingProof_ = hasConflictingProof_ || hasConflictingProof;
        }

        emit I.BatchesProved(_ctx.verifier, _trans);
        IVerifier2(_ctx.verifier).verifyProof(verifierCtxs, _proof);
    }

    function _proveBatch(
        I.State storage $,
        Context memory _ctx,
        I.Stats2 memory _stats2,
        I.BatchProveMetadata calldata _proveMeta,
        I.Transition calldata _tran
    )
        private
        returns (bool hasConflictingProof_, IVerifier2.Context memory verifierCtx_)
    {
        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify the firstBlockId of the block in the following check.
        LibFork.checkBlocksInShastaFork(
            _ctx.config, _proveMeta.firstBlockId, _proveMeta.firstBlockId
        );

        require(_tran.batchId > _stats2.lastVerifiedBatchId, I.BatchNotFound());
        require(_tran.batchId < _stats2.numBatches, I.BatchNotFound());

        require(_tran.parentHash != 0, I.InvalidTransitionParentHash());
        require(_tran.blockHash != 0, I.InvalidTransitionBlockHash());
        require(_tran.stateRoot != 0, I.InvalidTransitionStateRoot());

        // Verify the batch's metadata.
        uint256 slot = _tran.batchId % _ctx.config.batchRingBufferSize;
        I.Batch memory batch = $.batches[slot];

        // TODO
        // require(verifierCtx_.metaHash == batch.metaHash, I.MetaHashMismatch());

        verifierCtx_ =
            IVerifier2.Context({ metaHash: batch.metaHash, transition: _tran, prover: msg.sender });

        // Finds out if this transition is overwriting an existing one (with the same parent
        // hash) or is a new one.
        uint16 tid;
        int16 nextTransitionId = batch.nextTransitionId;
        if (nextTransitionId > 1) {
            // This batch has at least one transition.
            if ($.transitions[slot][1].parentHash == _tran.parentHash) {
                // Overwrite the first transition.
                tid = 1;
            } else if (nextTransitionId > 2) {
                // Retrieve the transition ID using the parent hash from the mapping. If the ID
                // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                // existing transition.
                tid = $.transitionIds[_tran.batchId][_tran.parentHash];
            }
        }

        if (tid == 0) {
            // This transition is new, we need to use the next available ID.
            unchecked {
                tid = uint16(nextTransitionId);
                $.batches[slot].nextTransitionId = nextTransitionId + 1;
            }
        } else {
            I.TransitionState memory _ts = $.transitions[slot][tid];
            if (_ts.blockHash == 0) {
                // This transition has been invalidated due to a conflicting proof.
                // So we can reuse the transition ID.
            } else {
                bool isSameTransition = _ts.blockHash == _tran.blockHash
                    && (_ts.stateRoot == 0 || _ts.stateRoot == _tran.stateRoot);

                if (isSameTransition) {
                    // Re-approving the same transition is allowed, but we will not change the
                    // existing one.
                } else {
                    // A conflict is detected with the new transition. Pause the contract and
                    // invalidate the existing transition by setting its blockHash to 0.
                    $.transitions[slot][tid].blockHash = 0;
                    emit I.ConflictingProof(_tran.batchId, _ts, _tran);
                    hasConflictingProof_ = true;
                }

                return (hasConflictingProof_, verifierCtx_);
            }
        }

        (I.ProofTiming proofTiming, address prover) = _determineProofTiming(
            _proveMeta.proposedAt.max(_stats2.lastUnpausedAt), _ctx.config, _proveMeta.prover
        );

        // TODO: use one single slot, do not store the transitions in storage.
        I.TransitionState memory ts = I.TransitionState({
            parentHash: tid == 1 ? _tran.parentHash : bytes32(0),
            blockHash: _tran.blockHash,
            stateRoot: _tran.batchId % _ctx.config.stateRootSyncInternal == 0
                ? _tran.stateRoot
                : bytes32(0),
            proofTiming: proofTiming,
            prover: prover,
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _proveMeta.prover
        });

        $.transitions[slot][tid] = ts;

        if (tid != 1) {
            $.transitionIds[_tran.batchId][_tran.parentHash] = tid;
        } else if (
            ts.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _proveMeta.proposer
        ) {
            // Ensure msg.sender pays the provability bond to prevent malicious forfeiture
            // of the proposer's bond through an invalid first transition.
            LibBonds2.debitBond($, _ctx.bondToken, msg.sender, _proveMeta.provabilityBond);
            LibBonds2.creditBond($, _proveMeta.proposer, _proveMeta.provabilityBond);
        }
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
}
