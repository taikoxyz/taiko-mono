// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title I1559Manager
/// @notice Interface for updating the L2 EIP-1559 base fee.
/// Defines a function to calculate and set the new base fee per gas.
interface I1559Manager {
    /// @notice Emitted when the base fee is set or updated.
    event BaseFeeUpdated(uint256 value);

    /// @notice Computes and updates the L2 EIP-1559 base fee using the gas
    /// consumption of the parent block.
    /// @param gasUsed Gas consumed by the parent block, used to calculate the
    /// new base fee.
    /// @return baseFeePerGas Updated base fee per gas for the current block.
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        returns (uint64 baseFeePerGas);

    /// @dev Calculate and returns the new base fee per gas.
    /// @param gasUsed Gas consumed by the parent block, used to calculate the
    /// new base fee.
    /// @return baseFeePerGas Updated base fee per gas for the current block.
    function calcBaseFeePerGas(uint32 gasUsed)
        external
        view
        returns (uint64 baseFeePerGas);
}
