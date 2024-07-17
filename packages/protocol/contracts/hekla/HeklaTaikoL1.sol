// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1.sol";

/// @title HeklaTaikoL1
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract HeklaTaikoL1 is TaikoL1 {
    /// @inheritdoc ITaikoL1
    function getConfig() public pure override returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // Never change this value as ring buffer is being reused!!!
            blockMaxProposals: 324_000,
            // Never change this value as ring buffer is being reused!!!
            blockRingBufferSize: 324_512,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            ontakeForkHeight: 540_000 // = 7200 * 75
         });
    }
}
