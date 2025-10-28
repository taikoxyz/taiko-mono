// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EssentialContractStorage
/// @notice Mirrors the storage footprint of `EssentialContract` so that contracts
///         replacing it can keep the exact slot layout without inheriting its logic.
abstract contract EssentialContractStorage {
    /// @dev Storage slots reserved to stay layout-compatible with `EssentialContract`.
    uint256[251] private __essentialContractStorage;
}
