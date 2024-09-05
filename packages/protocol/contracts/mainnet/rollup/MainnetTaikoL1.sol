// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../../L1/TaikoL1.sol";
import "../addrcache/RollupAddressCache.sol";

/// @title MainnetTaikoL1
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {TaikoL1}.
/// @custom:security-contact security@taiko.xyz
contract MainnetTaikoL1 is TaikoL1, RollupAddressCache {
    /// @inheritdoc ITaikoL1
    function getConfig() public pure override returns (TaikoData.Config memory) {
        // All hard-coded configurations:
        // - treasury: the actual TaikoL2 address.
        // - anchorGasLimit: 250_000 (based on internal devnet, its ~220_000
        // after 256 L2 blocks)
        return TaikoData.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            // If we have 1 block per 12 seconds, then each day there will be 86400/12=7200 blocks.
            // We therefore use 7200 as the base unit to configure blockMaxProposals and
            // blockRingBufferSize.
            blockMaxProposals: 324_000, // = 7200 * 45
            // We give 7200 * 5 = 36000 slots for verifeid blocks in case third party apps will use
            // their data.
            blockRingBufferSize: 360_000, // = 7200 * 50
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: TaikoData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes
             }),
            ontakeForkHeight: 374_400 // = 7200 * 52
         });
    }

    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
