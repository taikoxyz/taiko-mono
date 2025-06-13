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
        uint64 maxVerificationDelay;
        uint96 livenessBondBase;
        uint96 livenessBondPerBlock;
    }

    uint64 public immutable chainId;
    uint64 public immutable maxVerificationDelay;
    uint96 public immutable livenessBondBase;
    uint96 public immutable livenessBondPerBlock;

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
        maxVerificationDelay = _configParams.maxVerificationDelay;
        livenessBondBase = _configParams.livenessBondBase;
        livenessBondPerBlock = _configParams.livenessBondPerBlock;
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
            blockMaxGasLimit: 200_000_000,
            livenessBondBase: livenessBondBase,
            livenessBondPerBlock: livenessBondPerBlock,
            stateRootSyncInternal: 2,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 100_000_000,
                minGasExcess: 31_136_000_000, // Resolves to ~0.0999 Gwei
                maxGasIssuancePerBlock: 6_000_000_000
            }),
            provingWindow: 24 hours,
            cooldownWindow: 7 days,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
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
