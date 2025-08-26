// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoInbox.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/layer1/mainnet/libs/LibFasterReentryLock.sol";

/// @title SurgeDevnetInbox
/// @notice See the documentation in {ITaikoInbox}.
/// @custom:security-contact security@nethermind.io
contract SurgeDevnetInbox is TaikoInbox {
    struct ConfigParams {
        uint64 chainId;
        uint24 cooldownWindow;
        uint64 maxVerificationDelay;
        uint96 livenessBondBase;
    }

    uint64 public immutable chainId;
    uint24 public immutable cooldownWindow;
    uint64 public immutable maxVerificationDelay;
    uint96 public immutable livenessBondBase;

    constructor(
        ConfigParams memory _configParams,
        address _wrapper,
        address _dao,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        TaikoInbox(_wrapper, _dao, _verifier, _bondToken, _signalService)
    {
        chainId = _configParams.chainId;
        cooldownWindow = _configParams.cooldownWindow;
        maxVerificationDelay = _configParams.maxVerificationDelay;
        livenessBondBase = _configParams.livenessBondBase;
    }

    function pacayaConfig() public view override returns (ITaikoInbox.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 1_000_000
        return ITaikoInbox.Config({
            chainId: chainId,
            // Ring buffers are being reused on the mainnet, therefore the following two
            // configuration values must NEVER be changed!!!
            maxUnverifiedBatches: 324_000, // DO NOT CHANGE!!!
            batchRingBufferSize: 360_000, // DO NOT CHANGE!!!
            maxBatchesToVerify: 16,
            blockMaxGasLimit: 60_000_000,
            livenessBondBase: livenessBondBase,
            livenessBondPerBlock: 0,
            stateRootSyncInternal: 2,
            maxAnchorHeightOffset: 64,
            // Surge: Nothing except `sharingPctg` in `baseFeeConfig` is relevant
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 0,
                sharingPctg: 75,
                gasIssuancePerSecond: 0,
                minGasExcess: 0,
                maxGasIssuancePerBlock: 0
            }),
            provingWindow: 24 hours,
            cooldownWindow: cooldownWindow,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 6,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0, shasta: 0, unzen: 0 }),
            maxVerificationDelay: maxVerificationDelay
        });
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
