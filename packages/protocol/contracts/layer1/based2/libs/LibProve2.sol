// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "./LibData2.sol";
import "./LibBonds2.sol";
import "./LibFork2.sol";

/// @title LibProve2
/// @custom:security-contact security@taiko.xyz
library LibProve2 {
    using LibMath for uint256;

    error BatchNotFound();
    error BlocksNotInCurrentFork();
    error ContractPaused();
    error InvalidSummary();
    error InvalidTransitionParentHash();
    error MetaHashNotMatch();
    error NoBlocksToProve();
    error TooManyBatchesToProve();

    struct Environment {
        // reads
        I.Config conf;
        address sender;
        uint48 blockTimestamp;
        uint48 blockNumber;
        address verifier;
        // writes
        function(address, address, uint256) debitBond;
        function(address, uint256) creditBond;
        function(I.Config memory, uint256, bytes32, bytes32) returns (bool) saveTransition;
    }

    function proveBatches(
        I.State storage $,
        Environment memory _env,
        I.Summary calldata _summary, //TODO: change this memory will avoid multiple time access to
            // calldata?
        I.BatchProveInput[] calldata _evidences
    )
        internal
        returns (bytes32 aggregatedBatchHash_)
    {
        bool paused = LibData2.validateSummary($, _summary);
        require(!paused, ContractPaused());

        uint256 nBatches = _evidences.length;
        require(nBatches != 0, NoBlocksToProve());
        require(nBatches <= type(uint8).max, TooManyBatchesToProve());

        I.TransitionMeta[] memory metas = new I.TransitionMeta[](nBatches);
        bytes32[] memory ctxHashes = new bytes32[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            (metas[i], ctxHashes[i]) = _proveBatch($, _env, _summary, _evidences[i]);
        }
        aggregatedBatchHash_ =
            keccak256(abi.encode(_env.conf.chainId, msg.sender, _env.verifier, ctxHashes));

        emit I.BatchesProved(_env.verifier, metas);
    }

    function _proveBatch(
        I.State storage $,
        Environment memory _env,
        I.Summary calldata _summary, //TODO: change this memory will avoid multiple time access to
            // calldata?
        I.BatchProveInput calldata _input
    )
        private
        returns (I.TransitionMeta memory tranMeta_, bytes32 ctxHash_)
    {
        require(_input.transition.batchId > _summary.lastVerifiedBatchId, BatchNotFound());
        require(_input.transition.batchId < _summary.numBatches, BatchNotFound());
        require(_input.transition.parentHash != 0, InvalidTransitionParentHash());

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify        the firstBlockId of the block in the following
        // check.
        require(
            LibFork2.isBlocksInCurrentFork(
                _env.conf, _input.proveMeta.firstBlockId, _input.proveMeta.firstBlockId
            ),
            BlocksNotInCurrentFork()
        );

        // Verify the batch's metadata.
        uint256 slot = _input.transition.batchId % _env.conf.batchRingBufferSize;
        bytes32 batchMetaHash = $.batches[slot]; // 1 SLOAD

        _validateBatchProveMeta(batchMetaHash, _input);

        ctxHash_ = keccak256(abi.encode(batchMetaHash, _input.transition));

        tranMeta_ = I.TransitionMeta({
            parentHash: _input.transition.parentHash,
            blockHash: _input.transition.blockHash,
            stateRoot: _input.transition.batchId % _env.conf.stateRootSyncInternal == 0
                ? _input.transition.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // to be updated below
            prover: address(0), // to be updated below
            createdAt: uint48(block.timestamp),
            byAssignedProver: msg.sender == _input.proveMeta.prover,
            lastBlockId: _input.proveMeta.lastBlockId,
            provabilityBond: _input.proveMeta.provabilityBond,
            livenessBond: _input.proveMeta.livenessBond
        });

        (tranMeta_.proofTiming, tranMeta_.prover) = _determineProofTiming(
            _env.conf,
            _input.proveMeta.prover,
            uint256(_input.proveMeta.proposedAt).max(_summary.lastProposedIn)
        );

        bytes32 tranMetaHash = keccak256(abi.encode(tranMeta_));

        bool isFirstTransition = _env.saveTransition(
            _env.conf, _input.transition.batchId, _input.transition.parentHash, tranMetaHash
        );
        if (
            isFirstTransition && tranMeta_.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _input.proveMeta.proposer
        ) {
            _env.debitBond(_env.conf.bondToken, msg.sender, _input.proveMeta.provabilityBond);
            _env.creditBond(_input.proveMeta.proposer, _input.proveMeta.provabilityBond);
        }
    }

    /// @dev Decides which time window we are in and who should be recorded as the prover.
    function _determineProofTiming(
        I.Config memory _config,
        address _assignedProver,
        uint256 _proposedAt
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
        I.BatchProveInput calldata _input
    )
        private
        pure
    {
        bytes32 proveMetaHash = keccak256(abi.encode(_input.proveMeta));
        bytes32 rightHash = keccak256(abi.encode(_input.proposeMetaHash, proveMetaHash));
        bytes32 metaHash = keccak256(abi.encode(_input.idAndBuildHash, rightHash));

        require(_batchMetaHash == metaHash, MetaHashNotMatch());
    }
}
