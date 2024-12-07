// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/shared/libs/LibNetwork.sol";
import "./libs/LibFasterReentryLock.sol";

/// @title MainnetTaikoL1
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {TaikoL1}.
/// @custom:security-contact security@taiko.xyz
contract MainnetTaikoL1 is TaikoL1 {
    function getConfigV3() public pure override returns (ITaikoL1.ConfigV3 memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 250_000 (based on internal devnet, its ~220_000
        // after 256 L2 blocks)
        return ITaikoL1.ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            // Ring buffers are being reused on the mainnet, therefore the following two
            // configuration values must NEVER be changed!!!
            blockMaxProposals: 324_000, // DO NOT CHANGE!!!
            blockRingBufferSize: 360_000, // DO NOT CHANGE!!!
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 2 hours,
            emitTxListInCalldata: true,
            pacayaForkHeight: 1_000_000 // TODO: update this
         });
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
