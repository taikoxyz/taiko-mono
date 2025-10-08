// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoInbox.sol";

/// @title DevnetInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
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
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService)
    {
        chainId = _chainId;
        cooldownWindow = _cooldownWindow;
    }

    function _getConfig() internal view override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: chainId,
            maxUnverifiedBatches: 324_000,
            batchRingBufferSize: 360_000,
            maxBatchesToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 25e18, // 25 Taiko token per batch.
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
            forkHeights: ITaikoInbox.ForkHeights({
                ontake: 0,
                pacaya: 0,
                shasta: 10,
                unzen: 0,
                etna: 0,
                fuji: 0
            })
        });
    }
}
