// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibMath.sol";
import "./LibBondManagement.sol";
import "./LibForks.sol";

/// @title LibBatchProving
/// @custom:security-contact security@taiko.xyz
library LibBatchProving {
    using LibMath for uint256;

    struct ReadWrite {
        // reads
        uint48 blockTimestamp;
        uint48 blockNumber;
        // writes
        function(address, uint256) creditBond;
        function(I.Config memory, address, uint256) debitBond;
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        function(I.Config memory, uint256) returns (bytes32) getBatchMetaHash;
    }

    function proveBatches(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _evidences
    )
        internal
        returns (I.Summary memory, bytes32)
    {
        uint256 nBatches = _evidences.length;
        require(nBatches != 0, NoBlocksToProve());
        require(nBatches <= type(uint8).max, TooManyBatchesToProve());

        bytes32[] memory ctxHashes = new bytes32[](nBatches);

        for (uint256 i; i < nBatches; ++i) {
            ctxHashes[i] = _proveBatch(_conf, _rw, _summary, _evidences[i]);
        }

        bytes32 aggregatedBatchHash =
            keccak256(abi.encode(_conf.chainId, msg.sender, _conf.verifier, ctxHashes));

        return (_summary, aggregatedBatchHash);
    }

    function _proveBatch(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Summary memory _summary,
        I.BatchProveInput calldata _input
    )
        private
        returns (bytes32)
    {
        require(_input.tran.batchId > _summary.lastVerifiedBatchId, BatchNotFound());
        require(_input.tran.batchId < _summary.numBatches, BatchNotFound());
        require(_input.tran.parentHash != 0, InvalidtranParentHash());

        // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
        // Hence, we only need to verify        the firstBlockId of the block in the following
        // check.
        require(
            LibForks.isBlocksInCurrentFork(
                _conf, _input.proveMeta.firstBlockId, _input.proveMeta.firstBlockId
            ),
            BlocksNotInCurrentFork()
        );

        // Verify the batch's metadata.
        bytes32 batchMetaHash = _rw.getBatchMetaHash(_conf, _input.tran.batchId);

        _validateBatchProveMeta(batchMetaHash, _input);

        I.TransitionMeta memory tranMeta = I.TransitionMeta({
            parentHash: _input.tran.parentHash,
            blockHash: _input.tran.blockHash,
            stateRoot: _input.tran.batchId % _conf.stateRootSyncInternal == 0
                ? _input.tran.stateRoot
                : bytes32(0),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow, // to be updated below
            prover: address(0), // to be updated below
            createdAt: _rw.blockTimestamp,
            byAssignedProver: msg.sender == _input.proveMeta.prover,
            lastBlockId: _input.proveMeta.lastBlockId,
            provabilityBond: _input.proveMeta.provabilityBond,
            livenessBond: _input.proveMeta.livenessBond
        });

        (tranMeta.proofTiming, tranMeta.prover) = _determineProofTiming(
            _conf,
            _rw,
            _input.proveMeta.prover,
            uint256(_input.proveMeta.proposedAt).max(_summary.lastUnpausedAt)
        );

        bytes32 tranMetaHash = keccak256(abi.encode(tranMeta));

        bool isFirstTransition =
            _rw.saveTransition(_conf, _input.tran.batchId, _input.tran.parentHash, tranMetaHash);
        if (
            isFirstTransition && tranMeta.proofTiming != I.ProofTiming.OutOfExtendedProvingWindow
                && msg.sender != _input.proveMeta.proposer
        ) {
            _rw.debitBond(_conf, msg.sender, _input.proveMeta.provabilityBond);
            _rw.creditBond(_input.proveMeta.proposer, _input.proveMeta.provabilityBond);
        }

        emit I.BatchProved(_input.tran.batchId, isFirstTransition, tranMeta);

        return keccak256(abi.encode(batchMetaHash, _input.tran));
    }

    /// @dev Decides which time window we are in and who should be recorded as the prover.
    function _determineProofTiming(
        I.Config memory _conf,
        ReadWrite memory _rw,
        address _assignedProver,
        uint256 _proposedAt
    )
        private
        view
        returns (I.ProofTiming timing_, address prover_)
    {
        unchecked {
            if (_rw.blockTimestamp <= _proposedAt + _conf.provingWindow) {
                return (I.ProofTiming.InProvingWindow, _assignedProver);
            } else if (_rw.blockTimestamp <= _proposedAt + _conf.extendedProvingWindow) {
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

    // --- ERRORs --------------------------------------------------------------------------------
    error BatchNotFound();
    error BlocksNotInCurrentFork();
    error InvalidtranParentHash();
    error MetaHashNotMatch();
    error NoBlocksToProve();
    error TooManyBatchesToProve();
}
