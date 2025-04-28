// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "./libs/LibFasterReentryLock.sol";

/// @title MainnetTaikoL1
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {TaikoL1}.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is TaikoInbox {
    constructor(
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService,
        address _proverMarket
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService, _proverMarket)
    { }

    function v4GetConfig() public pure override returns (ITaikoInbox.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 1_000_000
        (uint64 maxUnverifiedBatches_, uint64 batchRingBufferSize_) = _getRingBufferConfig();

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // Ring buffers are being reused on the mainnet, therefore the following two
            // configuration values must NEVER be changed!!!
            maxUnverifiedBatches: maxUnverifiedBatches_, // DO NOT CHANGE!!!
            batchRingBufferSize: batchRingBufferSize_, // DO NOT CHANGE!!!
            maxBatchesToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 50e18, // 50 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 4,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_344_899_430, // 0.01 gwei
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 2 hours,
            cooldownWindow: 2 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            baseFeeSharings: _getBaseFeeSharings(),
            forkHeights: _getForkHeights()
        });
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    function _getRingBufferConfig()
        internal
        pure
        virtual
        returns (uint64 maxUnverifiedBatches_, uint64 batchRingBufferSize_)
    {
        maxUnverifiedBatches_ = 324_000;
        batchRingBufferSize_ = 360_000;
    }

    function _getForkHeights() internal pure virtual returns (ITaikoInbox.ForkHeights memory) {
        return ITaikoInbox.ForkHeights({
            ontake: 538_304,
            pacaya: type(uint64).max,
            shasta: 0,
            unzen: 0
        });
    }

    function _getBaseFeeSharings()
        internal
        pure
        virtual
        returns (ITaikoInbox.BaseFeeSharing[] memory)
    {
        // TODO
        return new ITaikoInbox.BaseFeeSharing[](0);
    }
}
