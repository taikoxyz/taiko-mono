// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Pico Verifier Interface
/// @author Brevis Network
/// @notice This contract is the interface for the Pico Verifier.
interface IPicoVerifier {
    /// @notice Verifies a proof with given public values and riscv verification key.
    /// @param riscvVkey The verification key for the RISC-V program.
    /// @param publicValues The public values encoded as bytes.
    /// @param proof The proof of the riscv program execution in the Pico.
    function verifyPicoProof(
        bytes32 riscvVkey,
        bytes calldata publicValues,
        uint256[8] calldata proof
    ) external view;
}
