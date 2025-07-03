// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBondManagement.sol";
import "./LibForks.sol";
import "./LibBatchProposal.sol";
import "./LibDataUtils.sol";
import "./LibStorage.sol";

/// @title LibBatchVerification
/// @notice Library for batch verification functionality
/// @custom:security-contact security@taiko.xyz
library LibBatchVerification {
    using LibMath for uint256;
    using LibStorage for I.State;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Verifies multiple batches and updates the summary
    /// @param $ The state storage
    /// @param _conf The configuration
    /// @param _rw Read/write access functions
    /// @param _summary The current summary
    /// @param _trans The transition metadata array
    /// @return The updated summary
    function verifyBatches(
        I.State storage $,
        I.Config memory _conf,
        LibDataUtils.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            uint48 batchId = _summary.lastVerifiedBatchId + 1;

            if (!LibForks.isBlocksInCurrentFork(_conf, batchId, batchId)) {
                return _summary;
            }

            uint256 stopBatchId = uint256(_summary.numBatches).min(
                _conf.maxBatchesToVerify + _summary.lastVerifiedBatchId + 1
            );

            uint256 i;
            uint48 lastSyncedBlockId;
            bytes32 lastSyncedStateRoot;
            uint256 nTransitions = _trans.length;

            for (; batchId < stopBatchId; ++batchId) {
                (bytes32 tranMetaHash, bool isFirstTransition) =
                    $.loadTransitionMetaHash(_conf, _summary.lastVerifiedBlockHash, batchId);

                if (tranMetaHash == 0) break;

                require(i < nTransitions, TransitionNotProvided());
                require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionMetaMismatch());

                if (_trans[i].createdAt + _conf.cooldownWindow > block.timestamp) {
                    break;
                }

                uint96 bondToProver = _calcBondToProver(_conf, _trans[i], isFirstTransition);
                _rw.creditBond(_trans[i].prover, bondToProver);

                if (batchId % _conf.stateRootSyncInternal == 0) {
                    lastSyncedBlockId = _trans[i].lastBlockId;
                    lastSyncedStateRoot = _trans[i].stateRoot;
                }

                emit I.BatchesVerified(batchId, _trans[i].blockHash);
                _summary.lastVerifiedBlockHash = _trans[i++].blockHash;
            }

            if (lastSyncedBlockId != 0) {
                _summary.lastSyncedBlockId = lastSyncedBlockId;
                _summary.lastSyncedAt = uint48(block.timestamp);
                _rw.syncChainData(_conf, lastSyncedBlockId, lastSyncedStateRoot);
            }
        }
        return _summary;
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Calculates the bond amount to return to the prover
    /// @param _conf The configuration
    /// @param _tran The transition metadata
    /// @param _isFirstTransition Whether this is the first transition
    /// @return The bond amount to credit to the prover
    function _calcBondToProver(
        I.Config memory _conf,
        I.TransitionMeta memory _tran,
        bool _isFirstTransition
    )
        private
        pure
        returns (uint96)
    {
        unchecked {
            if (_tran.proofTiming == I.ProofTiming.InProvingWindow) {
                // All liveness bond is returned to the prover, this is not a reward
                return _isFirstTransition
                    ? _tran.livenessBond + _tran.provabilityBond
                    : _tran.livenessBond;
            }

            if (_tran.proofTiming == I.ProofTiming.InExtendedProvingWindow) {
                // Prover is rewarded with bondRewardPtcg% of the liveness bond
                uint96 amount = (_tran.livenessBond * _conf.bondRewardPtcg) / 100;
                return _isFirstTransition ? amount + _tran.provabilityBond : amount;
            }

            if (_tran.byAssignedProver) {
                // The assigned prover gets back his liveness bond, and 100% provability
                // bond. This allows him to use a higher gas price to submit his proof first
                return _tran.provabilityBond;
            }

            // Other provers get bondRewardPtcg% of the provability bond
            return (_tran.provabilityBond * _conf.bondRewardPtcg) / 100;
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when a transition is not provided
    error TransitionNotProvided();

    /// @notice Thrown when the transition metadata doesn't match
    error TransitionMetaMismatch();
}
