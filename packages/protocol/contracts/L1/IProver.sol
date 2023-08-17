// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IProver Interface
/// @notice Defines the function that handle prover assignment.
interface IProver {
    /// @notice Assigns a prover to a specific block or reverts if none is
    /// available.
    /// @param proposer The address of the block proposer.
    /// @param inputHash The hash of the block's BlockMetadataInput data.
    /// @param params Additional parameters.
    function onBlockAssigned(
        address proposer,
        bytes32 inputHash,
        bytes calldata params
    )
        external
        payable;
}
