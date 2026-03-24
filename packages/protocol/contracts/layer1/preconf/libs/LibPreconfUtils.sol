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
    /// @param _timestamp The timestamp for which the beacon block root is to be retrieved.
    /// @return root_ The beacon block root as a bytes32 value.
    function getBeaconBlockRootAtOrAfter(uint256 _timestamp) internal view returns (bytes32 root_) {
        assembly {
            // Inline genesis timestamp check — avoids Solidity if/else dispatch
            let genesis := 0
            switch chainid()
            case 1 { genesis := 1606824023 }
            case 17000 { genesis := 1695902400 }
            case 7014190335 { genesis := 1718967660 }
            case 560048 { genesis := 1742213400 }

            if iszero(lt(_timestamp, genesis)) {
                let ts := add(_timestamp, 12) // SECONDS_IN_SLOT
                let ct := timestamp()
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    if gt(ts, ct) { break }
                    mstore(0x00, ts)
                    if staticcall(
                        gas(),
                        0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02,
                        0x00,
                        0x20,
                        0x00,
                        0x20
                    ) {
                        let r := mload(0x00)
                        if r {
                            root_ := r
                            break
                        }
                    }
                    ts := add(ts, 12)
                }
            }
        }
    }

    /// @notice Retrieves the beacon block root at a specific timestamp.
    /// @param _ts The timestamp for which the beacon block root is to be retrieved.
    /// @return root_ The beacon block root as a bytes32 value.
    function getBeaconBlockRootAt(uint256 _ts) internal view returns (bytes32 root_) {
        assembly {
            mstore(0x00, _ts)
            if staticcall(gas(), 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02, 0x00, 0x20, 0x00, 0x20)
            {
                root_ := mload(0x00)
            }
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
    /// @return result_ The timestamp of the future epoch.
    function getEpochTimestamp(uint256 _epochOffset) internal view returns (uint48 result_) {
        /// forge-lint: disable-start(divide-before-multiply)
        assembly {
            // Inline getGenesisTimestamp(block.chainid) — avoids Solidity if/else chain
            let genesis := 0
            switch chainid()
            case 1 { genesis := 1606824023 } // ETHEREUM_MAINNET
            case 17000 { genesis := 1695902400 } // ETHEREUM_HOLESKY
            case 7014190335 { genesis := 1718967660 } // ETHEREUM_HELDER
            case 560048 { genesis := 1742213400 } // ETHEREUM_HOODI

            let timePassed := sub(timestamp(), genesis)
            // (timePassed / 384) * 384 — round down to epoch boundary
            let epochTime := mul(div(timePassed, 384), 384)
            result_ := add(genesis, add(epochTime, mul(_epochOffset, 384)))
        }
        /// forge-lint: disable-end
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
