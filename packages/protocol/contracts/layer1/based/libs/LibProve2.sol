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
        returns (I.Stats2 memory stats2_)
    {
        uint256 nBatches = _proveMetas.length;
        require(nBatches != 0, I.NoBlocksToProve());
        require(nBatches <= type(uint8).max, I.TooManyBatchesToProve());
        require(nBatches == _trans.length, I.ArraySizesMismatch());

        stats2_ = $.stats2;
        require(!stats2_.paused, I.ContractPaused());

        I.TransitionEvtData[] memory tranEvtDatas = new I.TransitionEvtData[](nBatches);
        IVerifier2.Context[] memory verifierCtxs = new IVerifier2.Context[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            (tranEvtDatas[i], verifierCtxs[i]) =
                _proveBatch($, _ctx, stats2_, _proveMetas[i], _trans[i]);
        }

        emit I.BatchesProved(_ctx.verifier, tranEvtDatas);
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
        returns (I.TransitionEvtData memory tranEvtData_, IVerifier2.Context memory verifierCtx_)
    {
        _validateTransition(_tran, _stats2);

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify the firstBlockId of the block in the following check.
        LibFork.checkBlocksInShastaFork(
            _ctx.config, _proveMeta.firstBlockId, _proveMeta.firstBlockId
        );

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
        if (batch.nextTransitionId > 1) {
            // This batch has at least one transition. Lets check if the first transition is to be
            // overwritten.
            if ($.transitions[slot][1].parentHash == _tran.parentHash) {
                tid = 1; // Overwrite the first transition.
            } else if (batch.nextTransitionId > 2) {
                // Retrieve the transition ID using the parent hash from the mapping. If the ID
                // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                // existing transition other than the first one.
                tid = $.transitionIds[_tran.batchId][_tran.parentHash];
            }
        }

        if (tid == 0) {
            // This transition is new, we need to use the next available ID
            unchecked {
                tid = uint16(batch.nextTransitionId);
                // increment the nextTransitionId by 1
                $.batches[slot].nextTransitionId = batch.nextTransitionId + 1;
            }
        }

        I.TransitionMeta memory tranMeta = I.TransitionMeta({
            parentHash: _tran.parentHash,
            blockHash: _tran.blockHash,
            stateRoot: _tran.batchId % _ctx.config.stateRootSyncInternal == 0
                ? _tran.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // inited below
            prover: address(0), // inited below
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _proveMeta.prover
        });

        (tranMeta.proofTiming, tranMeta.prover) = _determineProofTiming(
            _proveMeta.proposedAt.max(_stats2.lastUnpausedAt), _ctx.config, _proveMeta.prover
        );

        I.TransitionState memory tranState = I.TransitionState({
            parentHash: tid == 1 ? _tran.parentHash : bytes32(0),
            metaHash: keccak256(abi.encode(tranMeta))
        });

        $.transitions[slot][tid] = tranState;

        if (tid != 1) {
            $.transitionIds[_tran.batchId][_tran.parentHash] = tid;
        } else if (
            tranMeta.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _proveMeta.proposer
        ) {
            // Ensure msg.sender pays the provability bond to prevent malicious forfeiture
            // of the proposer's bond through an invalid first transition.
            LibBonds2.debitBond($, _ctx.bondToken, msg.sender, _proveMeta.provabilityBond);
            LibBonds2.creditBond($, _proveMeta.proposer, _proveMeta.provabilityBond);
        }

        tranEvtData_ = I.TransitionEvtData({ batchId: _tran.batchId, tid: tid, meta: tranMeta });
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

    function _validateTransition(
        I.Transition calldata _tran,
        I.Stats2 memory _stats2
    )
        private
        pure
    {
        require(_tran.batchId > _stats2.lastVerifiedBatchId, I.BatchNotFound());
        require(_tran.batchId < _stats2.numBatches, I.BatchNotFound());

        require(_tran.parentHash != 0, I.InvalidTransitionParentHash());
        require(_tran.blockHash != 0, I.InvalidTransitionBlockHash());
        require(_tran.stateRoot != 0, I.InvalidTransitionStateRoot());
    }
}
