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
    /// @param blockId The ID of the proposed block. Note that the ID is only
    /// known when the block is proposed, therefore, it should not be used for
    /// verifying prover authorization.
    /// @param input The block's BlockMetadataInput data.
    /// @param assignment The assignment to evaluate
    function onBlockAssigned(
        uint64 blockId,
        TaikoData.BlockMetadataInput calldata input,
        TaikoData.ProverAssignment calldata assignment
    )
        external
        payable;
}
