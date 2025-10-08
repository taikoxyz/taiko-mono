// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "./libs/LibFasterReentryLock.sol";

/// @title MainnetInbox
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {TaikoInbox}.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is TaikoInbox {
    constructor(
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService)
    { }

    function _getConfig() internal pure virtual override returns (ITaikoInbox.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 1_000_000

        (uint64 maxUnverifiedBatches_, uint64 batchRingBufferSize_) = _getRingbufferConfig();
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // Ring buffers are being reused on the mainnet, therefore the following two
            // configuration values must NEVER be changed!!!
            maxUnverifiedBatches: maxUnverifiedBatches_,
            batchRingBufferSize: batchRingBufferSize_,
            maxBatchesToVerify: 16,
            blockMaxGasLimit: 32_000_000,
            livenessBond: 25e18, // 25 Taiko token per batch
            stateRootSyncInternal: 4,
            maxAnchorHeightOffset: 96,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 40,
                sharingPctg: 75,
                gasIssuancePerSecond: 1_000_000,
                minGasExcess: 1_440_000_000,
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 2 hours,
            cooldownWindow: 2 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: _getForkHeights()
        });
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    function _getForkHeights() internal pure virtual returns (ITaikoInbox.ForkHeights memory) {
        return ITaikoInbox.ForkHeights({
            ontake: 538_304,
            pacaya: 1_166_000,
            shasta: 0,
            unzen: 0,
            etna: 0,
            fuji: 0
        });
    }

    /// @dev Never change the following two values!!!
    function _getRingbufferConfig()
        internal
        pure
        virtual
        returns (uint64 maxUnverifiedBatches_, uint64 batchRingBufferSize_)
    {
        maxUnverifiedBatches_ = 324_000;
        batchRingBufferSize_ = 360_000;
    }
}
