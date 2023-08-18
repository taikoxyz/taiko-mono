// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoData } from "./TaikoData.sol";

/// @title IProver Interface
/// @notice Defines the function that handle prover assignment.
interface IProver {
    /// @notice Assigns a prover to a specific block or reverts if this prover
    /// is not available.
    /// @param proposer The address of the block proposer.
    /// @param input The block's BlockMetadataInput data.
    function onBlockAssigned(
        address proposer,
        TaikoData.BlockMetadataInput calldata input
    )
        external
        payable;
}
