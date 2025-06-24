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

    bytes32 internal constant FIRST_TRAN_PARENT_HASH_PLACEHOLDER = bytes32(type(uint256).max);

    // The struct is introdueced to avoid stack too deep error.
    struct Env {
        I.Config config;
        address bondToken;
        address verifier;
    }

    function proveBatches(
        I.State storage $,
        Env memory _env,
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

        stats2_ = $.stats2; // make a read-only copy
        require(!stats2_.paused, I.ContractPaused());

        I.TransitionMeta[] memory tranMetas = new I.TransitionMeta[](nBatches);
        IVerifier2.Context[] memory ctxs = new IVerifier2.Context[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            (tranMetas[i], ctxs[i]) = _proveBatch($, _env, stats2_, _proveMetas[i], _trans[i]);
        }

        emit I.BatchesProved(_env.verifier, tranMetas);
        IVerifier2(_env.verifier).verifyProof(ctxs, _proof);
    }

    function _proveBatch(
        I.State storage $,
        Env memory _env,
        I.Stats2 memory _stats2,
        I.BatchProveMetadata calldata _proveMeta,
        I.Transition calldata _tran
    )
        private
        returns (I.TransitionMeta memory tranMeta_, IVerifier2.Context memory ctx_)
    {
        _validateTransition(_tran, _stats2);

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify the firstBlockId of the block in the following check.
        LibFork.checkBlocksInShastaFork(
            _env.config, _proveMeta.firstBlockId, _proveMeta.firstBlockId
        );

        // Verify the batch's metadata.
        uint256 slot = _tran.batchId % _env.config.batchRingBufferSize;
        I.Batch memory batch = $.batches[slot];

        // TODO
        // require(verifierCtx_.metaHash == batch.metaHash, I.MetaHashMismatch());

        ctx_ =
            IVerifier2.Context({ metaHash: batch.metaHash, transition: _tran, prover: msg.sender });

        tranMeta_ = I.TransitionMeta({
            parentHash: _tran.parentHash,
            blockHash: _tran.blockHash,
            stateRoot: _tran.batchId % _env.config.stateRootSyncInternal == 0
                ? _tran.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // inited below
            prover: address(0), // inited below
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _proveMeta.prover
        });

        (tranMeta_.proofTiming, tranMeta_.prover) = _determineProofTiming(
            _proveMeta.proposedAt.max(_stats2.lastUnpausedAt), _env.config, _proveMeta.prover
        );

        bytes32 metaHash = keccak256(abi.encode(tranMeta_));
        if ($.transitions[slot][1].parentHash == FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
            $.transitions[slot][1] = I.TransitionState(_tran.parentHash, metaHash);
        } else {
            $.transitionMetaHashes[_tran.batchId][_tran.parentHash] = metaHash;

            if (
                tranMeta_.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                    && msg.sender != _proveMeta.proposer
            ) {
                // Ensure msg.sender pays the provability bond to prevent malicious forfeiture
                // of the proposer's bond through an invalid first transition.
                LibBonds2.debitBond($, _env.bondToken, msg.sender, _proveMeta.provabilityBond);
                LibBonds2.creditBond($, _proveMeta.proposer, _proveMeta.provabilityBond);
            }
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
