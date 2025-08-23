// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProofVerifier
/// @notice Interface for verifying validity proofs for state transitions
/// @custom:security-contact security@taiko.xyz
interface IProofVerifier {
    /// @notice Verifies a validity proof for a state transition
    /// @dev This function must revert if the proof is invalid
    /// @param _transitionsHash The hash of the transitions to verify
    /// @param _proof The proof data for the transitions
    function verifyProof(bytes32 _transitionsHash, bytes calldata _proof) external view;
}
