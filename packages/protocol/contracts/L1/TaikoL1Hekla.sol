// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1.sol";

/// @title TaikoL1Hekla
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1Hekla is TaikoL1 {
    /// @inheritdoc ITaikoL1
    function getConfig() public pure override returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO_HEKLA,
            blockMaxProposals: 504_000, // = 7200 * 70
            blockRingBufferSize: 540_000, // = 7200 * 75
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            checkEOAForCalldataDA: true
        });
    }
}
