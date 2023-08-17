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
    /// Burns the specified `bond` amount of Taiko token from this contract.
    /// @param proposer The address of the block proposer.
    /// @param blockId The ID of the block.
    /// @param params Additional function parameters.
    function onBlockAssigned(
        address proposer,
        uint64 blockId,
        bytes calldata params
    )
        external
        payable;
}
