// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "../IInbox.sol";
import "./LibForks.sol";
import "./LibBinding.sol";

/// @title LibVerify
/// @notice Library for batch verification and bond distribution in Taiko protocol
/// @dev Handles the final verification stage of batch processing including:
///      - Sequential batch verification with transition metadata validation
///      - Cooldown period enforcement before verification
///      - Bond distribution to provers based on timing and conditions
///      - Periodic state root synchronization with L2
///      - Fork boundary checks for verification eligibility
/// @custom:security-contact security@taiko.xyz
library LibVerify {
    using LibMath for uint256;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Verifies multiple batches and updates the protocol summary
    /// @dev Processes batches sequentially, validating transition metadata,
    ///      enforcing cooldown periods, and distributing bonds to provers.
    ///      Also handles periodic state root synchronization.
    /// @param _bindings Library function binding
    /// @param _config Protocol configuration parameters
    /// @param _summary Current protocol summary state
    /// @param _trans Array of transition metadata for verification
    /// @return Updated summary with verification results
    function verify(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Summary memory _summary,
        IInbox.TransitionMeta[] memory _trans
    )
        internal
        returns (IInbox.Summary memory)
    {
        uint256 nextBlockId = _summary.lastVerifiedBlockId + 1;

        // A batch cannot cross fork boundaries, this is guaranteed by proposal and proving
        // logics,
        // so we can check the first block id only.
        if (!LibForks.isBlockInCurrentFork(_config, nextBlockId)) {
            return _summary;
        }

        uint256 lastSyncedBatchIndex;
        uint48 batchId = _summary.lastVerifiedBatchId;

        for (uint256 i; i < _config.maxBatchesToVerify; ++i) {
            if (i >= _trans.length) revert TransitionNotProvided();
            IInbox.TransitionMeta memory tran = _trans[i];

            batchId = tran.batchId;

            bytes32 tranMetaHash =
                _bindings.loadTransitionMetaHash(_config, _summary.lastVerifiedBlockHash, batchId);

            // Transition not found, we've reached the end of the transition linked list.
            if (tranMetaHash == 0) break;

            // The provided transition is invalid
            if (tranMetaHash != keccak256(abi.encode(tran))) {
                revert TransitionHashMismatch();
            }

            // The transition is still cooling down, we stop here without reverting
            if (tran.provedAt + _config.cooldownWindow > block.timestamp) break;

            uint256 proverRefund = _calcBondPaymentToProver(_config, tran);
            _bindings.creditBond(tran.prover, proverRefund * 1 gwei);

            if (batchId % _config.stateRootSyncInternal == 0) {
                lastSyncedBatchIndex = i;
            }

            _summary.lastVerifiedBlockHash = tran.blockHash;
            _summary.lastVerifiedBlockId = tran.lastBlockId;
            _summary.lastVerifiedBatchId = batchId;

            emit IInbox.Verified(batchId, tran.lastBlockId, tran.blockHash);
        }

        if (lastSyncedBatchIndex != 0) {
            _summary.lastSyncedAt = uint48(block.timestamp);
            _summary.lastSyncedBlockId = _trans[lastSyncedBatchIndex].lastBlockId;
            _bindings.syncChainData(
                _config, _summary.lastSyncedBlockId, _trans[lastSyncedBatchIndex].stateRoot
            );
        }
        return _summary;
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Calculates the bond amount to refund to the prover based on timing and conditions
    /// @param _config Protocol configuration containing bond parameters
    /// @param _tran Transition metadata containing bond and timing information
    /// @return  Bond amount to credit to the prover
    function _calcBondPaymentToProver(
        IInbox.Config memory _config,
        IInbox.TransitionMeta memory _tran
    )
        private
        pure
        returns (uint256)
    {
        if (_tran.proofTiming == IInbox.ProofTiming.InProvingWindow) {
            return _tran.provabilityBond + _tran.livenessBond;
        } else if (_tran.proofTiming == IInbox.ProofTiming.InExtendedProvingWindow) {
            return
                uint256(_tran.livenessBond) * _config.bondRewardPtcg / 100 + _tran.provabilityBond;
        } else {
            //  _tran.proofTiming == IInbox.ProofTiming.OutOfExtendedProvingWindow
            return uint256(_tran.provabilityBond) * _config.bondRewardPtcg / 100;
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error TransitionNotProvided();
    error TransitionHashMismatch();
}
