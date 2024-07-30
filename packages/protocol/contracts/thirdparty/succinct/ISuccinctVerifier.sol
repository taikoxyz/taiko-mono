// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title SP1 Verifier Interface
/// @author Succinct Labs
/// @notice This interface is for the deployed SP1 Verifier and 100% brought over from :
/// https://github.com/succinctlabs/sp1-contracts/blob/main/contracts/src/ISP1Verifier.sol
interface ISuccinctVerifier {
    /// @notice Verifies a proof with given public values and vkey.
    /// @dev It is expected that the first 4 bytes of proofBytes must match the first 4 bytes of
    /// target verifier's VERIFIER_HASH.
    /// @param programVKey The verification key for the RISC-V program.
    /// @param publicValues The public values encoded as bytes.
    /// @param proofBytes The proof of the program execution the SP1 zkVM encoded as bytes.
    function verifyProof(
        bytes32 programVKey,
        bytes calldata publicValues,
        bytes calldata proofBytes
    )
        external
        view;
}

interface ISuccinctWithHash is ISuccinctVerifier {
    /// @notice Returns the hash of the verifier.
    function VERIFIER_HASH() external pure returns (bytes32);
}
