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
            blockMaxProposals: 324_000, // = 45*86400/12, 45 days, 12 seconds avg block time
            blockRingBufferSize: 324_512,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            checkEOAForCalldataDA: true
        });
    }
}
