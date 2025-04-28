// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LibPreconfConstants.sol";

/// @title LibPreconfUtils
/// @custom:security-contact security@taiko.xyz
library LibPreconfUtils {
    uint256 private constant _MAX_QUERIES = 32;

    /// @notice Retrieves the beacon block root that was posted to the execution layer at or after a
    /// given timestamp.
    /// @dev To obtain the block root of the Nth block, this function queries the root at block N +
    /// 1. If block N + 1 is a missed slot, it continues querying up to 32 subsequent blocks (N + 2,
    /// N + 3, etc.) until it finds a block that contains the root for the Nth block or the target
    /// timestamp exceeds the current block timestamp.
    /// @dev Caller should verify the returned value is not 0.
    /// @param timestamp The timestamp for which the beacon block root is to be retrieved.
    /// @return The beacon block root as a bytes32 value.
    function getBeaconBlockRoot(uint256 timestamp) internal view returns (bytes32) {
        if (timestamp < LibPreconfConstants.getGenesisTimestamp(block.chainid)) {
            return bytes32(0);
        }
        timestamp = timestamp + LibPreconfConstants.SECONDS_IN_SLOT;
        uint256 currentTimestamp = block.timestamp;

        for (uint256 i; i < _MAX_QUERIES && timestamp <= currentTimestamp; ++i) {
            (bool success, bytes memory result) =
                LibPreconfConstants.getBeaconBlockRootContract().staticcall(abi.encode(timestamp));

            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                timestamp += LibPreconfConstants.SECONDS_IN_SLOT;
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

    /// @notice Calculates the timestamp of a future epoch based on the genesis timestamp.
    /// @param _epochOffset The offset from the current epoch.
    /// @return The timestamp of the future epoch.
    function getEpochTimestamp(uint256 _epochOffset) internal view returns (uint256) {
        return getEpochTimestamp() + _epochOffset * LibPreconfConstants.SECONDS_IN_EPOCH;
    }

    /// @notice Calculates the block height at a given timestamp.
    /// @param _timestamp The timestamp for which the block height is to be retrieved.
    /// @return The block height at the given timestamp.
    function getBlockHeightAtTimestamp(uint256 _timestamp) internal view returns (uint256) {
        if (_timestamp < block.timestamp) {
            return
                block.number - (block.timestamp - _timestamp) / LibPreconfConstants.SECONDS_IN_SLOT;
        } else {
            return
                block.number + (_timestamp - block.timestamp) / LibPreconfConstants.SECONDS_IN_SLOT;
        }
    }
}
