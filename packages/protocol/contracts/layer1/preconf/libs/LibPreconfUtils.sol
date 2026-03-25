// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/ILookaheadStore.sol";
import "./LibPreconfConstants.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/// @title LibPreconfUtils
/// @custom:security-contact security@taiko.xyz
library LibPreconfUtils {
    using SafeCastUpgradeable for uint256;

    uint256 private constant _MAX_QUERIES = 32;

    /// @notice Calculates the lookahead hash.
    /// @param _epochTimestamp The timestamp of the epoch.
    /// @param _lookaheadSlots The lookahead slots array.
    /// @return The hash of the abi.encoded timestamp and lookahed slots.
    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        internal
        pure
        returns (bytes26)
    {
        return bytes26(keccak256(abi.encode(_epochTimestamp, _lookaheadSlots)));
    }

    /// @notice Retrieves the beacon block root that was posted to the execution layer at or after a
    /// given timestamp.
    /// @dev To obtain the block root of the Nth block, this function queries the root at block N +
    /// 1. If block N + 1 is a missed slot, it continues querying up to 32 subsequent blocks (N + 2,
    /// N + 3, etc.) until it finds a block that contains the root for the Nth block or the target
    /// timestamp exceeds the current block timestamp.
    /// @dev Caller should verify the returned value is not 0.
    /// @param timestamp The timestamp for which the beacon block root is to be retrieved.
    /// @return The beacon block root as a bytes32 value.
    function getBeaconBlockRootAtOrAfter(uint256 timestamp) internal view returns (bytes32) {
        if (timestamp < LibPreconfConstants.getGenesisTimestamp(block.chainid)) {
            return bytes32(0);
        }
        timestamp = timestamp + LibPreconfConstants.SECONDS_IN_SLOT;
        uint256 currentTimestamp = block.timestamp;

        for (uint256 i; i < _MAX_QUERIES && timestamp <= currentTimestamp; ++i) {
            bytes32 root = getBeaconBlockRootAt(timestamp);
            if (root != 0) return root;

            unchecked {
                timestamp += LibPreconfConstants.SECONDS_IN_SLOT;
            }
        }
        return bytes32(0);
    }

    /// @notice Retrieves the beacon block root at a specific timestamp.
    /// @param timestamp The timestamp for which the beacon block root is to be retrieved.
    /// @return root_ The beacon block root as a bytes32 value.
    function getBeaconBlockRootAt(uint256 timestamp) internal view returns (bytes32 root_) {
        (bool success, bytes memory result) =
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT.staticcall(abi.encode(timestamp));

        if (success && result.length > 0) {
            root_ = abi.decode(result, (bytes32));
        }
    }

    /// @notice Calculates the timestamp of the current epoch based on the genesis timestamp.
    /// @dev This function retrieves the genesis timestamp for the current chain ID, calculates
    ///      the time passed since the genesis, and determines the timestamp for the start of
    ///      the current epoch by rounding down to the nearest epoch boundary.
    /// @return The timestamp of the current epoch.
    function getEpochTimestamp() internal view returns (uint48) {
        return getEpochTimestamp(0);
    }

    /// @notice Calculates the timestamp of a future epoch based on the genesis timestamp.
    /// @param _epochOffset The offset from the current epoch.
    /// @return The timestamp of the future epoch.
    function getEpochTimestamp(uint256 _epochOffset) internal view returns (uint48) {
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 timePassed = block.timestamp - genesisTimestamp;
        /// forge-lint: disable-start(divide-before-multiply)
        uint256 timePassedUptoCurrentEpoch = (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
            * LibPreconfConstants.SECONDS_IN_EPOCH;
        /// forge-lint: disable-end

        return (genesisTimestamp + timePassedUptoCurrentEpoch + _epochOffset
                * LibPreconfConstants.SECONDS_IN_EPOCH).toUint48();
    }

    /// @notice Calculates the timestamp of the epoch containing the provided slot timestamp .
    /// @param _slotTimestamp The timestamp of the slot.
    /// @return The timestamp of the epoch.
    function getEpochtimestampForSlot(uint256 _slotTimestamp) internal view returns (uint256) {
        uint256 genesisTimestamp = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 timePassed = _slotTimestamp - genesisTimestamp;
        uint256 timePassedUptoEpoch = (timePassed / LibPreconfConstants.SECONDS_IN_EPOCH)
            * LibPreconfConstants.SECONDS_IN_EPOCH;
        return genesisTimestamp + timePassedUptoEpoch;
    }
}
