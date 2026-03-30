// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

/// @title Zisk Verifier Interface
/// @author SilentSig
/// @notice This contract is the interface for the Zisk Verifier.
interface IZiskVerifier {
    /// @notice Verifies a proof with given public values and vkey.
    /// @param programVK The verification key for the RISC-V program.
    /// @param rootCVadcopFinal The rootC value for the Vadcop final.
    /// @param publicValues The public values encoded as bytes.
    /// @param proofBytes The proof of the program execution the Zisk zkVM encoded as bytes.
    function verifySnarkProof(
        uint64[4] calldata programVK,
        uint64[4] calldata rootCVadcopFinal,
        bytes calldata publicValues,
        bytes calldata proofBytes
    )
        external
        view;
}
