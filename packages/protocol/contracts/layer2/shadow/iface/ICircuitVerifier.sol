// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @custom:security-contact security@taiko.xyz

interface ICircuitVerifier {
    /// @notice Verifies a proof against public inputs.
    function verifyProof(bytes calldata _proof, uint256[] calldata _publicInputs)
        external
        view
        returns (bool _isValid_);
}
