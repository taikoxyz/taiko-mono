// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoInbox.sol";

/// @title HeklaInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract HeklaInbox is TaikoInbox {
    /// @notice Emitted when a transition is written to the state by the owner.
    /// @param batchId The ID of the batch containing the transition.
    /// @param tid The ID of the transition within the batch.
    /// @param ts The transition state written.
    event TransitionWritten(uint64 batchId, uint24 tid, TransitionState ts);

    constructor(
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService, type(uint64).max)
    { }

    /// @notice Manually write a transition for a batch.
    /// @dev This function is supposed to be used by the owner to force prove a transition for a
    /// block that has not been verified.
    function writeTransition(
        uint64 _batchId,
        bytes32 _parentHash,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        address _prover,
        bool _inProvingWindow
    )
        external
        onlyOwner
    {
        require(_blockHash != 0, InvalidParams());
        require(_parentHash != 0, InvalidParams());
        require(_stateRoot != 0, InvalidParams());
        require(_batchId > state.stats2.lastVerifiedBatchId, BatchVerified());

        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        uint24 tid = state.transitionIds[_batchId][_parentHash];
        if (tid == 0) {
            tid = batch.nextTransitionId++;
        }

        TransitionState storage ts = state.transitions[slot][tid];
        ts.stateRoot = _batchId % config.stateRootSyncInternal == 0 ? _stateRoot : bytes32(0);
        ts.blockHash = _blockHash;
        ts.prover = _prover;
        ts.inProvingWindow = _inProvingWindow;
        ts.createdAt = uint48(block.timestamp);

        if (tid == 1) {
            ts.parentHash = _parentHash;
        } else {
            state.transitionIds[_batchId][_parentHash] = tid;
        }

        emit TransitionWritten(
            _batchId,
            tid,
            TransitionState(
                _parentHash,
                _blockHash,
                _stateRoot,
                _prover,
                _inProvingWindow,
                uint48(block.timestamp)
            )
        );
    }

    function pacayaConfig() public pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_HEKLA,
            // Never change this value as ring buffer is being reused!!!
            maxUnverifiedBatches: 324_000,
            // Never change this value as ring buffer is being reused!!!
            batchRingBufferSize: 324_512,
            maxBatchesToVerify: 8,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 4,
            maxAnchorHeightOffset: 96,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_344_899_430, // 0.01 gwei
                maxGasIssuancePerBlock: 600_000_000 // two minutes
             }),
            provingWindow: 2 hours,
            cooldownWindow: 2 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({
                ontake: 840_512,
                pacaya: 1_299_888,
                shasta: 0,
                unzen: 0
            })
        });
    }
}
