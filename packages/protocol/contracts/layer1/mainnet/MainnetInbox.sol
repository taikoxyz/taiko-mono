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
        uint64 _shastaForkTimestamp
    )
        TaikoInbox(_wrapper, _verifier, _bondToken, _signalService, _shastaForkTimestamp)
    { }

    function pacayaConfig() public pure override returns (ITaikoInbox.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 1_000_000
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // Ring buffers are being reused on the mainnet, therefore the following two
            // configuration values must NEVER be changed!!!
            maxUnverifiedBatches: 324_000, // DO NOT CHANGE!!!
            batchRingBufferSize: 360_000, // DO NOT CHANGE!!!
            maxBatchesToVerify: 8,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 25e18, // 25 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 4,
            maxAnchorHeightOffset: 96,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_344_899_430, // 0.01 gwei
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 2 hours,
            cooldownWindow: 2 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({
                ontake: 538_304,
                pacaya: 1_166_000,
                shasta: 0,
                unzen: 0
            })
        });
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
