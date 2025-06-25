// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./LibData2.sol";
import "./LibBonds2.sol";
import "./LibFork2.sol";

/// @title LibProve2
/// @custom:security-contact security@taiko.xyz
library LibProve2 {
    using LibMath for uint256;

    error BlocksNotInCurrentFork();
    error InvalidSummary();
    error MetaHashNotMatch();

    function proveBatches(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary calldata _summary,
        I.BatchProveMetadataEvidence[] calldata _evidences,
        I.Transition[] calldata _trans,
        bytes calldata _proof
    )
        internal
    {
        bool paused = LibData2.validateSummary($, _summary);
        require(!paused, I.ContractPaused());

        uint256 nBatches = _evidences.length;
        require(nBatches != 0, I.NoBlocksToProve());
        require(nBatches <= type(uint8).max, I.TooManyBatchesToProve());
        require(nBatches == _trans.length, I.ArraySizesMismatch());

        I.TransitionMeta[] memory metas = new I.TransitionMeta[](nBatches);
        bytes32[] memory ctxHashes = new bytes32[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            (metas[i], ctxHashes[i]) = _proveBatch($, _env, _summary, _evidences[i], _trans[i]);
        }

        emit I.BatchesProved(_env.verifier, metas);

        bytes32 contextHash =
            keccak256(abi.encode(_env.config.chainId, msg.sender, _env.verifier, ctxHashes));
        IVerifier2(_env.verifier).verifyProof(contextHash, _proof);
    }

    function _proveBatch(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary memory _summary,
        I.BatchProveMetadataEvidence calldata _evidence,
        I.Transition calldata _tran
    )
        private
        returns (I.TransitionMeta memory tranMeta_, bytes32 batchContextHash_)
    {
        _validateTransition(_tran, _summary);

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify the firstBlockId of the block in the following check.
        require(
            LibFork2.isBlocksInCurrentFork(
                _env.config, _evidence.proveMeta.firstBlockId, _evidence.proveMeta.firstBlockId
            ),
            BlocksNotInCurrentFork()
        );

        // Verify the batch's metadata.
        uint256 slot = _tran.batchId % _env.config.batchRingBufferSize;
        I.Batch memory batch = $.batches[slot]; // 1 SLOAD

        _validateBatchProveMeta(batch.metaHash, _evidence);

        batchContextHash_ = keccak256(abi.encode(batch.metaHash, _tran));

        tranMeta_ = I.TransitionMeta({
            parentHash: _tran.parentHash,
            blockHash: _tran.blockHash,
            stateRoot: _tran.batchId % _env.config.stateRootSyncInternal == 0
                ? _tran.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // to be updated below
            prover: address(0), // to be updated below
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _evidence.proveMeta.prover,
            lastBlockId: _evidence.proveMeta.lastBlockId,
            provabilityBond: _evidence.proveMeta.provabilityBond,
            livenessBond: _evidence.proveMeta.livenessBond
        });

        (tranMeta_.proofTiming, tranMeta_.prover) = _determineProofTiming(
            uint256(_evidence.proveMeta.proposedAt).max(_summary.lastProposedIn),
            _env.config,
            _evidence.proveMeta.prover
        );

        // In the next code section, we always use `$.transitions[slot][1]` to reuse a previously
        // declared state variable -- note that the second mapping key is always 1.
        // Tip: the reuse of the first transition slot can save 3900 gas per batch.
        bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
        bytes32 metaHash = keccak256(abi.encode(tranMeta_));
        if (
            firstTransitionParentHash == _tran.parentHash
                || firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER
        ) {
            $.transitions[slot][1].metaHash = metaHash; // 1 SSTORE

            // This is the very first transition of the batch, or a transition with the same parent
            // hash. We can reuse the transition state slot to reduce gas cost.
            if (firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
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

    function _validateBatchProveMeta(
        bytes32 _batchMetaHash,
        I.BatchProveMetadataEvidence calldata _evidence
    )
        private
        pure
    {
        bytes32 proveMetaHash = keccak256(abi.encode(_evidence.proveMeta));
        bytes32 rightHash = keccak256(abi.encode(_evidence.proposeMetaHash, proveMetaHash));
        bytes32 metaHash = keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));

        require(_batchMetaHash == metaHash, MetaHashNotMatch());
    }

    function _validateTransition(
        I.Transition calldata _tran,
        I.Summary memory _summary
    )
        private
        pure
    {
        require(_tran.batchId > _summary.lastVerifiedBatchId, I.BatchNotFound());
        require(_tran.batchId < _summary.numBatches, I.BatchNotFound());
        require(_tran.blockHash != 0, I.InvalidTransitionBlockHash());
        require(_tran.stateRoot != 0, I.InvalidTransitionStateRoot());
        require(
            _tran.parentHash != 0 && _tran.parentHash != LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER,
            I.InvalidTransitionParentHash()
        );
    }
}
