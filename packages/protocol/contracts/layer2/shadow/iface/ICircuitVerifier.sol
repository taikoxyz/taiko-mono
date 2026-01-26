// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ICircuitVerifier
/// @notice Verifies ZK circuit proofs.
/// @custom:security-contact security@taiko.xyz
interface ICircuitVerifier {
    /// @notice Verifies a ZK proof against public inputs.
    /// @param _proof The serialized proof bytes.
    /// @param _publicInputs The public input field elements.
    /// @return _isValid_ True if the proof is valid.
    function verifyProof(
        bytes calldata _proof,
        uint256[] calldata _publicInputs
    )
        external
        view
        returns (bool _isValid_);
}
