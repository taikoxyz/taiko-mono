// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LibPreconfConstants.sol";

/// @title LibPreconfUtils
/// @custom:security-contact security@taiko.xyz
library LibPreconfUtils {
    /// @notice Retrieves the beacon block root for a given timestamp.
    /// @dev At block N, this function gets the beacon block root for block N - 1.
    ///      To obtain the block root of the Nth block, it queries the root at block N + 1.
    ///      If N + 1 is a missed slot, it continues querying until it finds a block N + x
    ///      that has the block root for the Nth block.
    /// @param timestamp The timestamp for which the beacon block root is to be retrieved.
    /// @return The beacon block root as a bytes32 value.
    function getBeaconBlockRoot(uint256 timestamp) internal view returns (bytes32) {
        uint256 targetTimestamp = timestamp + LibPreconfConstants.SECONDS_IN_SLOT;
        while (true) {
            (bool success, bytes memory result) = LibPreconfConstants.getBeaconBlockRootContract()
                .staticcall(abi.encode(targetTimestamp));
            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                targetTimestamp += LibPreconfConstants.SECONDS_IN_SLOT;
            }
        }
        return bytes32(0);
    }

    /// @notice Calculates the timestamp of the current epoch based on the genesis timestamp.
    /// @dev This function retrieves the genesis timestamp for the current chain ID, calculates
    ///      the time passed since the genesis, and determines the timestamp for the start of
    ///      the current epoch by rounding down to the nearest epoch boundary.
    /// @return The timestamp of the current epoch.
    function getEpochTimestamp() internal view returns (uint256) {
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 timePassed = block.timestamp - genesisTimestamp;
        uint256 timePassedUptoCurrentEpoch = (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
            * LibPreconfConstants.SECONDS_IN_EPOCH;

        return genesisTimestamp + timePassedUptoCurrentEpoch;
    }
}
