// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IProver Interface
/// @notice Defines the functions that handle prover assignment and release.
interface IProver {
    /// @notice Assigns a prover to a specific block. If this prover nor any
    /// of its managed sub-provers are available, the function must revert.
    /// However, when the block should still be proposed as an open block, this
    /// fuction should simply return address(0). When this function is called,
    /// the specified `bond` amount of Taiko token will be burned.
    /// @param proposer Address of the block proposer.
    /// @param maxFeePerGas The fee amount charged per unit of gas.
    /// @param proofWindow The proof window within which the proof must be
    /// submitted.
    /// @param params Additional input bytes for the function.
    /// @return prover The address of the prover that should submit a proof
    /// later. If no prover is available, address(0) is returned.
    function onBlockAssigned(
        address proposer,
        uint32 maxFeePerGas,
        uint16 proofWindow,
        bytes calldata params
    )
        external
        returns (address prover, uint32 feePerGas);
}
