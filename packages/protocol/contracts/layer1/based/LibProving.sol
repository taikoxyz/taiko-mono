// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/surge/verifiers/ISurgeVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";
import "./ITaikoInbox.sol";

/// @title LibProving
/// @notice This library is used to prove batches
/// @dev This library's prove function is made public to reduce TaikoInbox's code size.
/// @custom:security-contact security@nethermind.io
library LibProving {
    using LibProofType for LibProofType.ProofType;

    struct ProveBatchesParams {
        LibProofType.ProofType proofType;
        ITaikoInbox.BatchMetadata[] metas;
        ITaikoInbox.Transition[] trans;
    }

    /// @notice Proves batches and returns the updated stats2 and config
    /// @param _state The TaikoInbox state
    /// @param _config The TaikoInbox configuration
    /// @param _params The prove batches parameters
    /// @param _proof The proof data
    /// @param _verifier The verifier address
    /// @return stats2_ The updated stats2
    function proveBatches(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        ProveBatchesParams memory _params,
        bytes calldata _proof,
        address _verifier
    )
        public
        returns (ITaikoInbox.Stats2 memory stats2_)
    {
        require(_params.metas.length != 0, ITaikoInbox.NoBlocksToProve());
        require(_params.metas.length == _params.trans.length, ITaikoInbox.ArraySizesMismatch());

        stats2_ = _state.stats2;
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](_params.metas.length);

        // Surge: Remove `hasConflictingProof` variable

        for (uint256 i; i < _params.metas.length; ++i) {
            ITaikoInbox.BatchMetadata memory meta = _params.metas[i];

            require(meta.batchId >= _config.forkHeights.pacaya, ITaikoInbox.ForkNotActivated());
            require(
                _config.forkHeights.shasta == 0 || meta.batchId < _config.forkHeights.shasta,
                ITaikoInbox.BeyondCurrentFork()
            );

            require(meta.batchId > stats2_.lastVerifiedBatchId, ITaikoInbox.BatchNotFound());
            if (!stats2_.proposeWithProofMode) {
                require(meta.batchId < stats2_.numBatches, ITaikoInbox.BatchNotFound());
            }

            ITaikoInbox.Transition memory tran = _params.trans[i];
            require(tran.parentHash != 0, ITaikoInbox.InvalidTransitionParentHash());
            require(tran.blockHash != 0, ITaikoInbox.InvalidTransitionBlockHash());
            require(tran.stateRoot != 0, ITaikoInbox.InvalidTransitionStateRoot());

            ctxs[i].batchId = meta.batchId;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].transition = tran;

            // Verify the batch's metadata.
            uint256 slot = meta.batchId % _config.batchRingBufferSize;
            ITaikoInbox.Batch storage batch = _state.batches[slot];
            require(ctxs[i].metaHash == batch.metaHash, ITaikoInbox.MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;

            // Surge: block to avoid stack too deep
            {
                uint24 nextTransitionId = batch.nextTransitionId;
                if (nextTransitionId > 1) {
                    // This batch has at least one transition.
                    // Surge: get the first transition
                    if (_state.transitions[slot][1][0].parentHash == tran.parentHash) {
                        // Overwrite the first transition.
                        tid = 1;
                    } else if (nextTransitionId > 2) {
                        // Retrieve the transition ID using the parent hash from the mapping. If the
                        // ID
                        // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                        // existing transition.
                        tid = _state.transitionIds[meta.batchId][tran.parentHash];
                    }
                }
            }

            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                unchecked {
                    tid = batch.nextTransitionId++;
                }
            } else {
                ITaikoInbox.TransitionState[] storage transitions = _state.transitions[slot][tid];

                // Surge: `mti` is the matching transition index
                uint256 mti = type(uint256).max;
                {
                    // Surge: Try to find a matching transition
                    uint256 numTransitions = transitions.length;
                    for (uint256 j; j < numTransitions; ++j) {
                        bytes32 _blockHash = transitions[j].blockHash;
                        bytes32 _stateRoot = transitions[j].stateRoot;
                        if (
                            _blockHash == tran.blockHash
                                && (_stateRoot == 0 || _stateRoot == tran.stateRoot)
                        ) {
                            mti = j;
                            break;
                        }
                    }
                }

                // Surge: Remove the notion of reusing invalidated transitions since we no longer
                // invalidate on conflicting proofs

                // Surge: Modify the logic of checking for matching transitions based on the
                // new finality gadget

                // A matching transition was found
                if (mti != type(uint256).max) {
                    // Existing proof type of the matching transition
                    LibProofType.ProofType _proofType = transitions[mti].proofType;

                    // Take action depending upon existing proof type
                    if (
                        _proofType.isZkTeeProof()
                            || (_proofType.isZkProof() && _params.proofType.isZkProof())
                            || (_proofType.isTeeProof() && _params.proofType.isTeeProof())
                    ) {
                        // We skip the transition if the existing proof type is ZK + TEE or if the
                        // existing proof type is same as the newly submitted proof type
                        continue;
                    }

                    // At this point, the transition would be both ZK + TEE proven
                    transitions[mti].proofType = _proofType.combine(_params.proofType);
                    // The sender of the latest set of proofs becomes the bond receiver
                    transitions[mti].bondReceiver = msg.sender;
                } else {
                    ITaikoInbox.TransitionState memory _ts;

                    // Add the conflicting transition
                    _ts.blockHash = tran.blockHash;
                    _ts.stateRoot = meta.batchId % _config.stateRootSyncInternal == 0
                        ? tran.stateRoot
                        : bytes32(0);
                    _ts.proofType = _params.proofType;

                    // If the conflicting transition is finalising, the sender of the proof becomes
                    // the bond receiver
                    if (_params.proofType.isZkTeeProof()) {
                        _ts.bondReceiver = msg.sender;
                    }

                    // _ts.createdAt may not be set since it is irrelevant for conflicting
                    // transitions

                    transitions.push(_ts);

                    emit ITaikoInbox.ConflictingProof(meta.batchId, _ts, tran);
                }

                // Surge: remove transition state and shift it to the conditionals above

                // Proceed with other transitions.
                continue;
            }

            // Surge: prepare the transition state in memory instead of storage
            ITaikoInbox.TransitionState memory __ts;

            if (tid == 1) {
                __ts.parentHash = tran.parentHash;
            } else {
                _state.transitionIds[meta.batchId][tran.parentHash] = tid;
            }

            __ts.blockHash = tran.blockHash;
            __ts.stateRoot =
                meta.batchId % _config.stateRootSyncInternal == 0 ? tran.stateRoot : bytes32(0);
            __ts.proofType = _params.proofType;

            bool inProvingWindow;
            unchecked {
                inProvingWindow =
                    block.timestamp <= uint256(meta.proposedAt) + _config.provingWindow;
            }

            // Surge: Set the bond receiver based on the proving window and received proof type
            if (_params.proofType.isZkTeeProof()) {
                __ts.bondReceiver = inProvingWindow ? meta.proposer : msg.sender;
            }

            // Surge: Remove initialising `ts.provingWindow` and `ts.prover`

            __ts.createdAt = uint48(block.timestamp);

            // Surge: add the transition to the transitions array in storage
            _state.transitions[slot][tid].push(__ts);
        }

        // Surge: We use the ISurgeVerifier interface
        LibProofType.ProofType __proofType = ISurgeVerifier(_verifier).verifyProof(ctxs, _proof);
        // Surge: check that proof type sent in the parameters matches the
        // proof type returned by the verifier
        require(__proofType.equals(_params.proofType), ITaikoInbox.InvalidProofType());

        // Emit the event
        {
            uint64[] memory batchIds = new uint64[](_params.metas.length);
            for (uint256 i; i < _params.metas.length; ++i) {
                batchIds[i] = _params.metas[i].batchId;
            }

            emit ITaikoInbox.BatchesProved(_verifier, batchIds, _params.trans);
        }
    }
}
