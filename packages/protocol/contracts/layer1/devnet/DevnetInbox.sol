// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoInbox.sol";

/// @title DevnetInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract DevnetInbox is TaikoInbox {
    uint64 internal immutable chainId;
    uint24 internal immutable cooldownWindow;

    constructor(
        uint64 _chainId,
        uint24 _cooldownWindow,
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService, type(uint64).max)
    {
        chainId = _chainId;
        cooldownWindow = _cooldownWindow;
    }

    /// @inheritdoc ITaikoInbox
    function pacayaConfig() public view override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: chainId,
            maxUnverifiedBatches: 324_000,
            batchRingBufferSize: 360_000,
            maxBatchesToVerify: 8,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 25e18, // 25 Taiko token per batch.
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 96,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_344_899_430, // 0.01 gwei
                maxGasIssuancePerBlock: 600_000_000
            }),
            provingWindow: 2 hours,
            cooldownWindow: cooldownWindow,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0, shasta: 0, unzen: 0 })
        });
    }
}
