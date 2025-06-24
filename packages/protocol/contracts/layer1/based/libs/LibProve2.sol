// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./LibData2.sol";
import "./LibBonds2.sol";
import "./LibFork.sol";

/// @title LibProve
/// @custom:security-contact security@taiko.xyz
library LibProve {
    using LibMath for uint256;

    error BlocksNotInCurrentFork();

    bytes32 internal constant FIRST_TRAN_PARENT_HASH_PLACEHOLDER = bytes32(type(uint256).max);

    function proveBatches(
        LibData2.Env memory _env,
        I.State storage $,
        bytes calldata _proof,
        I.BatchProveMetadataEvidence[] calldata _evidences,
        I.Transition[] calldata _trans
    )
        internal
        returns (I.Stats2 memory stats2_)
    {
        uint256 nBatches = _evidences.length;
        require(nBatches != 0, I.NoBlocksToProve());
        require(nBatches <= type(uint8).max, I.TooManyBatchesToProve());
        require(nBatches == _trans.length, I.ArraySizesMismatch());

        stats2_ = $.stats2; // make a read-only copy, 1 SLOAD
        require(!stats2_.paused, I.ContractPaused());

        I.TransitionMeta[] memory metas = new I.TransitionMeta[](nBatches);
        IVerifier2.Context[] memory ctxs = new IVerifier2.Context[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            (metas[i], ctxs[i]) = _proveBatch(_env, $, stats2_, _evidences[i], _trans[i]);
        }

        emit I.BatchesProved(_env.verifier, metas);
        IVerifier2(_env.verifier).verifyProof(ctxs, _proof);
    }

    function _proveBatch(
        LibData2.Env memory _env,
        I.State storage $,
        I.Stats2 memory _stats2,
        I.BatchProveMetadataEvidence calldata _evidence,
        I.Transition calldata _tran
    )
        private
        returns (I.TransitionMeta memory tranMeta_, IVerifier2.Context memory ctx_)
    {
        _validateTransition(_tran, _stats2);

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify the firstBlockId of the block in the following check.
        require(
            LibFork.isBlocksInCurrentFork(
                _env.config,
                _evidence.proveMeta.firstBlockId,
                _evidence.proveMeta.firstBlockId,
                false
            ),
            BlocksNotInCurrentFork()
        );

        // Verify the batch's metadata.
        uint256 slot = _tran.batchId % _env.config.batchRingBufferSize;
        I.Batch memory batch = $.batches[slot]; // 1 SLOAD

        _validateBatchProveMeta(_tran.batchId, batch.metaHash, _evidence);

        ctx_ = IVerifier2.Context({
            batchId: _tran.batchId,
            metaHash: batch.metaHash,
            transition: _tran,
            prover: msg.sender
        });

        tranMeta_ = I.TransitionMeta({
            parentHash: _tran.parentHash,
            blockHash: _tran.blockHash,
            stateRoot: _tran.stateRoot,
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // to be updated below
            prover: address(0), // to be updated below
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _evidence.proveMeta.prover
        });

        (tranMeta_.proofTiming, tranMeta_.prover) = _determineProofTiming(
            _evidence.proveMeta.proposedAt.max(_stats2.lastUnpausedAt),
            _env.config,
            _evidence.proveMeta.prover
        );

        // In the next code section, we always use `$.transitions[slot][1]` to reuse a previously
        // declared state variable -- note that the second mapping key is always 1.
        bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
        bytes32 metaHash = keccak256(abi.encode(tranMeta_));
        if (
            firstTransitionParentHash == _tran.parentHash
                || firstTransitionParentHash == FIRST_TRAN_PARENT_HASH_PLACEHOLDER
        ) {
            $.transitions[slot][1].metaHash = metaHash; // 1 SSTORE

            // This is the very first transition of the batch, or a transition with the same parent
            // hash. We can reuse the transition state slot to reduce gas cost.
            if (firstTransitionParentHash == FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
                $.transitions[slot][1].parentHash = _tran.parentHash; // 1 SSTORE

                // The prover for the first transition is responsible for placing the provability
                // if the transition is within extended proving window.
                if (
                    tranMeta_.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                        && msg.sender != _evidence.proveMeta.proposer
                ) {
                    // Ensure msg.sender pays the provability bond to prevent malicious forfeiture
                    // of the proposer's bond through an invalid first transition.
                    LibBonds2.debitBond(
                        $, _env.bondToken, msg.sender, _evidence.proveMeta.provabilityBond
                    );
                    LibBonds2.creditBond(
                        $, _evidence.proveMeta.proposer, _evidence.proveMeta.provabilityBond
                    );
                }
            }
        } else {
            // This is not the very first transition of the batch, or a transition with the same
            // parent hash. Use a mapping to store the meta hash of the transition. The mapping
            // slots are not reusable.
            $.transitionMetaHashes[_tran.batchId][_tran.parentHash] = metaHash; // 1 SSTORE
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

    function _validateBatchProveMeta(
        uint256 _batchId,
        bytes32 _batchMetaHash,
        I.BatchProveMetadataEvidence calldata _evidence
    )
        private
        pure
    {
        bytes32 h = keccak256(abi.encode(_evidence.proveMeta));
        h = keccak256(abi.encode(h, _evidence.verifyMetaHash));
        h = keccak256(abi.encode(_batchId, _evidence.buildProposeHash, h));

        require(_batchMetaHash == h, "Invalid parent batch");
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
        require(_tran.blockHash != 0, I.InvalidTransitionBlockHash());
        require(_tran.stateRoot != 0, I.InvalidTransitionStateRoot());
        require(
            _tran.parentHash != 0 && _tran.parentHash != FIRST_TRAN_PARENT_HASH_PLACEHOLDER,
            I.InvalidTransitionParentHash()
        );
    }
}
